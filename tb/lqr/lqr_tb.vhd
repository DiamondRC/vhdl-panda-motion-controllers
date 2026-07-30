--------------------------------------------------------------------------------
--  File:   lqr_tb.vhd
--  Desc:   Self-checking TB for the PandA LQR controller core.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.panda_consts.all;
use work.num_utils.all;
use work.matrix_consts.all;
use work.mac_utils.all;
use work.lqr_consts.all;


entity lqr_td is
end entity lqr_td;

architecture rtl of lqr_td is
    -- System
    constant p_clk_period : time := MASTER_CLK_PERIOD;
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    -- Topology
    constant M : natural := 3;
    constant N : natural := 3;
    constant AW : natural := ceil_log2(M * n_int(N, 0, false)); -- plain addr width
    constant AWA : natural := ceil_log2(M * n_int(N, 0, true));  -- affine addr width
    constant NA : natural := n_int(N, 0, true);                 -- affine col count

    -- Shared
    signal clk_i  : std_logic := '0';
    signal init_i : std_logic := '0';

    -- Plain DUT
    signal wr_addr_i : unsigned(AW - 1 downto 0) := (others => '0');
    signal wr_data_i : signed(LANE_B_W - 1 downto 0) := (others => '0');
    signal wr_en_i : std_logic := '0';

    signal commit_i : std_logic := '0';
    signal gen_o : unsigned(GEN_W - 1 downto 0);

    signal x_i : mac_data_vec(0 to N - 1) := (others => (others => '0'));
    signal start_i: std_logic := '0';

    signal done_o : std_logic;
    signal u_o : lqr_out_vec(0 to M - 1);

    -- Affine DUT
    signal wr_addr_a : unsigned(AWA - 1 downto 0) := (others => '0');
    signal wr_data_a : signed(LANE_B_W - 1 downto 0) := (others => '0');
    signal wr_en_a : std_logic := '0';

    signal commit_a : std_logic := '0';
    signal gen_a : unsigned(GEN_W - 1 downto 0);

    signal x_i_a : mac_data_vec(0 to N - 1) := (others => (others => '0'));
    signal start_a : std_logic := '0';

    signal done_a : std_logic;
    signal u_o_a : lqr_out_vec(0 to M - 1);


    -- Test helpers
    function kg(r : real) return signed is
        -- Real -> Gain FP.
    begin
        return to_signed(integer(round(r * 2.0 ** GAIN_F)), LANE_B_W);
    end function;

    function xg(r : real) return signed is
        -- Real -> State FP.
    begin
        return to_signed(integer(round(r * 2.0 ** STATE_F)), LANE_A_W);
    end function;

    function round_sat(acc : signed) return lqr_out is
        -- Magnitude rounding method:
        -- Round-half-away then saturate.
        -- Independant (and more expensive) method
        -- compared to bias-shift => proves result.
        constant FD : natural := PROD_F - OUT_F;
        variable mag : signed(acc'length + 1 downto 0);
        variable r : signed(acc'length + 1 downto 0);
    begin
        if FD = 0 then
            r := resize(acc, r'length);
        else
            mag := abs(resize(acc, mag'length)); -- |acc| +guard
            mag := mag + shift_left(
                to_signed(
                    1, mag'length
                    ),
                    FD - 1
                ); -- + half
            r := shift_right(mag, FD); -- floor(|acc|/2^FD + .5)

            if acc(acc'high) = '1' then
                r := -r; -- restore sign
            end if;
        end if;

        if r > max_s(OUT_W) then
            return max_s(OUT_W);
        elsif r < min_s(OUT_W) then
            return min_s(OUT_W);
        else
            return resize(r, OUT_W);
        end if;

    end function;


    -- Test definitions
    procedure load (
        -- Fill the inactive gain buffer
        -- (M x N_INT, addr = row*N_INT + col) + commit.
        constant k : mac_gain_mat;

        signal clk_i     : in  std_logic;
        signal wr_addr_i : out unsigned;
        signal wr_data_i : out signed;
        signal wr_en_i   : out std_logic;
        signal commit_i  : out std_logic
    ) is
        constant NC : natural := k'high(2) + 1; -- N_INT
    begin
        for r in 0 to k'high(1) loop
            for c in 0 to k'high(2) loop
                wr_addr_i <= to_unsigned(r * NC + c, wr_addr_i'length);
                wr_data_i <= k(r, c);
                wr_en_i   <= '1';
                wait until rising_edge(clk_i);
            end loop;
        end loop;
        wr_en_i <= '0';

        commit_i <= '1';
        wait until rising_edge(clk_i);
        commit_i <= '0';
    end procedure;

    procedure run (
        -- Load gains, drive state, run one pass and check against the golden
        -- (assemble the engine input like lqr, accumulate exactly at PROD_F,
        -- round+saturate).
        constant name   : in string;
        constant k      : mac_gain_mat;
        constant x      : mac_data_vec;
        constant affine : boolean;

        signal clk_i     : in  std_logic;
        signal wr_addr_i : out unsigned;
        signal wr_data_i : out signed;
        signal wr_en_i   : out std_logic;
        signal commit_i  : out std_logic;
        signal x_i       : out mac_data_vec;
        signal start_i   : out std_logic;
        signal done_o    : in  std_logic;
        signal u_o       : in  lqr_out_vec;
        signal fail_o    : out std_logic
    ) is
        variable x_eng : mac_data_vec(0 to k'high(2)); -- 0 .. N_INT-1
        variable acc   : mac_acc_vec(0 to k'high(1));
        variable exp   : lqr_out_vec(0 to k'high(1));
    begin
        -- Golden: [ state | features (= 0) | affine (=1) ]
        x_eng := (others => (others => '0'));

        for c in x'range loop
            x_eng(c) := x(c);
        end loop;

        if affine then
            x_eng(x_eng'high) := ONE_FX;
        end if;

        for r in acc'range loop
            acc(r) := (others => '0');
            for c in x_eng'range loop
                acc(r) := acc(r) + resize(k(r, c) * x_eng(c), acc(r)'length);
            end loop;
            exp(r) := round_sat(acc(r));
        end loop;

        -- Load gains, drive state, kick off the pass.
        load(k, clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i);

        x_i <= x;
        start_i <= '1';
        wait until rising_edge(clk_i);
        start_i <= '0';

        -- Check once the pass completes.
        wait until done_o = '1';

        for r in exp'range loop
            if u_o(r) /= exp(r) then
                fail_o <= '1';
                report name &
                    ": u(" & integer'image(r) &
                    ") got " & integer'image(to_integer(u_o(r))) &
                    ", expected " & integer'image(to_integer(exp(r)))
                severity error;
            else
                report name & " passes" severity note;
            end if;
        end loop;

        wait until done_o = '0';
    end procedure;

    procedure anchor (
        -- Hardcoded check (incase other test methods share issue.
        constant name : in string;
        constant e0   : in integer;
        constant e1   : in integer;
        constant e2   : in integer;

        signal done_o : in std_logic;
        signal u_o    : in lqr_out_vec;
        signal fail_o : out std_logic
    ) is
        variable e : lqr_out_vec(0 to 2) :=
            (to_signed(e0, OUT_W), to_signed(e1, OUT_W), to_signed(e2, OUT_W));
    begin
        wait until done_o = '1';
        for r in 0 to 2 loop
            if u_o(r) /= e(r) then
                fail_o <= '1';
                report name & " anchor: u(" & integer'image(r) &
                    ") got " & integer'image(to_integer(u_o(r)))
                severity error;
            end if;
        end loop;
        wait until done_o = '0';
    end procedure;


    -- Test data
    constant K_ID : mac_gain_mat(0 to M - 1, 0 to N - 1) := (
        (kg(1.0), kg(0.0), kg(0.0)),
        (kg(0.0), kg(1.0), kg(0.0)),
        (kg(0.0), kg(0.0), kg(1.0)) );
    constant K_HALF : mac_gain_mat(0 to M - 1, 0 to N - 1) := (
        (kg(0.5), kg(0.0), kg(0.0)),
        (kg(0.0), kg(0.5), kg(0.0)),
        (kg(0.0), kg(0.0), kg(0.5)) );
    constant K_TWO : mac_gain_mat(0 to M - 1, 0 to N - 1) := (
        (kg(2.0), kg(0.0), kg(0.0)),
        (kg(0.0), kg(2.0), kg(0.0)),
        (kg(0.0), kg(0.0), kg(2.0)) );
    constant K_MIX : mac_gain_mat(0 to M - 1, 0 to N - 1) := (
        (kg(1.0),  kg(-0.5), kg(0.0)),
        (kg(0.25), kg(1.0),  kg(-0.5)),
        (kg(-1.0), kg(0.5),  kg(1.0)) );

    constant K_AFF : mac_gain_mat(0 to M - 1, 0 to NA - 1) := (
        -- Affine: identity + bias column b = [5, -3, 0].
        (kg(1.0), kg(0.0), kg(0.0), kg( 5.0)),
        (kg(0.0), kg(1.0), kg(0.0), kg(-3.0)),
        (kg(0.0), kg(0.0), kg(1.0), kg( 0.0)) );

    constant X_234 : mac_data_vec(0 to N - 1) := 
        (xg( 2.0), xg( 3.0), xg( 4.0));
    constant X_ONE : mac_data_vec(0 to N - 1) := 
        (xg( 1.0), xg( 1.0), xg( 1.0));
    constant X_NEG : mac_data_vec(0 to N - 1) := 
        (xg(-1.0), xg(-1.0), xg(-1.0));
    constant X_SAT : mac_data_vec(0 to N - 1) := 
        (xg(32.0), xg(32.0), xg(32.0));
    constant X_NST : mac_data_vec(0 to N - 1) := 
        (xg(-33.0), xg(-33.0), xg(-33.0));
    constant X_MIX : mac_data_vec(0 to N - 1) := 
        (xg( 3.0), xg( 4.0), xg(-2.0));
    constant X_ANC : mac_data_vec(0 to N - 1) := 
        (xg(10.0), xg(-20.0), xg(30.0));

begin

    clkgen : process
    begin
        while not sim_done loop
            clk_i <= not clk_i;
            wait for p_clk_period / 2;
        end loop;
        wait;
    end process;

    uut : entity work.lqr
        generic map (
            G_ENGINES => 1,
            G_LANES => 1,
            M => M,
            N => N,
            G_FEATURES => 0,
            G_AFFINE => false
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            wr_addr_i => wr_addr_i,
            wr_data_i => wr_data_i,
            wr_en_i => wr_en_i,
            commit_i => commit_i,
            gen_o => gen_o,
            x_i => x_i,
            start_i => start_i,
            done_o => done_o,
            u_o => u_o
        );

    uut_a : entity work.lqr
        generic map (
            G_ENGINES => 1,
            G_LANES => 1,
            M => M,
            N => N,
            G_FEATURES => 0,
            G_AFFINE => true
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            wr_addr_i => wr_addr_a,
            wr_data_i => wr_data_a,
            wr_en_i => wr_en_a,
            commit_i => commit_a,
            gen_o => gen_a,
            x_i => x_i_a,
            start_i => start_a,
            done_o => done_a,
            u_o => u_o_a
        );

    process
    begin
        -- Reset both DUTs
        wait until rising_edge(clk_i);
        init_i <= '1';
        wait until rising_edge(clk_i);
        init_i <= '0';
        wait until rising_edge(clk_i);


        -- Plain core: u = K*x

        -- sanity: identity -> [2, 3, 4]
        run(
            "sanity",
            K_ID,
            X_234,
            false,
            clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
            x_i, start_i, done_o, u_o, fail
        );

        -- rounding ties on the integer output (0.5 -> away)
        run(
            "tie up", 
            K_HALF,
            X_ONE,
            false,
            clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
            x_i, start_i, done_o, u_o, fail
        );
        run(
            "tie neg",
            K_HALF, 
            X_NEG, 
            false,
            clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
            x_i, start_i, done_o, u_o, fail
        );

        -- mixed matrix, accumulation signs
        run(
            "mix", 
            K_MIX,
            X_MIX, 
            false,
            clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
            x_i, start_i, done_o, u_o, fail
        );

        -- saturation: 2*32 = 64 > +63, 2*-33 = -66 < -64
        run(
            "sat hi",
            K_TWO,
            X_SAT,
            false,
            clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
            x_i, start_i, done_o, u_o, fail
        );
        run(
            "sat lo",
            K_TWO,
            X_NST,
            false,
            clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
            x_i, start_i, done_o, u_o, fail
        );

        -- hardcoded anchor: identity -> [10, -20, 30]
        load(
            K_ID,
            clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i
        );

        x_i <= X_ANC;
        start_i <= '1';
        wait until rising_edge(clk_i);
        start_i <= '0';
        anchor("identity", 10, -20, 30, done_o, u_o, fail);


        -- Mid-pass gain update must not tear

        load(
            K_ID,
            clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i
        );

        x_i <= X_234;
        start_i <= '1';
        wait until rising_edge(clk_i);
        start_i <= '0';

        -- Let the deferred swap complete before filling the next bank.
        -- Writing on the swap edge races write_buff and
        -- mis-banks the first address.
        wait until rising_edge(clk_i);

        -- stage K_HALF into the inactive bank mid-flight
        load(
            K_HALF,
            clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i
        );

        -- in-flight run must still be K_ID -> [2, 3, 4]
        anchor(
            "mid-pass A",
            2,
            3, 
            4, 
            done_o, u_o, fail
        );

        -- next start adopts K_HALF: 0.5*[2,3,4] = [1, 1.5, 2] -> [1, 2, 2]
        start_i <= '1';
        wait until rising_edge(clk_i);
        start_i <= '0';
        anchor(
            "mid-pass B",
            1,
            2,
            2,
            done_o, u_o, fail
        );


        -- Affine core: u = K*x + b   (b = [5, -3, 0]) -> [7, 0, 4]

        run(
            "affine bias",
            K_AFF,
            X_234,
            true,
            clk_i, wr_addr_a, wr_data_a, wr_en_a, commit_a,
            x_i_a, start_a, done_a, u_o_a, fail
        );

        -- Report the overall result
        wait until rising_edge(clk_i);
        if fail = '0' then
            report "LQR TESTS PASS - Controller passes its MOT" severity note;
        else
            report "LQR TESTS FAILED" severity failure;
        end if;
        sim_done <= true;

        wait;
    end process;

end architecture rtl;
