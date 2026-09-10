--------------------------------------------------------------------------------
--  File:   nm_conversion.vhd
--  Desc:   Convert interferometry inputs to nm.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Convert interferometry input to nm.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
use work.fp_utils.all;
use work.num_utils.all;
use work.matrix_consts.all;
-- use work.mac_utils.all;
-- use work.lqr_consts.all;
use work.cond_consts.all;

entity nm_conversion is
    generic (
        C_W : positive;
        SCALE : real := 0.256
    );
    port (
        clk_i : in std_logic;
        c_i : in signed(C_W - 1 downto 0);
        nm_o : out signed(LANE_A_W - 1 downto 0)
    );
end entity;

architecture rtl of nm_conversion is
    constant PV_SCALE : natural := pv_scale(SCALE);
    constant PV_SCALE_LEN : natural := ceil_log2(PV_SCALE) + 1; -- +1 for sign
    constant PROD_W : natural := C_W + PV_SCALE_LEN;

    signal c_r : signed(C_W - 1 downto 0) := (others => '0');
    signal prod_r : signed(PROD_W - 1 downto 0) := (others => '0');

    attribute use_dsp : string;
    attribute use_dsp of prod_r : signal is "yes";
begin
    process(clk_i) begin
        if rising_edge(clk_i) then
            c_r <= c_i; -- 1) input reg
            prod_r <= c_r * to_signed(PV_SCALE, PV_SCALE_LEN); -- 2) DSP *
            nm_o <= requantise(prod_r, FRAC_DIFF, LANE_A_W, HALF_AWAY); -- 3) round + saturate
        end if;
    end process;
end architecture;