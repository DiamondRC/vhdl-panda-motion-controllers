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
-- use work.num_utils.all;
use work.matrix_consts.all;
use work.mac_utils.all;

entity mac_engine is
    generic (
        G_LANES : natural := 1;
        M : natural := 3;
        N : natural := 3
    );
    port (
        clk_i  : in std_logic; -- PandA master clock
        init_i : in std_logic; -- PandA reset

        k_i : in mac_gain_mat(0 to M - 1, 0 to N - 1); -- (row, col)
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

    -- Lane wiring
    signal lane_a    : signed(DSP_COEFF_W - 1 downto 0);
    signal lane_b    : signed(DSP_DATA_W  - 1 downto 0);
    signal lane_load : std_logic;
    signal lane_en   : std_logic;
    signal lane_acc  : signed(DSP_ACC_W  - 1 downto 0);

    -- Vector ranges
    signal row : natural range 0 to M - 1 := 0;
    signal col : natural range 0 to N - 1 := 0;
    signal drain_cnt : natural range 0 to 2 := 0;

begin
    -- MAC lane
    u_lan : entity work.mac_lane
    port map (
        clk_i => clk_i,
        init_i => init_i,
        a_i => lane_a,
        b_i => lane_b,
        load_i => lane_load,
        en_i => lane_en,
        acc_o => lane_acc
    );

    -- Drive inputs with combinational mux
    lane_a    <= k_i(row, col);
    lane_b    <= x_i(col);
    lane_en   <= '1' when state = FEED else '0';
    lane_load <= '1' when (state = FEED and col = 0) else '0';

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

                -- Other
                u_o <= (others => (others => '0'));
            else
                case state is
                    -- Waiting for a start signal
                    when IDLE =>
                        done_o <= '0';

                        if start_i = '1' then
                            row <= 0;
                            state <= FEED;
                        end if;

                    -- Feed lane(s) with all column items
                    when FEED =>
                        -- Once fed advance
                        if col = N - 1 then
                            col <= 0;
                            state <= drain_cnt;
                        else 
                            col <= col + 1;
                        end if;

                    -- Wait for lane calculations
                    when drain_cnt =>
                        -- Await the 2 cycle lane latency
                        if drain_cnt = 1 then
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
