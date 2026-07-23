--------------------------------------------------------------------------------
--  File:   panda1_dsp.vhd
--  Desc:   A single DSP48E1 unit on the PandA.
--          Adapted from the Xilinx HDL Language Template, version 2023.2
--          DSP48E1: 48-bit Multi-Functional Arithmetic Block, Virtex-7
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- One DSP48E1 unit
--------------------------------------------------------------------------------

library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity panda1_dsp is
    port (
        clk_i, rst_i, load_i, en_i : in std_logic;
        a_i : in signed(24 downto 0);
        b_i : in signed(17 downto 0);
        pcin_i : in signed(47 downto 0);
        acc_o : out signed(47 downto 0);
        pcout_o : out signed(47 downto 0)
    );
end entity panda1_dsp;

architecture trl of panda1_dsp is
    signal p_slv : std_logic_vector(47 downto 0);
    signal pcout_slv : std_logic_vector(47 downto 0);
    signal a_ext : std_logic_vector(29 downto 0);
    signal opmode : std_logic_vector(6 downto 0);

begin
    opmode <= (others => '0');

    -- SLV -> signed boundary
    acc_o   <= signed(p_slv);
    pcout_o <= signed(pcout_slv);
    a_ext   <= std_logic_vector(resize(a_i, 30));

    dsp_inst : DSP48E1
        generic map (
            -- Feature Control Attributes: Data Path Selection
            A_INPUT => "DIRECT",               -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
            B_INPUT => "DIRECT",               -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
            USE_DPORT => FALSE,                -- Select D port usage (TRUE or FALSE)
            USE_MULT => "MULTIPLY",            -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
            USE_SIMD => "ONE48",               -- SIMD selection ("ONE48", "TWO24", "FOUR12")

            -- Pattern Detector Attributes: Pattern Detection Configuration
            AUTORESET_PATDET => "NO_RESET",    -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH"
            MASK => X"3fffffffffff",           -- 48-bit mask value for pattern detect (1=ignore)
            PATTERN => X"000000000000",        -- 48-bit pattern match for pattern detect
            SEL_MASK => "MASK",                -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2"
            SEL_PATTERN => "PATTERN",          -- Select pattern value ("PATTERN" or "C")
            USE_PATTERN_DETECT => "NO_PATDET", -- Enable pattern detect ("PATDET" or "NO_PATDET")

            -- Register Control Attributes: Pipeline Register Configuration
            ACASCREG => 1,                     -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
            ADREG => 1,                        -- Number of pipeline stages for pre-adder (0 or 1)
            ALUMODEREG => 1,                   -- Number of pipeline stages for ALUMODE (0 or 1)
            AREG => 1,                         -- Number of pipeline stages for A (0, 1 or 2)
            BCASCREG => 1,                     -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
            BREG => 1,                         -- Number of pipeline stages for B (0, 1 or 2)
            CARRYINREG => 1,                   -- Number of pipeline stages for CARRYIN (0 or 1)
            CARRYINSELREG => 1,                -- Number of pipeline stages for CARRYINSEL (0 or 1)
            CREG => 1,                         -- Number of pipeline stages for C (0 or 1)
            DREG => 1,                         -- Number of pipeline stages for D (0 or 1)
            INMODEREG => 1,                    -- Number of pipeline stages for INMODE (0 or 1)
            MREG => 1,                         -- Number of multiplier pipeline stages (0 or 1)
            OPMODEREG => 1,                    -- Number of pipeline stages for OPMODE (0 or 1)
            PREG => 1                          -- Number of pipeline stages for P (0 or 1)
        )
        port map (
            -- Cascade: 30-bit (each) output: Cascade Ports
            ACOUT => open,                    -- 30-bit output: A port cascade output
            BCOUT => open,                    -- 18-bit output: B port cascade output
            CARRYCASCOUT => open,             -- 1-bit output: Cascade carry output
            MULTSIGNOUT => open,              -- 1-bit output: Multiplier sign cascade output
            PCOUT => pcout_slv,               -- 48-bit output: Cascade output

            -- Control: 1-bit (each) output: Control Inputs/Status Bits
            OVERFLOW => open,                 -- 1-bit output: Overflow in add/acc output
            PATTERNBDETECT => open,           -- 1-bit output: Pattern bar detect output
            PATTERNDETECT => open,            -- 1-bit output: Pattern detect output
            UNDERFLOW => open,                -- 1-bit output: Underflow in add/acc output

            -- Data: 4-bit (each) output: Data Ports
            CARRYOUT => open,                 -- 4-bit output: Carry output
            P => p_slv,                       -- 48-bit output: Primary data output

            -- Cascade: 30-bit (each) input: Cascade Ports
            ACIN => (others => '0'),          -- 30-bit input: A cascade data input
            BCIN => (others => '0'),          -- 18-bit input: B cascade input
            CARRYCASCIN => '0',               -- 1-bit input: Cascade carry input
            MULTSIGNIN => '0',                -- 1-bit input: Multiplier sign input
            PCIN => std_logic_vector(pcin_i), -- 48-bit input: P cascade input

            -- Control: 4-bit (each) input: Control Inputs/Status Bits
            ALUMODE => "0000",                -- 4-bit input: ALU control input (Z + X + Y, add)
            CARRYINSEL => "000",              -- 3-bit input: Carry select input
            CLK => clk_i,
            INMODE => "00000",                -- 5-bit input: INMODE control input (A2 * B2)
            OPMODE => opmode,                 -- 7-bit input: Operation mode input (TODO: load/accumulate)

            -- Data: 30-bit (each) input: Data Ports
            A => a_ext,
            B => std_logic_vector(b_i),
            C => (others => '0'),             -- 48-bit input: C data input
            CARRYIN => '0',                   -- 1-bit input: Carry input signal
            D => (others => '0'),             -- 25-bit input: D data input

            -- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
            CEA1 => '1',                      -- 1-bit input: Clock enable input for 1st stage AREG
            CEA2 => '1',                      -- 1-bit input: Clock enable input for 2nd stage AREG
            CEAD => '1',                      -- 1-bit input: Clock enable input for ADREG
            CEALUMODE => '1',                 -- 1-bit input: Clock enable input for ALUMODE
            CEB1 => '1',                      -- 1-bit input: Clock enable input for 1st stage BREG
            CEB2 => '1',                      -- 1-bit input: Clock enable input for 2nd stage BREG
            CEC => '1',                       -- 1-bit input: Clock enable input for CREG
            CECARRYIN => '1',                 -- 1-bit input: Clock enable input for CARRYINREG
            CECTRL => '1',                    -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
            CED => '1',                       -- 1-bit input: Clock enable input for DREG
            CEINMODE => '1',                  -- 1-bit input: Clock enable input for INMODEREG
            CEM => '1',                       -- 1-bit input: Clock enable input for MREG
            CEP => '1',                       -- 1-bit input: Clock enable input for PREG (TODO: gate with en_i)
            RSTA => rst_i,                    -- 1-bit input: Reset input for AREG
            RSTALLCARRYIN => rst_i,           -- 1-bit input: Reset input for CARRYINREG
            RSTALUMODE => rst_i,              -- 1-bit input: Reset input for ALUMODEREG
            RSTB => rst_i,                    -- 1-bit input: Reset input for BREG
            RSTC => rst_i,                    -- 1-bit input: Reset input for CREG
            RSTCTRL => rst_i,                 -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
            RSTD => rst_i,                    -- 1-bit input: Reset input for DREG and ADREG
            RSTINMODE => rst_i,               -- 1-bit input: Reset input for INMODEREG
            RSTM => rst_i,                    -- 1-bit input: Reset input for MREG
            RSTP => rst_i                     -- 1-bit input: Reset input for PREG
        );
end architecture;
