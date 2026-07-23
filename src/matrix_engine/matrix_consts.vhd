--------------------------------------------------------------------------------
-- matrix_consts : shared constants for the time-multiplexed MAC engine.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

use work.panda_consts.all;


package matrix_consts is
    type mac_data_vec is array (natural range <>)
        of signed(DSP_DATA_W - 1 downto 0);
    type mac_gain_mat is array (natural range <>, natural range <>) 
        of signed(DSP_COEFF_W - 1 downto 0);

    type mac_acc_vec is array (natural range <>) 
        of signed(DSP_ACC_W - 1 downto 0);

end package matrix_consts;
