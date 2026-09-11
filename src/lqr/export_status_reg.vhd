--------------------------------------------------------------------------------
--  File:   export_status_reg.vhd
--  Desc:   State-export status readback.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity export_status_reg is
    port (
        clk_i : in std_logic;
        init_i : in std_logic;
        busy_i : in std_logic; -- export in progress
        error_i : in std_logic; -- BRESP error pulse
        overrun_i : in std_logic; -- dropped export tick pulse
        status_o : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of export_status_reg is
    signal err_sticky : std_logic := '0';
    signal overrun_sticky : std_logic := '0';
begin
    status_o <= (0 => busy_i, 1 => err_sticky, 2 => overrun_sticky, others => '0');

    process(clk_i) begin
        if rising_edge(clk_i) then
            if init_i = '1' then
                err_sticky <= '0';
                overrun_sticky <= '0';
            else
                if error_i = '1' then
                    err_sticky <= '1';
                end if;
                if overrun_i = '1' then
                    overrun_sticky <= '1';
                end if;
            end if;
        end if;
    end process;
end architecture;
