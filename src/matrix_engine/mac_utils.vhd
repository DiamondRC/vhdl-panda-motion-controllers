--------------------------------------------------------------------------------
-- mac_utils : FSM and stream versioning utils.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.panda_consts.all;

package mac_utils is

    -- Constants
    constant GEN_W : positive := 16; -- Stream version tag (A->B->A)

    -- FSM
    type engine_state is (
        IDLE,
        FEED,
        DRAIN,
        CAPTURE,
        DONE
    );
    

end package mac_utils;