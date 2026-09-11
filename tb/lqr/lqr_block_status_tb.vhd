--------------------------------------------------------------------------------
--  File: lqr_block_status_tb.vhd
--  Desc: Check EXPORT_STATUS readback and reset correctness.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.panda_consts.all;
use work.interface_types.all;
use work.acp_tb_pkg.all;

entity lqr_block_status_td is
end entity;

architecture rtl of lqr_block_status_td is
    constant CLK_PERIOD : time := MASTER_CLK_PERIOD;
    constant MEM_WORDS : positive := 16;

    signal clk : std_logic := '0';
    signal init : std_logic := '0';
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    signal export_status : std_logic_vector(31 downto 0);
    signal acp_bus : acp_interface := acp_init;
    signal berr : std_logic := '0';
    signal mem : word64_vec(0 to MEM_WORDS - 1);

    signal busy_seen : std_logic := '0'; -- bit0 witnessed high in flight

begin
    ----------------------------------------------------------------------------
    -- Clock + watchdog
    ----------------------------------------------------------------------------
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Allow room for warm-up plus several export periods before declaring a hang.
    watchdog : process
    begin
        wait until sim_done for 120000 * CLK_PERIOD;
        assert sim_done
            report "lqr_block_status_tb TIMEOUT - an export never completed"
            severity failure;
        wait;
    end process;

    ----------------------------------------------------------------------------
    -- DUT + mock slave (block acp record -> mock flat ports)
    ----------------------------------------------------------------------------
    uut : entity work.lqr_block
        port map (
            clk_i => clk,
            init_i => init,

            pos0_i => x"00000000",
            pos1_i => x"00000000",
            pos2_i => x"00000000",

            SP0_i => x"00000000",
            SP1_i => x"00000000",
            SP2_i => x"00000000",

            SV0_i => x"00000000",
            SV1_i => x"00000000",
            SV2_i => x"00000000",

            GAINS_START => x"00000000",
            GAINS_START_WSTB => '0',
            GAINS_DATA => x"00000000",
            GAINS_DATA_WSTB => '0',
            GAINS_LENGTH => x"00000000",
            GAINS_LENGTH_WSTB => '0',

            COMMIT => x"00000000",
            COMMIT_WSTB => '0',

            GEN => open,
            EXPORT_STATUS => export_status,
            acp => acp_bus,

            u0_o => open,
            u1_o => open,
            u2_o => open,
            u_valid_o => open
        );

    slave : entity work.mock_acp
        generic map (
            MEM_WORDS => MEM_WORDS
        )
        port map (
            clk_i => clk,
            init_i => init,
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
            berr_i => berr,

            mem_o => mem
        );

    -- bit0 is live busy,
    -- check if it went high during some export.
    busy_mon : process(clk)
    begin
        if rising_edge(clk) then
            if export_status(0) = '1' then
                busy_seen <= '1';
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Stimulus + checks
    ----------------------------------------------------------------------------
    stim : process
        procedure check(cond : boolean; msg : string) is
        begin
            assert cond report msg severity error;
            if not cond then fail <= '1'; end if;
        end procedure;

        -- Wait through one full export.
        procedure one_export is
        begin
            wait until rising_edge(clk) and export_status(0) = '1';
            wait until rising_edge(clk) and export_status(0) = '0';
        end procedure;

    begin
        init <= '1';
        wait for 4 * CLK_PERIOD;
        init <= '0';
        wait until rising_edge(clk);

        check(export_status(1) = '0', "Error sticky set out of reset");
        check(export_status(2) = '0', "Overrun sticky set out of reset");

        -- Clean export: nothing latches, and bit0 tracks the in-flight burst.
        berr <= '0';
        one_export;
        check(export_status(1) = '0', "Error sticky set on a clean export");
        check(busy_seen = '1', "bit0 never tracked an in-flight export");

        -- Errored export: SLVERR latches bit1.
        berr <= '1';
        one_export;
        check(export_status(1) = '1', "SLVERR did not latch the error sticky");

        -- Sticky holds across a subsequent clean export.
        berr <= '0';
        one_export;
        check(export_status(1) = '1', "Error sticky did not hold across a clean export");

        -- No overrun at this cadence (a tick never lands while busy).
        check(export_status(2) = '0', "Overrun sticky latched unexpectedly");

        -- INIT clears both sticky bits and leaves busy low at rest.
        init <= '1';
        wait for 4 * CLK_PERIOD;
        init <= '0';
        wait until rising_edge(clk);
        check(export_status(1) = '0', "INIT did not clear the error sticky");
        check(export_status(2) = '0', "INIT did not clear the overrun sticky");
        check(export_status(0) = '0', "Busy asserted at rest after INIT");

        wait until rising_edge(clk);
        if fail = '0' then
            report "lqr_block_status_tb PASSED" severity note;
        else
            report "lqr_block_status_tb FAILED" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;
end architecture;
