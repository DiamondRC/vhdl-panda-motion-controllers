--------------------------------------------------------------------------------
-- fp_utils : fixed-point rounding / scaling primitives.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fp_utils is

    function round_half_away(
        s_in      : signed;
        FRAC_DIFF : natural;
        OUT_LEN   : natural
    ) return signed;

    function round_half_even(
        s_in      : signed;
        FRAC_DIFF : natural;
        OUT_LEN   : natural
    ) return signed;

    function pad_signed(
        s_in     : signed;
        PAD_BITS : natural;
        OUT_LEN  : natural
    ) return signed;

end package fp_utils;


package body fp_utils is

    ----------------------------------------------------------------------------
    -- Round half away from zero.
    --
    -- Bias is built with a shift so it never overflows the integer range.
    -- Costs one accumulation + wiring
    --
    -- Best used for the output sum - especially a bipolar signal symetric
    -- around zero (C++/Matlab's round(), LQR output)
    ----------------------------------------------------------------------------
    function round_half_away(
        s_in      : signed;
        FRAC_DIFF : natural;
        OUT_LEN   : natural
    ) return signed is
        variable v_ext  : signed(s_in'length downto 0);
        variable v_bias : signed(s_in'length downto 0);
    begin
        -- fast return
        if FRAC_DIFF = 0 then
            return resize(s_in, OUT_LEN);
        end if;

        v_ext  := resize(s_in, v_ext'length);
        v_bias := shift_left(to_signed(1, v_bias'length), FRAC_DIFF - 1); -- 2^(F-1)

        if s_in(s_in'high) = '1' then
            -- negative
            -- 2^(F-1) - 1
            v_bias := v_bias - 1;
        end if;

        v_ext := v_ext + v_bias;

        return resize(shift_right(v_ext, FRAC_DIFF), OUT_LEN);
    end function;

    ----------------------------------------------------------------------------
    -- Round half to even (banker's method).
    --
    -- Floor + non-negative remainder => symmetric across signs.
    -- Assumes s_in is a normalised signed and FRAC_DIFF <= s_in'length.
    -- Costs one increment adder + wiring.
    --
    -- Best used for re-accumulated values/values with a DC offset/asymetric
    -- pattern (Python/numpy round() ReLUs)
    ----------------------------------------------------------------------------
    function round_half_even(
        s_in      : signed;
        FRAC_DIFF : natural;
        OUT_LEN   : natural
    ) return signed is
        variable v_floor : signed(s_in'length downto 0); -- +1 guard bit
        variable v_drop  : unsigned(FRAC_DIFF - 1 downto 0);
        variable v_half  : unsigned(FRAC_DIFF - 1 downto 0);
        variable v_inc   : signed(s_in'length downto 0) := (others => '0');
    begin
        -- fast return
        if FRAC_DIFF = 0 then
            return resize(s_in, OUT_LEN);
        end if;

        v_floor := resize(shift_right(s_in, FRAC_DIFF), v_floor'length);
        v_drop  := unsigned(s_in(FRAC_DIFF - 1 downto 0));

        v_half  := (others => '0');
        v_half(FRAC_DIFF - 1) := '1'; -- 2^(F-1)

        if v_drop > v_half then
            v_inc := to_signed(1, v_inc'length);
        elsif v_drop = v_half then
            if v_floor(0) = '1' then
                -- odd => round to even
                v_inc := to_signed(1, v_inc'length);
            end if;
        end if;

        return resize(v_floor + v_inc, OUT_LEN);
    end function;

    ----------------------------------------------------------------------------
    -- Pad a signed for operations with other fixed point signed numbers.
    --
    -- Left-pad by PAD_BITS then resize to OUT_LEN.
    ----------------------------------------------------------------------------
    function pad_signed(
        s_in     : signed;
        PAD_BITS : natural;
        OUT_LEN  : natural
    ) return signed is
    begin
        if PAD_BITS /= 0 then
            return shift_left(resize(s_in, OUT_LEN), PAD_BITS);
        else
            return resize(s_in, OUT_LEN);
        end if;
    end function;

end package body fp_utils;
