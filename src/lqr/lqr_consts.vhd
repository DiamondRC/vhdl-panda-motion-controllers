--------------------------------------------------------------------------------
-- lqr_consts
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;
use work.panda_consts.all;


package lqr_consts is

    --------------------- Input Conversion ----------------------
    -- Encoder counts (256 pm / count) -> nm: scale by INTER_SCALE = 0.256.
    constant PV_FRAC     : natural := 15;
    constant INTER_SCALE : real    := 0.256;

    constant PV_SCA_HI   : integer := PANDA_PORT_SIZE - PV_FRAC - 1;
    constant PV_SCA_LO   : integer := -PV_FRAC;

    constant PV_SCALE    : sfixed(PV_SCA_HI downto PV_SCA_LO) :=
        to_sfixed(INTER_SCALE, PV_SCA_HI, PV_SCA_LO);

end package lqr_consts;
