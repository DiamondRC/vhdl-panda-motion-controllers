--------------------------------------------------------------------------------
--  File:   bram_store.vhd
--  Desc:   The weights/gain storage for the PandA's MAC engine.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- BRAM Feed
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
-- use work.fp_utils.all;
use work.num_utils.all;
-- use work.matrix_consts.all;
-- use work.mac_utils.all;

entity bram_store is
    generic (
        DEPTH : natural := 9; -- M * N
        DATA_W : natural := 32 -- Gain width
    );
    port (
        clk_i : in std_logic; -- PandA clock

        -- Write
        wr_addr_i : in unsigned(ceil_log2(DEPTH) - 1 downto 0);
        wr_data_i : in signed(DATA_W - 1 downto 0);
        wr_en_i : in std_logic;

        -- Read
        rd_addr_i : in unsigned(ceil_log2(DEPTH) - 1 downto 0);
        rd_data_o : out signed(DATA_W - 1 downto 0) -- valid in 2 cycles
    );
end entity bram_store;

architecture main of bram_store is
    -- Constants
    constant ADDR_W : natural := ceil_log2(DEPTH);

    -- Physcial BRAM memory (READ_FIRST)
    type ram_t is array (0 to 2 ** ADDR_W - 1) of std_logic_vector(DATA_W - 1 downto 0);

    -- Signals
    signal ram : ram_t; 
    signal rd_m : std_logic_vector(DATA_W - 1 downto 0); -- Stage 1: BRAM core read
    signal rd_r : std_logic_vector(DATA_W - 1 downto 0); -- Stage 2: output register

    -- Attributes
    attribute ram_style : string; -- Force BRAM synthesis.
    attribute ram_style of ram : signal is "block";

begin
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if wr_en_i = '1' then -- Write to BRAM
                ram(to_integer(wr_addr_i)) <= std_logic_vector(wr_data_i);
            end if;

            rd_m <= ram(to_integer(rd_addr_i)); -- Read a word in BRAM
            
            -- Send to output register
            -- (PandA has the cycle budget for the output register,
            -- thus we can benefit from higher Fmax).
            rd_r <= rd_m;
        end if;
    end process;
    rd_data_o <= signed(rd_r);

end architecture main;