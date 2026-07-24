--------------------------------------------------------------------------------
-- mac_utils : FSM and test helpers
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.panda_consts.all;

package mac_utils is

    type engine_state is (
        IDLE,
        FEED,
        DRAIN,
        CAPTURE,
        DONE
    );
    

end package mac_utils;