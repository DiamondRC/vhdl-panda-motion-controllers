--------------------------------------------------------------------------------
-- lqr_consts
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all; -- Just using in consts/TB

use work.panda_consts.all;
-- use work.fp_utils.all;
-- use work.num_utils.all;
use work.matrix_consts.all;
-- use work.mac_utils.all;


package lqr_consts is
    -- Input Conversion
    -- -- Encoder counts (256 pm / count) -> nm: scale by INTER_SCALE = 0.256.
    -- constant PV_FRAC     : natural := 15;
    -- constant INTER_SCALE : real    := 0.256;

    -- constant PV_SCA_HI   : integer := PANDA_PORT_SIZE - PV_FRAC - 1;
    -- constant PV_SCA_LO   : integer := -PV_FRAC;

    -- constant PV_SCALE    : sfixed(PV_SCA_HI downto PV_SCA_LO) :=
    --     to_sfixed(INTER_SCALE, PV_SCA_HI, PV_SCA_LO);

    -- Integer/Frac sizes
    constant S_I : natural := 32;
    constant S_F : natural := 10;
    constant G_I : natural := 7;
    constant G_F : natural := 25;
    constant O_I : natural := 7;
    constant O_F : natural := 0; -- integer DAC output

    -- Q-format dict
    subtype state_fx is sfixed(S_I - 1 downto -(S_F));
    subtype gain_fx is sfixed(G_I - 1 downto -(G_F));
    subtype out_fx is sfixed(O_I - 1 downto -(O_F));

    -- Q-format sizes
    constant STATE_F : natural := -state_fx'low;
    constant GAIN_F : natural := -gain_fx'low;
    constant PROD_F : natural := GAIN_F + STATE_F; -- invariant accum frac
    constant OUT_W : natural := out_fx'length;
    constant OUT_F : natural := -out_fx'low;

    -- Literally just 1.0 in the correct Q format for the affine columns.
    constant ONE_FX  : signed(LANE_A_W - 1 downto 0) := 
        to_signed(2 ** STATE_F, LANE_A_W);

    -- Controller output
    subtype lqr_out is signed(OUT_W - 1 downto 0);
    type lqr_out_vec is array (natural range <>) of lqr_out;

    -- Helper functions
    function n_int(
        N : natural; -- State block width
        M : natural; -- Output width
        feats : natural; -- Feature block
        
        -- include the controller output, SP and affine?
        uprev, setpoint, affine: boolean
    ) return positive;

end package lqr_consts;


package body lqr_consts is

    function n_int(
        N : natural;
        M : natural;
        feats : natural;
        uprev, setpoint, affine: boolean
    ) return positive is
    begin
        return N + feats + 
            M * boolean'pos(uprev) + 
            N * boolean'pos(setpoint) + 
            boolean'pos(affine);
    end function;

end package body;