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
-- use work.num_utils.all;
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
    signal k_i : mac_gain_mat(0 to M - 1, 0 to N - 1) :=
        -- 2D array => two levels + bits
        (others => (others => (others => '0')));
    signal x_i : mac_data_vec(0 to N - 1) :=
        -- 1D array => one level + bits
        (others => (others => '0'));

    signal start_i : std_logic := '0';

    signal done_o : std_logic;
    signal u_o : mac_acc_vec(0 to M - 1);

    -- Test definition
    procedure run_test (
        constant name : in string;
        constant k : mac_gain_mat;
        constant x : mac_data_vec;

        signal clk_i : in std_logic;
        signal k_i : out mac_gain_mat;
        signal x_i : out mac_data_vec;
        signal start_i : out std_logic;
        signal done_o : in std_logic;
        signal u_o : in mac_acc_vec;
        signal fail_o : out std_logic
    ) is
        -- Golden reference: plain full-width u = K * x
        variable exp : mac_acc_vec(u_o'range);
    begin
        for r in exp'range loop
            exp(r) := (others => '0');
            for c in x'range loop
                exp(r) := exp(r) + resize(k(r, c) * x(c), exp(r)'length);
            end loop;
        end loop;

        -- Load K and x
        k_i <= k;
        x_i <= x;
        wait until rising_edge(clk_i);

        -- Begin engine
        start_i <= '1';
        wait until rising_edge(clk_i);
        start_i <= '0';

        -- Wait until calculation is complete
        wait until done_o = '1';

        -- Report test result
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
            end if;
        end loop;
    end procedure;

    -- Test helpers
    function kv(v : integer) return signed is
    begin
    return to_signed(v, LANE_B_W); end;

    function xv(v : integer) return signed is
    begin
    return to_signed(v, LANE_A_W); end;

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
        k_i => k_i,
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
    run_test(
        "identity",
        (
            (kv(1), kv(0), kv(0)),
            (kv(0), kv(1), kv(0)),
            (kv(0), kv(0), kv(1))
        ),
        (
            (xv(2), xv(3), xv(4))
        ),
        clk_i, k_i, x_i, start_i, done_o, u_o, fail
    );
    run_test(
        "lower-tri",
        (
            (kv(1), kv(0), kv(0)),
            (kv(1), kv(1), kv(0)),
            (kv(1), kv(1), kv(1))
        ),
        (
            (xv(2), xv(3), xv(4))
        ),
        clk_i, k_i, x_i, start_i, done_o, u_o, fail
    );
    run_test(
        "negatives",
        (
            (kv(-1), kv(0), kv(0)),
            (kv(-1), kv(1), kv(0)),
            (kv(1), kv(1), kv(-1))
        ),
        (
            (xv(2), xv(3), xv(4))
        ),
        clk_i, k_i, x_i, start_i, done_o, u_o, fail
    );
    run_test(
        "extreme",
        (
            (kv(16777215), kv(0), kv(0)),
            (kv(0), kv(8388610), kv(0)),
            (kv(1499999), kv(-10), kv(16777215))
        ),
        (
            (xv(131071), xv(-131070), xv(-131070))
        ),
        clk_i, k_i, x_i, start_i, done_o, u_o, fail
    );
    run_test(
        "wide",
        (
            (kv(1000000), kv(0), kv(0)),
            (kv(0), kv(-500000), kv(0)),
            (kv(2000000), kv(-3000000), kv(4000000))
        ),
        (
            (xv(50000000), xv(-40000000), xv(30000000))
        ),
        clk_i, k_i, x_i, start_i, done_o, u_o, fail
    );

    -- Test interrupt/restart recovery
    k_i <= (
        (kv(1), kv(1), kv(1)),
        (kv(1), kv(1), kv(1)),
        (kv(1), kv(1), kv(1))
    );
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
    run_test(
        "post-interrupt",
        (
            (kv(1), kv(0), kv(-10)),
            (kv(8), kv(3), kv(0)),
            (kv(2), kv(1), kv(111))
        ),
        (
            (xv(20), xv(3), xv(54))
        ),
        clk_i, k_i, x_i, start_i, done_o, u_o, fail
    );

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
