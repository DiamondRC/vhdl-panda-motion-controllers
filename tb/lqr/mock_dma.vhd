--------------------------------------------------------------------------------
--  File:   mock_dma.vhd
--  Desc:   Behavioural PandA DMA read-engine slave for block-level TBs.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Adapted from the PGEN, mock the behaviour of the DMA read-engine slave.
-- Used for testing behaviour in simulation ahead of hardware deployment.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.lqr_block_tb_pkg.all;

entity mock_dma is
    generic (
        DEPTH : positive := 27; -- Backing memory words
        GAP : natural := 0 -- #Idle cycles between valid words
    );
    port (
        clk_i : in std_logic;
        mem_i : in word_vec(0 to DEPTH - 1); -- gain words (Q7.25)

        -- DMA slave side
        dma_req_i : in std_logic;
        dma_ack_o : out std_logic;
        dma_done_o : out std_logic;
        dma_addr_i : in std_logic_vector(31 downto 0);
        dma_len_i : in std_logic_vector(7 downto 0);
        dma_data_o : out std_logic_vector(31 downto 0);
        dma_valid_o : out std_logic
    );
end entity;

architecture rtl of mock_dma is
    type st_t is (IDLE, STREAM);
    signal st : st_t := IDLE;
begin

    process(clk_i)
        variable idx : integer := 0; -- word index into mem
        variable wleft : integer := 0; -- remaining words this burst
        variable gapc : integer := 0; -- gap counter
    begin
        if rising_edge(clk_i) then
            dma_ack_o <= '0';
            dma_valid_o <= '0';
            dma_done_o <= '0';

            case st is
                when IDLE =>
                    if dma_req_i = '1' then
                        idx := to_integer(unsigned(dma_addr_i)) / 4;
                        wleft := to_integer(unsigned(dma_len_i));
                        dma_ack_o <= '1'; -- 1-cycle ack, ~1 clk after req
                        gapc := 0;
                        st <= STREAM;
                    end if;

                when STREAM =>
                    if GAP /= 0 and gapc < GAP then
                        gapc := gapc + 1; -- stall valid (back-pressure)
                    else
                        gapc := 0;
                        dma_data_o <= mem_i(idx);
                        dma_valid_o <= '1';
                        if wleft = 1 then
                            dma_done_o <= '1'; -- coincident with last word
                            st <= IDLE;
                        end if;
                        idx := idx + 1;
                        wleft := wleft - 1;
                    end if;
            end case;
        end if;
    end process;

end architecture;
