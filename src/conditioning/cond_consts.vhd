--------------------------------------------------------------------------------
-- cond_consts : bits and pieces for the input conversion.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- use work.panda_consts.all;

package cond_consts is

    function n_channels(
        g_state, g_velocity, g_prev : boolean
    ) return natural;

    function cond_width (
        P : positive;
        g_state, g_velocity, g_prev : boolean
    ) return positive;

end package;

package body cond_consts is

    function n_channels(
        g_state, g_velocity, g_prev : boolean
    ) return natural is
    begin
        -- Sums all boolean trues
        return boolean'pos(g_state) + boolean'pos(g_velocity) + boolean'pos(g_prev);
    end function;

    function cond_width (
        P : positive;
        g_state, g_velocity, g_prev : boolean
    ) return positive is
    begin
        return P * n_channels(g_state, g_velocity, g_prev);
    end function;

end package body;