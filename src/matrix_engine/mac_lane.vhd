--------------------------------------------------------------------------------
--  File:   mac_lane.vhd
--  Desc:   A single MAC lane (DSP multiply+accumulate) on the PandA.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- A MAC lane
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
-- use work.fp_utils.all;
-- use work.num_utils.all;

entity mac_lane is
    generic (
        COEFF_W : natural := DSP_COEFF_W; -- Gain (DSP 25 port)
        DATA_W : natural := DSP_DATA_W; -- State/error (DSP 18 port)
        ACC_W : natural := DSP_ACC_W -- P accumulator
    );
    port (
        clk_i  : in std_logic; -- PandA clock
        init_i : in std_logic; -- PandA reset

        a_i : in signed(COEFF_W - 1 downto 0); -- Gain
        b_i : in signed(DATA_W - 1 downto 0); -- State/error
        load_i : in std_logic; -- '1' to load, '0' to accumulate
        en_i : in std_logic; -- is the operand valid this cycle?

        acc_o : out signed(ACC_W - 1 downto 0)
    );
end entity mac_lane;


architecture main of mac_lane is
    -- Consts
    constant PROD_W : natural := COEFF_W + DATA_W ;

    -- Registered data
    signal a_reg : signed(COEFF_W - 1 downto 0) := (others => '0');
    signal b_reg : signed(DATA_W - 1 downto 0) := (others => '0');

    signal m_reg : signed(PROD_W- 1 downto 0) := (others => '0');

    -- Shift registers
    signal load_d1 : std_logic := '0';
    signal load_d2 : std_logic := '0';
    signal en_d1 : std_logic := '0';
    signal en_d2 : std_logic := '0';

begin
    -- A single PandA DSP.
    DSP : entity work.panda1_dsp
    port map (
        clk_i => clk_i,
        rst_i => init_i,
        load_i => load_i,
        en_i => en_i,
        a_i => a_i,
        b_i => b_i,
        pcin_i => (others => '0'),
        acc_o => acc_o,
        pcout_o => open
    );
end main;
