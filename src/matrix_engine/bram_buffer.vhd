--------------------------------------------------------------------------------
--  File:   bram_buffer.vhd
--  Desc:   A double-buffer to prevent tearing as we stream to PandA BRAM.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- BRAM Buffer
--
-- Coherency protocol for the DMA/BRAM release/aquire handshake.
-- 
-- The Reader (MAC engine) reads the buffer every cycle without locking.
-- The Writer (DMA) fills the write buffer, pulses the commit flag and 
-- waits until the gen counter increments (the swap as landed).
-- 
-- The swap is deferred from commit until the next pass starts.
-- An ongoing computation completes using the old values and the
-- swap occurs at the pass boundary (pass being one full computation across
-- all M rows, not just a single row).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
-- use work.fp_utils.all;
use work.num_utils.all;
-- use work.matrix_consts.all;
use work.mac_utils.all;

entity bram_buffer is
    generic (
        NUM_BUFFERS : positive := 2; -- BRAM instances
        DEPTH : positive; -- Size of BRAM
        DATA_W : positive -- ^
    );
    port (
        clk_i  : in std_logic; -- PandA master clock
        init_i : in std_logic; -- PandA reset

        -- Write side - DMA fills the inactive buffer
        wr_addr_i : in unsigned(ceil_log2(DEPTH) - 1 downto 0);
        wr_data_i : in signed(DATA_W - 1 downto 0);
        wr_en_i : in std_logic;
        commit_i : in std_logic; -- Is buffer filled?

        -- Read side - MAC engine
        rd_addr_i : in unsigned(ceil_log2(DEPTH) - 1 downto 0);
        rd_data_o : out signed(DATA_W - 1 downto 0); -- 2 cycle delay
        pass_start_i : in std_logic; -- Is it safe to swap?

        -- Atomic version tag
        -- Solves A->B->A problem.
        gen_o : out unsigned(GEN_W - 1 downto 0)
    );
end entity;


architecture main of bram_buffer is
    -- Arrays
    type buf_out_t is array (0 to NUM_BUFFERS - 1) of signed(DATA_W - 1 downto 0);

    -- Signals
    signal active_buf : natural range 0 to NUM_BUFFERS - 1;
    signal write_buff : natural range 0 to NUM_BUFFERS - 1;
    signal pending : std_logic;
    signal gen : unsigned(GEN_W - 1 downto 0);

    signal buf_rd : buf_out_t; -- N read outputs.
    signal buf_we : std_logic_vector(0 to NUM_BUFFERS - 1); -- per-buffer write enables

begin

    -- Write the active buffer
    write_buff <= (active_buf + 1) mod NUM_BUFFERS;

    -- Write to the fill buffer
    -- Demux selects which of the buffers to write too.
    gen_we : for i in 0 to NUM_BUFFERS - 1 generate
        buf_we(i) <= wr_en_i when i = write_buff else '0';
    end generate;

    -- Link buffer to all BRAM instances
    gen_buf : for i in 0 to NUM_BUFFERS - 1 generate
        u_store : entity work.bram_store
            generic map (
                DEPTH => DEPTH,
                DATA_W => DATA_W
            )
            port map (
                clk_i => clk_i,
                wr_addr_i => wr_addr_i, -- broadcast
                wr_data_i => wr_data_i, -- broadcast
                wr_en_i => buf_we(i), -- routed
                rd_addr_i => rd_addr_i, -- broadcast
                rd_data_o => buf_rd(i) -- collected
            );
    end generate;

    -- Read the active buffer
    rd_data_o <= buf_rd(active_buf);

    -- Wire through the gen stamp
    gen_o <= gen;

    -- Temporal swap logic
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if init_i = '1' then
                -- This resets the MOD so the first 
                -- fill target buffer is 0.
                active_buf <= NUM_BUFFERS - 1;
                pending <= '0';
                gen <= (others => '0');
            else
                -- Check the commit request
                -- to release a swap.
                if commit_i = '1' then
                    pending <= '1';
                end if;

                -- Swap the incoming streamed DMA values
                -- into the BRAM when safe to do so.
                if pass_start_i = '1' and pending = '1' then
                    -- Ingest the freshly filled buffer.
                    active_buf <= write_buff;
                    pending <= '0';
                    
                    -- Increment the generation count (ABA).
                    -- Writer must not pulse commit again
                    -- until this increments!
                    gen <= gen + 1;
                end if;

            end if;
        end if;
    end process;

end main;