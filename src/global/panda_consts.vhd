library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package panda_consts is
    constant PANDA_PORT_SIZE   : natural := 32;
    constant MASTER_CLK_PERIOD : time    := 8 ns; -- 125 MHz clk

    -- DSP48E1 specs
    constant DSP_COEFF_W : natural := 25; -- DSP48E1 A-port operand (signed)
    constant DSP_DATA_W : natural := 18; -- DSP48E1 B-port operand (signed)
    constant DSP_ACC_W : natural := 48; -- DSP48E1 P accumulator

end package panda_consts;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package global_subtypes is
    use work.panda_consts.all;

    subtype panda_port is std_logic_vector(PANDA_PORT_SIZE - 1 downto 0);
end package global_subtypes;