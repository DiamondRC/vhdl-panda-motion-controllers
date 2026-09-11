--------------------------------------------------------------------------------
--  File:   export_status_reg_tb.vhd
--  Desc:   Unit TB for the EXPORT_STATUS sticky register.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.panda_consts.all; -- MASTER_CLK_PERIOD

entity export_status_reg_td is
end entity;

architecture rtl of export_status_reg_td is
    constant CLK_PERIOD : time := MASTER_CLK_PERIOD;

    signal clk : std_logic := '0';
    signal init : std_logic := '0';

    signal busy : std_logic := '0';
    signal err : std_logic := '0';
    signal overrun : std_logic := '0';
    signal status : std_logic_vector(31 downto 0);

    signal sim_done : boolean := false;
    signal fail : std_logic := '0';
begin
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    dut : entity work.export_status_reg
        port map (
            clk_i => clk,
            init_i => init,
            busy_i => busy,
            error_i => err,
            overrun_i => overrun,
            status_o => status
        );

    stim : process
        procedure check(cond : boolean; msg : string) is
        begin
            assert cond report msg severity error;
            if not cond then fail <= '1'; end if;
        end procedure;
    begin
        -- Reset -> nothing latched
        init <= '1';
        wait until rising_edge(clk);
        init <= '0';
        wait until rising_edge(clk);
        check(status = x"00000000", "status not clear out of reset");

        -- bit0 = live busy (combinational, not sticky)
        busy <= '1';
        wait until rising_edge(clk);
        check(status(0) = '1', "bit0 did not follow busy high");
        busy <= '0';
        wait until rising_edge(clk);
        check(status(0) = '0', "bit0 did not follow busy low");

        -- bit1 latches on an error pulse and holds
        err <= '1';
        wait until rising_edge(clk);
        err <= '0';
        wait until rising_edge(clk);
        check(status(1) = '1', "error pulse did not latch bit1");
        for i in 0 to 3 loop
            wait until rising_edge(clk);
        end loop;
        check(status(1) = '1', "error sticky did not hold");

        -- bit2 latches on an overrun pulse and holds
        overrun <= '1';
        wait until rising_edge(clk);
        overrun <= '0';
        wait until rising_edge(clk);
        check(status(2) = '1', "overrun pulse did not latch bit2");
        check(status(1) = '1', "error sticky lost when overrun latched");

        -- INIT clears both sticky bits
        init <= '1';
        wait until rising_edge(clk);
        init <= '0';
        wait until rising_edge(clk);
        check(status(1) = '0', "INIT did not clear error sticky");
        check(status(2) = '0', "INIT did not clear overrun sticky");

        wait until rising_edge(clk);
        if fail = '0' then
            report "export_status_reg_tb PASSED" severity note;
        else
            report "export_status_reg_tb FAILED" severity failure;
        end if;
        sim_done <= true;
        wait;
    end process;
end architecture;
