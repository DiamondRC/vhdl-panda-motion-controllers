library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.fixed_pkg.all;

package panda_constants is
    constant PANDA_PORT_SIZE   : natural := 32;
    constant MASTER_CLK_PERIOD : time    := 8 ns; -- 125 MHz clk

end package panda_constants;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.fixed_pkg.all;
use work.panda_constants.all;

package lqr_constants is

    ---------------------------- Inputs ----------------------------
    -- signal x_int   : signed(15 downto 0);
    -- signal x_fix   : sfixed(15 downto -8);
    -- signal k_fix   : sfixed(0 downto -15);
    -- signal y_fix   : sfixed(31 downto -23);
    
    -- x_fix <= to_sfixed(x_int, x_fix'high, x_fix'low);
    -- k_fix <= to_sfixed(0.256, k_fix'high, k_fix'low);
    -- y_fix <= resize(x_fix * k_fix, y_fix'high, y_fix'low);

    --------------------- Input Conversion ----------------------
    constant PV_FRAC       : natural := 15;
    constant INTER_SCALE   : real    := 0.256;

    constant PV_SCA_HI     : integer := PANDA_PORT_SIZE - PV_FRAC - 1;
    constant PV_SCA_LO     : integer := -PV_FRAC;

    constant PV_SCALE      : sfixed(PV_SCA_HI downto PV_SCA_LO) :=
        to_sfixed(INTER_SCALE, PV_SCA_HI, PV_SCA_LO);


end package lqr_constants;

package body lqr_constants is

    function ceil_log2(n : natural) return natural is
        variable v : natural := n - 1;
        variable r : natural := 0;
    begin
        while v > 0 loop
            v := v / 2;
            r := r + 1;
        end loop;
        return r;
    end function;

end package body lqr_constants;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package global_subtypes is
    use work.panda_constants.all;

    subtype panda_port is std_logic_vector(PANDA_PORT_SIZE - 1 downto 0);
end package global_subtypes;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package state_enum is
    type lqr_state is (
        INITIAL,
        STAGE_2,
        DONE
    );
end package state_enum;