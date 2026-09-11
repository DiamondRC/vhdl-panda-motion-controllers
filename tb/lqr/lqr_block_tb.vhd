--------------------------------------------------------------------------------
--  File:   lqr_block_tb.vhd
--  Desc:   Exercise the full LQR VHDL trip, from AXI in to ACP out.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.panda_consts.all;
use work.matrix_consts.all;
use work.lqr_consts.all;
use work.interface_types.all;
use work.acp_tb_pkg.all;
use work.lqr_block_tb_pkg.all;


entity lqr_block_td is
end entity lqr_block_td;

architecture rtl of lqr_block_td is
    -- System
    constant p_clk_period : time := MASTER_CLK_PERIOD;
    constant MEM_WORDS : positive := 16;
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    -- Ports
    signal clk_i : std_logic := '0';
    signal init_i : std_logic := '0';

    signal pos0_i, pos1_i, pos2_i : std_logic_vector(31 downto 0) := (others => '0');
    signal sp0_i, sp1_i, sp2_i : std_logic_vector(31 downto 0) := (others => '0');
    signal sv0_i, sv1_i, sv2_i : std_logic_vector(31 downto 0) := (others => '0');

    signal GAINS_START : std_logic_vector(31 downto 0) := (others => '0');
    signal GAINS_START_WSTB : std_logic := '0';
    signal GAINS_DATA : std_logic_vector(31 downto 0) := (others => '0');
    signal GAINS_DATA_WSTB : std_logic := '0';
    signal GAINS_LENGTH : std_logic_vector(31 downto 0) := (others => '0');
    signal GAINS_LENGTH_WSTB : std_logic := '0';

    signal COMMIT : std_logic_vector(31 downto 0) := (others => '0');
    signal COMMIT_WSTB : std_logic := '0';

    signal GEN : std_logic_vector(31 downto 0);
    signal EXPORT_STATUS : std_logic_vector(31 downto 0);
    signal u0_o, u1_o, u2_o : std_logic_vector(31 downto 0);
    signal u_valid_o : std_logic;

    -- ACP export sink
    signal acp_bus : acp_interface := acp_init;
    signal mem : word64_vec(0 to MEM_WORDS - 1);

    -- Test data (raw counts). SP holds [ sp_pos | sp_vel ] (REF wide).
    constant P0 : mac_data_vec(0 to AXES - 1) := (pv(10), pv(20), pv(30));
    constant P1 : mac_data_vec(0 to AXES - 1) := (pv(12), pv(22), pv(28));
    constant P2 : mac_data_vec(0 to AXES - 1) := (pv( 8), pv(25), pv(35));
    constant SP : mac_data_vec(0 to REF - 1) :=
        (pv(5), pv(10), pv(15), pv(1), pv(2), pv(3));

begin

    clkgen : process
    begin
        while not sim_done loop
            clk_i <= not clk_i;
            wait for p_clk_period / 2;
        end loop;
        wait;
    end process;

    -- DIV=12500 => warm-up plus a few passes runs long; fail loud on a hang.
    watchdog : process
    begin
        wait until sim_done for 120000 * p_clk_period;
        assert sim_done
            report "lqr_block_tb TIMEOUT - a servo pass never completed"
            severity failure;
        wait;
    end process;

    uut : entity work.lqr_block
        port map (
            clk_i => clk_i,
            init_i => init_i,
            pos0_i => pos0_i, pos1_i => pos1_i, pos2_i => pos2_i,
            SP0_i => sp0_i, SP1_i => sp1_i, SP2_i => sp2_i,
            SV0_i => sv0_i, SV1_i => sv1_i, SV2_i => sv2_i,
            GAINS_START => GAINS_START,
            GAINS_START_WSTB => GAINS_START_WSTB,
            GAINS_DATA => GAINS_DATA,
            GAINS_DATA_WSTB => GAINS_DATA_WSTB,
            GAINS_LENGTH => GAINS_LENGTH,
            GAINS_LENGTH_WSTB => GAINS_LENGTH_WSTB,
            COMMIT => COMMIT,
            COMMIT_WSTB => COMMIT_WSTB,
            GEN => GEN,
            EXPORT_STATUS => EXPORT_STATUS,
            u0_o => u0_o, u1_o => u1_o, u2_o => u2_o,
            acp => acp_bus,
            u_valid_o => u_valid_o
        );

    slave : entity work.mock_acp
        generic map (
            MEM_WORDS => MEM_WORDS
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            awvalid_i => acp_bus.awvalid,
            awready_o => acp_bus.awready,
            awaddr_i => acp_bus.awaddr,
            awlen_i => acp_bus.awlen,

            wvalid_i => acp_bus.wvalid,
            wready_o => acp_bus.wready,
            wdata_i => acp_bus.wdata,
            wstrb_i => acp_bus.wstrb,
            wlast_i => acp_bus.wlast,

            bvalid_o => acp_bus.bvalid,
            bready_i => acp_bus.bready,
            bresp_o => acp_bus.bresp,

            w_wait_i => 0,
            berr_i => '0',

            mem_o => mem
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
            constant pc : in mac_data_vec; -- current position
            constant pp : in mac_data_vec; -- previous position (vel + prev)
            constant sp : in mac_data_vec -- setpoint [ sp_pos | sp_vel ]
        ) is
            variable r : servo_res;
        begin
            r := servo(pc, pp, sp, K, u_prev);
            pos0_i <= std_logic_vector(resize(pc(0), 32));
            pos1_i <= std_logic_vector(resize(pc(1), 32));
            pos2_i <= std_logic_vector(resize(pc(2), 32));
            sp0_i <= std_logic_vector(resize(sp(0), 32));
            sp1_i <= std_logic_vector(resize(sp(1), 32));
            sp2_i <= std_logic_vector(resize(sp(2), 32));
            sv0_i <= std_logic_vector(resize(sp(3), 32));
            sv1_i <= std_logic_vector(resize(sp(4), 32));
            sv2_i <= std_logic_vector(resize(sp(5), 32));

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

        -- Warm-up holds P0 (vel = 0, prev = P0), then the position sequence.
        servo_pass("k0", P0, P0, SP);
        servo_pass("k1", P1, P0, SP);
        servo_pass("k2", P2, P1, SP);

        -- One commit => one swap at the next pass boundary => GEN + 1.
        if unsigned(GEN) /= gen0 + 1 then
            fail <= '1';
            report "GEN did not increment after commit" severity error;
        end if;

        -- Exports have been running each tick against a clean slave.
        if EXPORT_STATUS(1) = '1' then
            fail <= '1';
            report "EXPORT_STATUS error set on clean exports" severity error;
        end if;

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
