--------------------------------------------------------------------------------
-- matrix_consts : shared constants for the time-multiplexed MAC engine.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;


package matrix_consts is

    ------------------------------------------------------------------
    -- Q-format operand dictionary  (hybrid fixed-point contract)
    --
    -- These sfixed subtypes DOCUMENT the radix point of each engine
    -- operand.  The synthesised datapath works on raw `signed`; the
    -- integer widths are DERIVED from these bounds so there is a single
    -- source of truth.
    --
    -- The widths below are the exploratory sketch moved out of
    -- lqr_consts.vhd; final values will align to the DSP48E1 25x18
    -- geometry once the engine generics are pinned.
    ------------------------------------------------------------------
    -- subtype k_fx  is sfixed( 0 downto -15);  -- gain       (-> 25-bit port)
    -- subtype x_fx  is sfixed(15 downto  -8);  -- state/error(-> 18-bit port)
    -- subtype y_fx  is sfixed(31 downto -23);  -- product / accumulator

    -- x_fx <= to_sfixed(x_int, x_fx'high, x_fx'low);
    -- k_fx <= to_sfixed(0.256, k_fx'high, k_fx'low);
    -- y_fx <= resize(x_fx * k_fx, y_fx'high, y_fx'low);

end package matrix_consts;
