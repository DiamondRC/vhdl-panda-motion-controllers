--------------------------------------------------------------------------------
--  File:   cond_input.vhd
--  Desc:   Process the PandA inputs ahead of the control algorithm.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Input conditioning block for the control algorithms.
--
-- Values which need deriving (velocity etc) are calculated here and then
-- threaded into their corresponding block in lqr.vhd.
-- If no processing is required, those values bypass this entirely.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
use work.fp_utils.all;
-- use work.num_utils.all;
use work.matrix_consts.all;
-- use work.mac_utils.all;
-- use work.lqr_consts.all;
use work.cond_consts.all;

entity cond_input is
    generic (
        AXES : positive := 3;
        HIST_DEPTH : positive := 2; -- 2 covers vel/prev
        INTER_SCALE : real := 0.256; -- 256pm / count -> nm

        G_STATE : boolean := true;
        G_VELOCITY : boolean := true;
        G_PREV : boolean := true
    );
    port (
        clk_i  : in std_logic; -- PandA master clock
        init_i : in std_logic; -- PandA reset

        tick_i : in std_logic; -- sample + advance history
        pos_i : in mac_data_vec(0 to AXES - 1); -- measured positions

        -- Controller input states
        x_o : out mac_data_vec(0 to cond_width(AXES, G_STATE, G_VELOCITY, G_PREV) - 1);
        valid_o : out std_logic -- x_o meaningful
    );
end entity cond_input;

architecture main of cond_input is
    -- Contains pos_k, pos_k-1, ...
    type hist_t is array (0 to AXES - 1) of mac_data_vec(0 to HIST_DEPTH - 1);

    signal poshist : hist_t;
    signal warm : natural range 0 to HIST_DEPTH := 0;

    -- Channel-major bases
    constant VEL_BASE  : natural := AXES * boolean'pos(G_STATE);
    constant PREV_BASE : natural := AXES * (boolean'pos(G_STATE) + boolean'pos(G_VELOCITY));

    -- Guarded difference
    function g_diff(a, b : signed) return signed is
    begin
        return saturate(resize(a, LANE_A_W + 1) - resize(b, LANE_A_W + 1), LANE_A_W);
    end function;

begin

    -- Combinational channel bank,
    -- channel-major concat.
    gen_state : if G_STATE generate
        a : for ax in 0 to AXES - 1 generate
            -- Current position, pass-through.
            x_o(ax) <= poshist(ax)(0);
        end generate;
    end generate;

    gen_vel : if G_VELOCITY generate
        a : for ax in 0 to AXES - 1 generate
            -- First finite difference => velocity.
            x_o(VEL_BASE + ax) <= g_diff(poshist(ax)(0), poshist(ax)(1));
        end generate;
    end generate;

    gen_prev : if G_PREV generate
        a : for ax in 0 to AXES - 1 generate
            -- Previous position (delayed state).
            x_o(PREV_BASE + ax) <= poshist(ax)(1);
        end generate;
    end generate;


    process(clk_i) begin
        if rising_edge(clk_i) then
            if init_i = '1' then
                -- Don't you just love vhdl lol
                poshist <= (others => (others => (others => '0')));
                warm    <= 0;
                valid_o <= '0';
            else
                valid_o <= '0'; -- default

                if tick_i = '1' then
                    for ax in 0 to AXES - 1 loop
                        for t in HIST_DEPTH - 1 downto 1 loop
                            -- Shimmy positions down the history.
                            poshist(ax)(t) <= poshist(ax)(t - 1);
                        end loop;

                        -- kth measured position, converted to nm
                        -- TODO - plausably misses timing (42x15 mul + round)
                        poshist(ax)(0) <= to_nm(pos_i(ax), INTER_SCALE);
                    end loop;

                    -- Wait HIST_DEPTH ticks until we're ready
                    if warm < HIST_DEPTH then
                        warm <= warm + 1;
                    end if;

                    if warm >= HIST_DEPTH - 1 then
                        valid_o <= '1';
                    end if;

                end if; -- tick

            end if; -- reset + main
        end if; -- clk
    end process;
end architecture;
