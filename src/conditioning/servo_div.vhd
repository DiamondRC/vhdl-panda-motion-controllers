--------------------------------------------------------------------------------
--  File:   servo_div.vhd
--  Desc:   Handle the servo-rate conversion from the PandA master clock/
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Create the controller servo-rate
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
-- use work.fp_utils.all;
-- use work.num_utils.all;
-- use work.matrix_consts.all;
-- use work.mac_utils.all;
-- use work.lqr_consts.all;
-- use work.cond_consts.all;

entity servo_div is
    generic (
        -- 125MHz / DIV = servo-rate
        DIV : positive := 12500 -- 12500 = 20KHz
    );
    port (
        clk_i  : in std_logic; -- PandA master clock
        init_i : in std_logic; -- PandA reset

        tick_o : out std_logic -- Servo-rate
    );
end;

architecture main of servo_div is
    signal cnt : natural range 0 to DIV - 1;
begin

    process(clk_i) begin
        if rising_edge(clk_i) then
            if init_i = '1' then
                cnt <= 0;
                tick_o <= '0';
            else
                tick_o <= '0';
                if cnt = DIV - 1 then
                    cnt <= 0;
                    tick_o <= '1';
                else
                    cnt <= cnt + 1;
                end if;
            end if;
        end if;
    end process;

end architecture main;