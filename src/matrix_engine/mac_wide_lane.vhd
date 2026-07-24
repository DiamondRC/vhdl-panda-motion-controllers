--------------------------------------------------------------------------------
--  File:   mac_wide_lane.vhd
--  Desc:   A wide MAC lane (multiple DSPs multiply+accumulate) on the PandA.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- A wide MAC lane
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
-- use work.fp_utils.all;
use work.num_utils.all;

entity mac_wide_lane is
    generic (
        A_W : natural := DSP_COEFF_W; -- 25-bit operand (WIDE) 
        B_W : natural := DSP_DATA_W; -- 18-bit operand (NARROW)
        ACC_W : natural := DSP_ACC_W -- Accumulator
    );
    port (
        clk_i  : in std_logic; -- PandA clock
        init_i : in std_logic; -- PandA reset

        a_i : in signed(A_W - 1 downto 0); -- WIDE
        b_i : in signed(B_W - 1 downto 0); -- NARROW
        load_i : in std_logic; -- '1' to load, '0' to accumulate
        en_i : in std_logic; -- is the operand valid this cycle?

        acc_o : out signed(ACC_W - 1 downto 0)
    );
end entity mac_wide_lane;


architecture main of mac_wide_lane is
    -- Constants
    constant PROD_W : natural := A_W + B_W ;
    constant N_A : natural := num_chunks(A_W, DSP_COEFF_W); -- # 25 bit DSP chunks
    constant N_B : natural := num_chunks(B_W, DSP_DATA_W); -- # 18 bit DSP chunks
    constant A_STRIDE : natural := DSP_COEFF_W - 1; -- 24
    constant B_STRIDE : natural := DSP_DATA_W  - 1; -- 17

    -- Arrays
    type a_chunks_t is array (0 to N_A - 1) of signed(DSP_COEFF_W - 1 downto 0);
    type b_chunks_t is array (0 to N_B - 1) of signed(DSP_DATA_W - 1 downto 0);
    type parts_t is array (0 to N_A - 1, 0 to N_B - 1) of
        signed(DSP_COEFF_W + DSP_DATA_W - 1 downto 0);
    type cell_acc_t is array (0 to N_A - 1, 0 to N_B - 1) of signed(DSP_ACC_W - 1 downto 0);

    -- Signals
    signal a_chunks : a_chunks_t;
    signal b_chunks : b_chunks_t;
    signal cell_acc : cell_acc_t;
    signal parts : parts_t; -- stores multiplication result
    signal full_prod : signed(PROD_W - 1 downto 0);

begin

    -- ---------------------------------------------------------------------------
    -- Split up input to feed into DSP unit(s).
    --
    -- If N_A/N_B = 1 generate range = null so the upper
    -- range is the entire operand.
    -- ---------------------------------------------------------------------------

    -- WIDE input
    gen_a_lower : for i in 0 to N_A - 2 generate
        -- lower, zero-extend
        a_chunks(i) <= signed(
            resize(
                unsigned(a_i(A_STRIDE * i + (A_STRIDE - 1) downto A_STRIDE * i)),
                DSP_COEFF_W
            )
        );
    end generate gen_a_lower;
 
    a_chunks(N_A - 1) <= resize(
        -- upper, sign-extend
        a_i(A_W - 1 downto A_STRIDE * (N_A - 1)),
        DSP_COEFF_W
    );
    
    -- ---------------------------------------------------------------------------

    -- NARROW input
    gen_b_lower : for i in 0 to N_B - 2 generate
        -- lower, zero-extend
        b_chunks(i) <= signed(
            resize(
                unsigned(b_i(B_STRIDE * i + (B_STRIDE - 1) downto B_STRIDE * i)),
                DSP_DATA_W
            )
        );
    end generate gen_b_lower;

    b_chunks(N_B - 1) <= resize(
        -- upper, sign-extend
        b_i(B_W - 1 downto B_STRIDE * (N_B - 1)),
        DSP_DATA_W
    );

    -- ---------------------------------------------------------------------------

    -- Multiply and accumulate the result in DSP unit(s).
    gen_a : for i in 0 to N_A - 1 generate
        gen_b : for j in 0 to N_B - 1 generate
            cell : entity work.panda1_dsp
                port map (
                    clk_i => clk_i,
                    rst_i => init_i,
                    load_i => load_i,
                    en_i => en_i,
                    a_i => a_chunks(i),
                    b_i => b_chunks(j),
                    pcin_i => (others => '0'),
                    acc_o => cell_acc(i, j),
                    pcout_o => open
                );
        end generate;
    end generate;

    -- ---------------------------------------------------------------------------

    -- Combine all the cell outputs
    combine : process(cell_acc)
        variable v : signed(ACC_W - 1 downto 0);
    begin
        v := (others => '0');
        for i in 0 to N_A -1 loop
            for j in 0 to N_B -1 loop
                v := v + shift_left(
                    resize(
                        cell_acc(i, j), ACC_W
                    ),
                    A_STRIDE * i + B_STRIDE * j
                );
            end loop;
        end loop;
        acc_o <= v;

    end process;

    -- ---------------------------------------------------------------------------
    

    -- -- A single PandA DSP.
    -- DSP : entity work.panda1_dsp
    -- port map (
    --     clk_i => clk_i,
    --     rst_i => init_i,
    --     load_i => load_i,
    --     en_i => en_i,
    --     a_i => a_i,
    --     b_i => b_i,
    --     pcin_i => (others => '0'),
    --     acc_o => acc_o,
    --     pcout_o => open
    -- );
end main;