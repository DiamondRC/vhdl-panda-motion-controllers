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
        clk_i  : in std_logic; -- Servo rate clock, not PandA
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

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if init_i = '1' then
                a_reg <= (others => '0');
                b_reg <= (others => '0');
                m_reg <= (others => '0');
                load_d1 <= '0';
                load_d2 <= '0';
                en_d1 <= '0';
                en_d2 <= '0';
            else
                -- Stage 1
                a_reg <= a_i;
                b_reg <= b_i;
                load_d1 <= load_i;
                en_d1 <= en_i;

                -- Stage 2
                m_reg <= a_reg * b_reg;
                load_d2 <= load_d1;
                en_d2 <= en_d1;

                -- Stage 3
                if en_d2 = '1' then
                    if load_d2 = '1' then
                        -- Load
                        acc_o <= resize(m_reg, ACC_W);
                    else 
                        -- Accum
                        acc_o <= acc_o + resize(m_reg, ACC_W);
                    end if; -- load
                end if; -- enable
            end if; -- reset/logic
        end if; -- clock
    end process;

end main;
