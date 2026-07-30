--------------------------------------------------------------------------------
--  File:   mac_engine_td.vhd
--  Desc:   The testbench to drive the MAC engine for the PandA.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
-- use work.fp_utils.all;
use work.num_utils.all;
use work.matrix_consts.all;
use work.mac_utils.all;


entity mac_engine_td is
end entity mac_engine_td;

architecture rtl of mac_engine_td is
    -- System
    constant p_clk_period : time := MASTER_CLK_PERIOD;
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    -- Engine generics
    constant M : natural := 3;
    constant N : natural := 3;

    -- Engine ports
    signal clk_i : std_logic := '0';
    signal init_i : std_logic := '0';
    
    signal wr_addr_i : unsigned(ceil_log2(M * N) - 1 downto 0) := (others => '0');
    signal wr_data_i : signed(LANE_B_W - 1 downto 0) := (others => '0');
    signal wr_en_i : std_logic := '0';
    signal commit_i : std_logic := '0';
    signal gen_o : unsigned(GEN_W - 1 downto 0);

    signal x_i : mac_data_vec(0 to N - 1) :=
        -- 1D array => one level + bits
        (others => (others => '0'));

    signal start_i : std_logic := '0';

    signal done_o : std_logic;
    signal u_o : mac_acc_vec(0 to M - 1);

    -- Test definition

    -- Fill the inactive buffer and commit it for the next swap.
    procedure load (
        constant k : mac_gain_mat;

        signal clk_i     : in  std_logic;
        signal wr_addr_i : out unsigned;
        signal wr_data_i : out signed;
        signal wr_en_i   : out std_logic;
        signal commit_i  : out std_logic
    ) is
    begin
        for r in 0 to M - 1 loop
            for c in 0 to N - 1 loop
                wr_addr_i <= to_unsigned(r * N + c, wr_addr_i'length);
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

    -- Wait for the result, check against golden u = K*x,
    -- then return once the engine is idle again.
    procedure verify (
        constant name : in string;
        constant k    : mac_gain_mat;
        constant x    : mac_data_vec;

        signal done_o : in std_logic;
        signal u_o    : in mac_acc_vec;
        signal fail_o : out std_logic
    ) is
        variable exp : mac_acc_vec(u_o'range);
    begin
        for r in exp'range loop
            exp(r) := (others => '0');
            for c in x'range loop
                exp(r) := exp(r) + resize(k(r, c) * x(c), exp(r)'length);
            end loop;
        end loop;

        wait until done_o = '1';

        for r in exp'range loop
            if u_o(r) /= exp(r) then
                fail_o <= '1';
                report name &
                    ": u(" &
                    integer'image(r) &
                    ") got " &
                    integer'image(to_integer(u_o(r))) &
                    ", expected " &
                    integer'image(to_integer(exp(r)))
                severity error;
            else
                report name & "passes" severity note;
            end if;
        end loop;

        wait until done_o = '0';
    end procedure;

    procedure rev_engine (
        -- Load gains, run one full computation and check.
        constant name : in string;
        constant k : mac_gain_mat;
        constant x : mac_data_vec;

        signal clk_i     : in  std_logic;
        signal wr_addr_i : out unsigned;
        signal wr_data_i : out signed;
        signal wr_en_i   : out std_logic;
        signal commit_i  : out std_logic;
        signal x_i       : out mac_data_vec;
        signal start_i   : out std_logic;
        signal done_o    : in  std_logic;
        signal u_o       : in  mac_acc_vec;
        signal fail_o    : out std_logic
    ) is
    begin
        load(k, clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i);

        x_i <= x;
        start_i <= '1';
        wait until rising_edge(clk_i);

        start_i <= '0';
        verify(name, k, x, done_o, u_o, fail_o);
    end procedure;

    -- Test helpers
    function kv(v : integer) return signed is
    begin
    return to_signed(v, LANE_B_W); end;

    function xv(v : integer) return signed is
    begin
    return to_signed(v, LANE_A_W); end;

    -- Mid-pass test matrices
    constant MP_A : mac_gain_mat(0 to M - 1, 0 to N - 1) := (
        (kv(2), kv(0), kv(0)),
        (kv(0), kv(2), kv(0)),
        (kv(0), kv(0), kv(2))
    );
    constant MP_B : mac_gain_mat(0 to M - 1, 0 to N - 1) := (
        (kv(1), kv(1), kv(1)),
        (kv(1), kv(1), kv(1)),
        (kv(1), kv(1), kv(1))
    );
    constant MP_X : mac_data_vec(0 to N - 1) := (xv(10), xv(20), xv(30));

begin

    clkgen : process
    begin
        while not sim_done loop
            clk_i <= not clk_i;
            wait for p_clk_period / 2;
        end loop;
        wait;
    end process;

    uut: entity work.mac_engine
    generic map (
        M => M,
        N => N
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

process
begin
    -- Begin
    wait until rising_edge(clk_i);

    -- Reset the engine
    init_i <= '1';
    wait until rising_edge(clk_i);
    init_i <= '0';
    wait until rising_edge(clk_i);

    -- Run all tests
    rev_engine(
        "identity",
        (
            (kv(1), kv(0), kv(0)),
            (kv(0), kv(1), kv(0)),
            (kv(0), kv(0), kv(1))
        ),
        (
            (xv(2), xv(3), xv(4))
        ),
        clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
        x_i, start_i, done_o, u_o, fail
    );
    rev_engine(
        "lower-tri",
        (
            (kv(1), kv(0), kv(0)),
            (kv(1), kv(1), kv(0)),
            (kv(1), kv(1), kv(1))
        ),
        (
            (xv(2), xv(3), xv(4))
        ),
        clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
        x_i, start_i, done_o, u_o, fail
    );
    rev_engine(
        "negatives",
        (
            (kv(-1), kv(0), kv(0)),
            (kv(-1), kv(1), kv(0)),
            (kv(1), kv(1), kv(-1))
        ),
        (
            (xv(2), xv(3), xv(4))
        ),
        clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
        x_i, start_i, done_o, u_o, fail
    );
    rev_engine(
        "extreme",
        (
            (kv(16777215), kv(0), kv(0)),
            (kv(0), kv(8388610), kv(0)),
            (kv(1499999), kv(-10), kv(16777215))
        ),
        (
            (xv(131071), xv(-131070), xv(-131070))
        ),
        clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
        x_i, start_i, done_o, u_o, fail
    );
    rev_engine(
        "wide",
        (
            (kv(1000000), kv(0), kv(0)),
            (kv(0), kv(-500000), kv(0)),
            (kv(2000000), kv(-3000000), kv(4000000))
        ),
        (
            (xv(50000000), xv(-40000000), xv(30000000))
        ),
        clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
        x_i, start_i, done_o, u_o, fail
    );

    -- Test interrupt/restart recovery

    -- We deliberately abort this so we can be lazy
    -- and never manually load the gains in BRAM.
    x_i <= (xv(5), xv(5), xv(5));
    wait until rising_edge(clk_i);

    start_i <= '1';
    wait until rising_edge(clk_i);
    start_i <= '0';
    wait until rising_edge(clk_i);

    -- run a few cycles...
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    -- ...then interrupt.
    init_i <= '1';
    wait until rising_edge(clk_i);
    init_i <= '0';
    wait until rising_edge(clk_i);

    -- A normal run after the abort must produce the right answer.
    rev_engine(
        "post-interrupt",
        (
            (kv(1), kv(0), kv(-10)),
            (kv(8), kv(3), kv(0)),
            (kv(2), kv(1), kv(111))
        ),
        (
            (xv(20), xv(3), xv(54))
        ),
        clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i,
        x_i, start_i, done_o, u_o, fail
    );


    -- Mid-pass - a live gain update must not tear

    -- Stage A and run, mid-computation stage B.
    -- The in-flight run must finish on A,
    -- only the next run adopts B.
    load(MP_A, clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i);

    x_i <= MP_X;
    start_i <= '1';
    wait until rising_edge(clk_i);
    start_i <= '0';

    -- Let the deferred swap land before filling the next bank -
    -- writing on the swap edge races write_buff.
    wait until rising_edge(clk_i);

    -- While the engine computes A, stage B into the inactive buffer.
    load(MP_B, clk_i, wr_addr_i, wr_data_i, wr_en_i, commit_i);

    -- The in-flight run must have used A.
    verify("mid-pass A", MP_A, MP_X, done_o, u_o, fail);

    -- A fresh start now swaps to B.
    start_i <= '1';
    wait until rising_edge(clk_i);
    start_i <= '0';
    verify("mid-pass B", MP_B, MP_X, done_o, u_o, fail);

    -- Report the overall result
    wait until rising_edge(clk_i);
    if fail = '0' then
        report "ENGINE TESTS PASS - Engine passes its MOT" severity note;
    else
        report "ENGINE TESTS FAILED" severity failure;
    end if;
    sim_done <= true;

    wait;
end process;

end architecture rtl;
