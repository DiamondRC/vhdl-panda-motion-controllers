--------------------------------------------------------------------------------
-- cond_consts : bits and pieces for the input conversion.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.num_utils.all;
use work.fp_utils.all;
use work.matrix_consts.all;

-- use work.panda_consts.all;

package cond_consts is

    -- Encoder counts (256 pm/count) -> nm.
    constant PV_FRAC   : natural := 15;
    constant DES_FRAC  : natural := 10; -- Must equal lqr_consts.STATE_F
    constant FRAC_DIFF : natural := PV_FRAC - DES_FRAC;

    function n_channels(
        g_state, g_velocity, g_prev : boolean
    ) return natural;

    function cond_width (
        P : positive;
        g_state, g_velocity, g_prev : boolean
    ) return positive;

    function pv_scale (
        scale : real
    ) return natural;

    function to_nm (
        c : signed;
        scale : real
    ) return signed;

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

    function pv_scale (
        scale : real
    ) return natural is 
    begin
        return natural(scale * real(2 ** PV_FRAC));
    end function;

    function to_nm (
        c : signed;
        scale : real
    ) return signed is
        constant PV_SCALE : natural := pv_scale(scale);
        constant PV_SCALE_LEN : natural := ceil_log2(PV_SCALE) + 1; -- +1 = sign bit
        variable prod : signed(c'length + PV_SCALE_LEN - 1 downto 0);
    begin
        prod := c * to_signed(PV_SCALE, PV_SCALE_LEN); -- counts * 0.256
        return requantise(prod, FRAC_DIFF, LANE_A_W, HALF_AWAY); -- convert to input format
    end function;

end package body;