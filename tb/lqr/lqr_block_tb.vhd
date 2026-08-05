--------------------------------------------------------------------------------
--  File:   lqr_block_tb.vhd
--  Desc:   Block-level TB for the register (tier-2, table short) LQR variant.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.panda_consts.all;
use work.matrix_consts.all;
use work.lqr_consts.all;
use work.lqr_block_tb_pkg.all;


entity lqr_block_td is
end entity lqr_block_td;

architecture rtl of lqr_block_td is
    -- System
    constant p_clk_period : time := MASTER_CLK_PERIOD;
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    -- Ports
    signal clk_i : std_logic := '0';
    signal init_i : std_logic := '0';

    signal pos0_i, pos1_i, pos2_i : std_logic_vector(31 downto 0) := (others => '0');
    signal sp0_i, sp1_i, sp2_i : std_logic_vector(31 downto 0) := (others => '0');

    signal GAINS_START : std_logic_vector(31 downto 0) := (others => '0');
    signal GAINS_START_WSTB : std_logic := '0';
    signal GAINS_DATA : std_logic_vector(31 downto 0) := (others => '0');
    signal GAINS_DATA_WSTB : std_logic := '0';
    signal GAINS_LENGTH : std_logic_vector(31 downto 0) := (others => '0');
    signal GAINS_LENGTH_WSTB : std_logic := '0';

    signal COMMIT : std_logic_vector(31 downto 0) := (others => '0');
    signal COMMIT_WSTB : std_logic := '0';

    signal GEN : std_logic_vector(31 downto 0);
    signal u0_o, u1_o, u2_o : std_logic_vector(31 downto 0);
    signal u_valid_o : std_logic;

    -- Test data (raw counts)
    constant P0 : mac_data_vec(0 to AXES - 1) := (pv(10), pv(20), pv(30));
    constant P1 : mac_data_vec(0 to AXES - 1) := (pv(12), pv(22), pv(28));
    constant P2 : mac_data_vec(0 to AXES - 1) := (pv( 8), pv(25), pv(35));
    constant SP : mac_data_vec(0 to AXES - 1) := (pv( 5), pv(10), pv(15));

begin

    clkgen : process
    begin
        while not sim_done loop
            clk_i <= not clk_i;
            wait for p_clk_period / 2;
        end loop;
        wait;
    end process;

    uut : entity work.lqr_block
        port map (
            clk_i => clk_i,
            init_i => init_i,
            pos0_i => pos0_i, pos1_i => pos1_i, pos2_i => pos2_i,
            sp0_i => sp0_i, sp1_i => sp1_i, sp2_i => sp2_i,
            GAINS_START => GAINS_START,
            GAINS_START_WSTB => GAINS_START_WSTB,
            GAINS_DATA => GAINS_DATA,
            GAINS_DATA_WSTB => GAINS_DATA_WSTB,
            GAINS_LENGTH => GAINS_LENGTH,
            GAINS_LENGTH_WSTB => GAINS_LENGTH_WSTB,
            COMMIT => COMMIT,
            COMMIT_WSTB => COMMIT_WSTB,
            GEN => GEN,
            u0_o => u0_o, u1_o => u1_o, u2_o => u2_o,
            u_valid_o => u_valid_o
        );

    process
        variable u_prev : mac_data_vec(0 to M - 1) := (others => (others => '0'));
        variable gen0 : unsigned(31 downto 0);

        -- Register-burst fill: START resets the pointer, one DATA word per clk.
        procedure load_reg(constant g : in word_vec) is
        begin
            GAINS_START_WSTB <= '1';
            wait until rising_edge(clk_i);
            GAINS_START_WSTB <= '0';
            for i in g'range loop
                GAINS_DATA <= g(i);
                GAINS_DATA_WSTB <= '1';
                wait until rising_edge(clk_i);
            end loop;
            GAINS_DATA_WSTB <= '0';
        end procedure;

        -- Drive one servo pass, check u_o against the golden, thread u_prev.
        procedure servo_pass(
            constant name : in string;
            constant pc : in mac_data_vec;
            constant sp : in mac_data_vec
        ) is
            variable r : servo_res;
        begin
            r := servo(pc, sp, K, u_prev);
            pos0_i <= std_logic_vector(resize(pc(0), 32));
            pos1_i <= std_logic_vector(resize(pc(1), 32));
            pos2_i <= std_logic_vector(resize(pc(2), 32));
            sp0_i <= std_logic_vector(resize(sp(0), 32));
            sp1_i <= std_logic_vector(resize(sp(1), 32));
            sp2_i <= std_logic_vector(resize(sp(2), 32));

            wait until u_valid_o = '1';
            wait until falling_edge(clk_i);

            if signed(u0_o) /= resize(r.u(0), 32) then
                fail <= '1';
                report name & ": u(0) got " & integer'image(to_integer(signed(u0_o))) &
                    ", expected " & integer'image(to_integer(r.u(0))) severity error;
            end if;
            if signed(u1_o) /= resize(r.u(1), 32) then
                fail <= '1';
                report name & ": u(1) got " & integer'image(to_integer(signed(u1_o))) &
                    ", expected " & integer'image(to_integer(r.u(1))) severity error;
            end if;
            if signed(u2_o) /= resize(r.u(2), 32) then
                fail <= '1';
                report name & ": u(2) got " & integer'image(to_integer(signed(u2_o))) &
                    ", expected " & integer'image(to_integer(r.u(2))) severity error;
            end if;

            u_prev := r.unext;
            report name & " passes" severity note;
        end procedure;
    begin
        -- Reset
        wait until rising_edge(clk_i);
        init_i <= '1';
        wait until rising_edge(clk_i);
        init_i <= '0';
        wait until rising_edge(clk_i);

        gen0 := unsigned(GEN);

        -- Fill the inactive bank, then commit it live.
        load_reg(GAINS_FLAT);
        COMMIT_WSTB <= '1';
        wait until rising_edge(clk_i);
        COMMIT_WSTB <= '0';
        wait until rising_edge(clk_i);

        if unsigned(GEN) /= gen0 + 1 then
            fail <= '1';
            report "GEN did not increment on commit" severity error;
        end if;

        -- Servo passes (setpoint held).
        servo_pass("k0", P0, SP);
        servo_pass("k1", P1, SP);
        servo_pass("k2", P2, SP);

        wait until rising_edge(clk_i);
        if fail = '0' then
            report "LQR BLOCK (register) TESTS PASS" severity note;
        else
            report "LQR BLOCK (register) TESTS FAILED" severity failure;
        end if;
        sim_done <= true;

        wait;
    end process;

end architecture rtl;
