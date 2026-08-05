--------------------------------------------------------------------------------
--  File:   cond_input_tb.vhd
--  Desc:   Verify the input signal processing for the PandA.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.panda_consts.all;
use work.matrix_consts.all;
use work.cond_consts.all;


entity cond_input_td is
end entity cond_input_td;

architecture rtl of cond_input_td is
    -- System
    constant p_clk_period : time := MASTER_CLK_PERIOD;
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    -- Topology
    constant AXES : natural := 3;
    constant HIST_DEPTH : natural := 2;
    constant INTER_SCALE : real := 0.256; -- 256pm / count -> nm

    -- Ports
    signal clk_i  : std_logic := '0';
    signal init_i : std_logic := '0';

    signal tick_i : std_logic := '0';
    signal pos_i  : mac_data_vec(0 to AXES - 1) := (others => (others => '0'));

    signal x_o     : mac_data_vec(0 to cond_width(AXES, true, true, true) - 1);
    signal valid_o : std_logic;

    -- Test helpers
    function pv(v : integer) return signed is
        -- Position counts (signed - conditioner is FP-agnostic).
    begin
        return to_signed(v, LANE_A_W);
    end function;

    -- Golden counts -> nm (independent of the DUT fixed-point path).
    function floor_shr(x : integer; f : natural) return integer is
        constant d : integer := 2 ** f;
    begin
        if x >= 0 then
            return x / d;
        else
            return -((-x + d - 1) / d); -- floor, not trunc
        end if;
    end function;

    function nm_gold(c : signed) return signed is
        constant SC : integer := integer(INTER_SCALE * real(2 ** PV_FRAC));
        variable prod : integer := to_integer(c) * SC;
        variable bias : integer := 2 ** (FRAC_DIFF - 1); -- half-away
    begin
        if prod < 0 then
            bias := bias - 1;
        end if;
        return to_signed(floor_shr(prod + bias, FRAC_DIFF), LANE_A_W);
    end function;


    procedure step (
        -- Drive one tick with pos, sample once the history has settled,
        -- and check the channels (channel-major [ state | vel | prev ]).
        constant name : in string;
        constant dp : in mac_data_vec; -- driven position
        constant pp : in mac_data_vec; -- previous position
        constant valid : in boolean;

        signal clk_i : in  std_logic;
        signal pos_i : out mac_data_vec;
        signal tick_i : out std_logic;
        signal x_o : in  mac_data_vec;
        signal valid_o : in  std_logic;
        signal fail_o : out std_logic
    ) is
    begin
        pos_i <= dp;
        tick_i <= '1';
        wait until rising_edge(clk_i);
        tick_i <= '0';
        wait until falling_edge(clk_i);

        if not valid then
            if valid_o /= '0' then
                fail_o <= '1';
                report name & ": valid_o set during warm-up" severity error;
            end if;
        else
            if valid_o /= '1' then
                fail_o <= '1';
                report name & ": valid_o not set" severity error;
            end if;

            for ax in 0 to AXES - 1 loop
                if x_o(ax) /= nm_gold(dp(ax)) then
                    fail_o <= '1';
                    report name & ": state(" & integer'image(ax) &
                        ") got " & integer'image(to_integer(x_o(ax)))
                    severity error;
                end if;

                if x_o(AXES + ax) /= nm_gold(dp(ax)) - nm_gold(pp(ax)) then
                    fail_o <= '1';
                    report name & ": vel(" & integer'image(ax) &
                        ") got " & integer'image(to_integer(x_o(AXES + ax)))
                    severity error;
                end if;

                if x_o(2 * AXES + ax) /= nm_gold(pp(ax)) then
                    fail_o <= '1';
                    report name & ": prev(" & integer'image(ax) &
                        ") got " & integer'image(to_integer(x_o(2 * AXES + ax)))
                    severity error;
                end if;
            end loop;

            report name & " passes" severity note;
        end if;
    end procedure;

    -- Test data
    constant PZ : mac_data_vec(0 to AXES - 1) := (others => (others => '0'));
    constant P0 : mac_data_vec(0 to AXES - 1) := (pv( 10), pv( 20), pv( 30));
    constant P1 : mac_data_vec(0 to AXES - 1) := (pv( 15), pv( 18), pv( 40));
    constant P2 : mac_data_vec(0 to AXES - 1) := (pv( 15), pv( 25), pv( 35));
    constant P3 : mac_data_vec(0 to AXES - 1) := (pv(  5), pv( 25), pv( 50));
    constant PR : mac_data_vec(0 to AXES - 1) := (pv( 16), pv(-16), pv( 16)); -- rounding tie
    constant PA : mac_data_vec(0 to AXES - 1) := (pv(100), pv(-50), pv(  7));
    constant PB : mac_data_vec(0 to AXES - 1) := (pv( 90), pv(-30), pv( 12));

begin

    clkgen : process
    begin
        while not sim_done loop
            clk_i <= not clk_i;
            wait for p_clk_period / 2;
        end loop;
        wait;
    end process;

    uut : entity work.cond_input
        generic map (
            AXES => AXES,
            HIST_DEPTH => HIST_DEPTH,
            INTER_SCALE => INTER_SCALE,
            G_STATE => true,
            G_VELOCITY => true,
            G_PREV => true
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            tick_i => tick_i,
            pos_i => pos_i,
            x_o => x_o,
            valid_o => valid_o
        );

    process
    begin
        -- Reset
        wait until rising_edge(clk_i);
        init_i <= '1';
        wait until rising_edge(clk_i);
        init_i <= '0';
        wait until rising_edge(clk_i);

        -- History not yet filled - no valid.
        step("warm-up", P0, PZ, false,
            clk_i, pos_i, tick_i, x_o, valid_o, fail);

        -- Filled - state/velocity/prev over a sequence.
        step("k1", P1, P0, true,
            clk_i, pos_i, tick_i, x_o, valid_o, fail);
        step("k2", P2, P1, true,
            clk_i, pos_i, tick_i, x_o, valid_o, fail);
        step("k3", P3, P2, true,
            clk_i, pos_i, tick_i, x_o, valid_o, fail);

        -- Half-away tie + negative counts.
        step("tie", PR, P3, true,
            clk_i, pos_i, tick_i, x_o, valid_o, fail);

        -- Init clears history + restarts the warm-up.
        init_i <= '1';
        wait until rising_edge(clk_i);
        init_i <= '0';
        wait until rising_edge(clk_i);

        step("re-warm", PA, PZ, false,
            clk_i, pos_i, tick_i, x_o, valid_o, fail);
        step("post-init", PB, PA, true,
            clk_i, pos_i, tick_i, x_o, valid_o, fail);

        -- Report the overall result
        wait until rising_edge(clk_i);
        if fail = '0' then
            report "COND INPUT TESTS PASS" severity note;
        else
            report "COND INPUT TESTS FAILED" severity failure;
        end if;
        sim_done <= true;

        wait;
    end process;

end architecture rtl;
