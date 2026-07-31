--------------------------------------------------------------------------------
--  File:   lqr_top_tb.vhd
--  Desc:   End-to-end TB for the PandA LQR controller.
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
use work.cond_consts.all;


entity lqr_top_td is
end entity lqr_top_td;

architecture rtl of lqr_top_td is
    -- System
    constant p_clk_period : time := MASTER_CLK_PERIOD;
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    -- Topology
    constant AXES : natural := 3;
    constant M : natural := 3;
    constant DIV : natural := 128; -- small => fast test ticks

    constant N  : natural := cond_width(AXES, true, true, false); -- state block [ pos | vel ]
    constant NI : natural := n_int(N, M, 0, true, true, false); -- total engine columns
    constant AW : natural := ceil_log2(M * NI);

    -- Column bases in the assembled input (features off)
    constant UPREV_BASE : natural := N; -- [ pos | vel | u_prev | setpoint ]
    constant SP_BASE    : natural := N + M;

    -- Ports
    signal clk_i  : std_logic := '0';
    signal init_i : std_logic := '0';

    signal pos_i : mac_data_vec(0 to AXES - 1) := (others => (others => '0'));
    signal sp_i  : mac_data_vec(0 to N - 1) := (others => (others => '0'));

    signal wr_addr_i : unsigned(AW - 1 downto 0) := (others => '0');
    signal wr_data_i : signed(LANE_B_W - 1 downto 0) := (others => '0');
    signal wr_en_i : std_logic := '0';

    signal commit_i : std_logic := '0';
    signal gen_o : unsigned(GEN_W - 1 downto 0);

    signal u_o : lqr_out_vec(0 to M - 1);
    signal u_valid_o : std_logic;

    -- Test helpers
    function kg(r : real) return signed is
        -- Real -> Gain FP.
    begin
        return to_signed(integer(round(r * 2.0 ** GAIN_F)), LANE_B_W);
    end function;

    function pg(r : real) return signed is
        -- Real -> position/state FP.
    begin
        return to_signed(integer(round(r * 2.0 ** STATE_F)), LANE_A_W);
    end function;

    function round_sat(acc : signed; fd : natural; w : natural) return signed is
        -- Magnitude round-half-away then saturate (independent of fp_utils).
        variable mag : signed(acc'length + 1 downto 0);
        variable r : signed(acc'length + 1 downto 0);
    begin
        if fd = 0 then
            r := resize(acc, r'length);
        else
            mag := abs(resize(acc, mag'length));
            mag := mag + shift_left(to_signed(1, mag'length), fd - 1);
            r := shift_right(mag, fd);

            if acc(acc'high) = '1' then
                r := -r;
            end if;
        end if;

        if r > max_s(w) then
            return max_s(w);
        elsif r < min_s(w) then
            return min_s(w);
        else
            return resize(r, w);
        end if;
    end function;

    -- Test definitions
    procedure load (
        -- Fill the inactive gain buffer (M x NI, addr = row*NI + col) + commit.
        constant k : mac_gain_mat;

        signal clk_i : in  std_logic;
        signal wr_addr_i : out unsigned;
        signal wr_data_i : out signed;
        signal wr_en_i : out std_logic;
        signal commit_i : out std_logic
    ) is
        constant NC : natural := k'high(2) + 1;
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

    procedure servo_check (
        -- Drive one position, let the free-running tick sample it,
        -- then check u_o against the modelled chain and
        -- thread u_prev to the next pass.
        constant name : in string;
        constant pc : in mac_data_vec; -- current position
        constant pp : in mac_data_vec; -- previous position
        constant sp : in mac_data_vec; -- setpoint
        constant k : in mac_gain_mat;
        variable u_prev : inout mac_data_vec;

        signal clk_i : in std_logic;
        signal pos_i : out mac_data_vec;
        signal u_valid_o : in  std_logic;
        signal u_o : in lqr_out_vec;
        signal fail_o : out std_logic
    ) is
        variable x_eng : mac_data_vec(0 to k'high(2));
        variable acc : mac_acc_vec(0 to k'high(1));
        variable exp : lqr_out_vec(0 to k'high(1));
        variable u_nxt : mac_data_vec(0 to k'high(1));
    begin
        -- [ pos | vel | u_prev | setpoint ]
        x_eng := (others => (others => '0'));

        for ax in pc'range loop
            x_eng(ax) := pc(ax);
            x_eng(AXES + ax) := pc(ax) - pp(ax);
        end loop;

        for r in u_prev'range loop
            x_eng(UPREV_BASE + r) := u_prev(r);
        end loop;

        for c in sp'range loop
            x_eng(SP_BASE + c) := sp(c);
        end loop;

        for r in acc'range loop
            acc(r) := (others => '0');
            for c in x_eng'range loop
                acc(r) := acc(r) + resize(k(r, c) * x_eng(c), acc(r)'length);
            end loop;
            exp(r)   := round_sat(acc(r), PROD_F - OUT_F, OUT_W);
            u_nxt(r) := round_sat(acc(r), PROD_F - STATE_F, LANE_A_W);
        end loop;

        -- Present the position; wait for this servo pass to complete.
        pos_i <= pc;
        wait until u_valid_o = '1';
        wait until falling_edge(clk_i);

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

        u_prev := u_nxt;
    end procedure;

    -- Test data
    -- K = [ K_pos | K_vel | K_uprev | K_sp ]
    --  u = pos + (0.25 * vel) + (0.5 * u_prev) - sp_pos
    constant K : mac_gain_mat(0 to M - 1, 0 to NI - 1) := (
        (
            kg(1.0), kg(0.0), kg(0.0), 
            kg(0.25), kg(0.0), kg(0.0),
            kg(0.5), kg(0.0), kg(0.0), 
            kg(-1.0), kg(0.0), kg(0.0),
            kg(0.0), kg(0.0), kg(0.0)
        ),
        (
            kg(0.0), kg(1.0), kg(0.0), 
            kg(0.0), kg(0.25), kg(0.0),
            kg(0.0), kg(0.5), kg(0.0), 
            kg(0.0), kg(-1.0), kg(0.0), 
            kg(0.0), kg(0.0), kg(0.0)
        ),
        (
            kg(0.0), kg(0.0), kg(1.0), 
            kg(0.0), kg(0.0), kg(0.25),
            kg(0.0), kg(0.0), kg(0.5),
            kg(0.0), kg(0.0), kg(-1.0),
            kg(0.0), kg(0.0), kg(0.0)
        )
    );

    constant SP : mac_data_vec(0 to N - 1) :=
        (
            pg(5.0), pg(10.0), pg(15.0),
            pg(0.0), pg(0.0), pg(0.0)
        );
    constant P0 : mac_data_vec(0 to AXES - 1) := 
        (pg(10.0), pg(20.0), pg(30.0));
    constant P1 : mac_data_vec(0 to AXES - 1) := 
        (pg(12.0), pg(22.0), pg(28.0));
    constant P2 : mac_data_vec(0 to AXES - 1) :=
        (pg( 8.0), pg(25.0), pg(35.0));

begin

    clkgen : process
    begin
        while not sim_done loop
            clk_i <= not clk_i;
            wait for p_clk_period / 2;
        end loop;
        wait;
    end process;

    uut : entity work.lqr_top
        generic map (
            AXES => AXES,
            M => M,
            DIV => DIV,
            HIST_DEPTH => 2,
            G_PHI => 0,
            G_VELOCITY => true,
            G_PREV => false,
            G_UPREV => true,
            G_SETPOINT => true,
            G_AFFINE => false
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            pos_i => pos_i,
            sp_i => sp_i,
            wr_addr_i => wr_addr_i,
            wr_data_i => wr_data_i,
            wr_en_i => wr_en_i,
            commit_i => commit_i,
            gen_o => gen_o,
            u_o => u_o,
            u_valid_o => u_valid_o
        );

    process
        variable u_prev_g : mac_data_vec(0 to M - 1) := (others => (others => '0'));
    begin
        -- Reset
        wait until rising_edge(clk_i);
        init_i <= '1';
        wait until rising_edge(clk_i);
        init_i <= '0';
        wait until rising_edge(clk_i);

        -- Preload gains + hold the setpoint
        load(K, clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i);
        sp_i <= SP;

        -- Warm-up holds P0 (vel = 0), then the position sequence.
        -- u = pos + 0.25*vel + 0.5*u_prev - sp_pos:
        --   k0 -> [5, 10, 15]
        --   k1 -> [10, 18, 20]
        --   k2 -> [7, 25, 32]
        servo_check("k0", P0, P0, SP, K, u_prev_g,
            clk_i, pos_i, u_valid_o, u_o, fail);
        servo_check("k1", P1, P0, SP, K, u_prev_g,
            clk_i, pos_i, u_valid_o, u_o, fail);
        servo_check("k2", P2, P1, SP, K, u_prev_g,
            clk_i, pos_i, u_valid_o, u_o, fail);

        -- Report the overall result
        wait until rising_edge(clk_i);
        if fail = '0' then
            report "LQR TOP TESTS PASS" severity note;
        else
            report "LQR TOP TESTS FAILED" severity failure;
        end if;
        sim_done <= true;

        wait;
    end process;

end architecture rtl;
