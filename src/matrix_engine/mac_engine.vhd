--------------------------------------------------------------------------------
--  File:   mac_engine.vhd
--  Desc:   The driving MAC engine for the PandA.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- The MAC Engine
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
-- use work.fp_utils.all;
use work.num_utils.all;
use work.matrix_consts.all;
use work.mac_utils.all;

entity mac_engine is
    generic (
        G_LANES : positive := 1;
        M : positive := 3;
        N : positive := 3
    );
    port (
        clk_i  : in std_logic; -- PandA master clock
        init_i : in std_logic; -- PandA reset

        -- BRAM Gains
        wr_addr_i : in unsigned(ceil_log2(M * N) - 1 downto 0);
        wr_data_i : in signed(LANE_B_W - 1 downto 0);
        wr_en_i : in std_logic;

        -- BRAM Buffer
        commit_i : in std_logic;
        gen_o : out unsigned(GEN_W - 1 downto 0);

        -- Incoming State
        x_i : in mac_data_vec(0 to N - 1);

        start_i : in std_logic;

        done_o : out std_logic := '0'; 
        u_o : out mac_acc_vec(0 to M - 1) :=
            (others => (others => '0'))
    );
end entity mac_engine;

architecture main of mac_engine is
    -- FSM
    signal state : engine_state := IDLE;

    -- BRAM
    constant DEPTH : natural := M * N;
    constant DATA_W : natural := LANE_B_W;
    constant NUM_BUFFERS : natural := 2;
    signal gain_addr : unsigned(ceil_log2(DEPTH) - 1 downto 0);

    -- Lane wiring
    signal lane_a    : signed(LANE_A_W - 1 downto 0); -- State
    signal lane_b    : signed(LANE_B_W  - 1 downto 0); -- Gains
    signal lane_load : std_logic;
    signal lane_en   : std_logic;
    signal lane_acc  : signed(LANE_ACC_W  - 1 downto 0);

    -- Vector ranges
    signal row : natural range 0 to M - 1 := 0;
    signal col : natural range 0 to N - 1 := 0;
    signal drain_cnt : natural range 0 to 4 := 0;

    -- Pipeline registers
    signal xa_p1 : signed(LANE_A_W - 1 downto 0);
    signal en_p1 : std_logic;
    signal ld_p1 : std_logic;
    signal pass_start : std_logic;

begin
    -- MAC lane
    u_lane : entity work.mac_lane
        generic map (
            A_W => LANE_A_W,
            B_W => LANE_B_W,
            ACC_W => LANE_ACC_W
        )
        port map ( 
            clk_i => clk_i,
            init_i => init_i,
            a_i => lane_a,
            b_i => lane_b,
            load_i => lane_load,
            en_i => lane_en,
            acc_o => lane_acc
        );

    -- BRAM gain storage
    u_store : entity work.bram_buffer
        generic map (
            NUM_BUFFERS => NUM_BUFFERS,
            DEPTH => DEPTH,
            DATA_W => DATA_W
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            wr_addr_i => wr_addr_i,
            wr_data_i => wr_data_i,
            wr_en_i => wr_en_i,
            rd_addr_i => gain_addr,
            rd_data_o => lane_b,
            commit_i => commit_i,
            pass_start_i => pass_start,
            gen_o => gen_o
        );

    -- Every cycle update the BRAM address to fetch next gain.
    gain_addr <= to_unsigned(row * N + col, gain_addr'length);

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if init_i = '1' then
                -- Core
                state <= IDLE;
                done_o <= '0';

                -- Vector ranges
                row <= 0;
                col <= 0;
                drain_cnt <= 0;

                -- BRAM pipelining
                en_p1 <= '0';
                ld_p1 <= '0';
                lane_en <= '0';
                lane_load <= '0';
                pass_start <= '0';

                -- Other
                u_o <= (others => (others => '0'));
            else
                -- ------------------------
                -- BRAM reads (every cycle)
                -- ------------------------

                -- Stage 1 - capture
                --
                -- Gains arrive from BRAM 2 cycles late,
                -- however x, load and en are available immediately.
                if state = FEED then
                    -- Buffer state,
                    -- enable processing.
                    xa_p1 <= x_i(col);
                    en_p1 <= '1';

                    -- Handle accumulation.
                    -- If first term in a new row...
                    if col = 0 then
                        -- ...overwrite accumuator,
                        -- new sum. Or...
                        ld_p1 <= '1';
                    else
                        -- ...continue accumulating.
                        ld_p1 <= '0';
                    end if;
                else
                    -- Do not pass state,
                    -- do not load/enable.
                    en_p1 <= '0';
                    ld_p1 <= '0';
                end if;

                -- Do not stream new data whislt we're
                -- working!
                pass_start <= '0';

                -- Stage 2 - pipeline for a cycle
                lane_a <= xa_p1; -- send state
                lane_en <= en_p1;
                lane_load <= ld_p1;

                -- ------------------------
                -- FSM lane
                -- ------------------------
                case state is
                    -- Waiting for a start signal
                    when IDLE =>
                        done_o <= '0';

                        if start_i = '1' then
                            row <= 0;
                            state <= FEED;
                            -- Begin pass at start of
                            -- new state processing.
                            pass_start <= '1';
                        end if;

                    -- Feed lane(s) with all column items
                    when FEED =>
                        -- Once fed advance
                        if col = N - 1 then
                            col <= 0;
                            state <= DRAIN;
                        else 
                            col <= col + 1;
                        end if;

                    -- Wait for lane calculations
                    when DRAIN =>
                        -- Await the 4 cycle lane latency
                        -- Last term 2 cycles to read + 2 to process
                        if drain_cnt = 3 then
                            state <= CAPTURE;
                            drain_cnt <= 0;
                        else
                            drain_cnt <= drain_cnt + 1;
                        end if;

                    -- Store lane calculation results
                    when CAPTURE =>
                        -- Return the current result
                        u_o(row) <= lane_acc;

                        -- Decided if we advance or finish.
                        -- Have all rows been processed?
                        if row < M - 1 then
                            row <= row + 1;
                            state <= FEED;
                        else 
                            state <= DONE;
                        end if;

                    -- All rows have been processed, finish.
                    when DONE =>
                        done_o <= '1';
                        state <= IDLE;

                end case;
            end if;
        end if; -- clk
    end process;

end main;
