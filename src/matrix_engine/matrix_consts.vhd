--------------------------------------------------------------------------------
-- matrix_consts : shared constants for the time-multiplexed MAC engine.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

use work.panda_consts.all;


package matrix_consts is
    -- Constants
    constant LANE_A_W : natural := 42;
    constant LANE_B_W : natural := 32;
    constant ACCUM_GUARD : natural := 8;
    constant LANE_ACC_W : natural := LANE_A_W + LANE_B_W + ACCUM_GUARD;

    -- Arrays
    type mac_data_vec is array (natural range <>)
        of signed(LANE_A_W - 1 downto 0);
    type mac_gain_mat is array (natural range <>, natural range <>) 
        of signed(LANE_B_W - 1 downto 0);

    type mac_acc_vec is array (natural range <>) 
        of signed(LANE_ACC_W - 1 downto 0);


end package matrix_consts;
