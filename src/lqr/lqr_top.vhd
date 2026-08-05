--------------------------------------------------------------------------------
--  File:   lqr_top.vhd
--  Desc:   Orchestrates the PandA LQR controller.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- LQR Controller
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
use work.fp_utils.all;
use work.num_utils.all;
use work.matrix_consts.all;
use work.mac_utils.all;
use work.lqr_consts.all;
use work.cond_consts.all;


entity lqr_top is
    generic (
        AXES : positive := 3;
        M : positive := 3; 
        DIV : positive := 12500; -- 12500 = 10KHz
        HIST_DEPTH : positive := 2;
        INTER_SCALE : real := 0.256; -- 256pm / count -> nm

        G_PHI : natural := 0; -- Count of nonlinear lift columns phi(x)
        G_REF : natural := 0; -- Setpoint block width (0 => defaults to N)

        G_VELOCITY : boolean := true; -- Add a velocity term?
        G_PREV : boolean := false; -- Recall previous input state?
        G_UPREV : boolean := true; -- Recall previous outputs?
        G_SETPOINT : boolean := false; -- Include the SP in the control?
        G_AFFINE : boolean := false -- Is affine (K * x + affine)?
    );
    port (
        clk_i : in std_logic; -- PandA master clock
        init_i : in std_logic; -- PandA reset

        pos_i : in  mac_data_vec(0 to AXES - 1);  -- Interferometry
        sp_i : in  mac_data_vec( -- PandABlocks
            0 to resolve_ref(
                cond_width(AXES, true, G_VELOCITY, G_PREV), G_REF
            ) - 1
        );

        wr_addr_i : in  unsigned(
            ceil_log2(
                M * n_int(
                    cond_width(AXES, true, G_VELOCITY, G_PREV), M,
                    resolve_ref(
                        cond_width(AXES, true, G_VELOCITY, G_PREV), G_REF
                    ),
                    G_PHI, G_UPREV, G_SETPOINT, G_AFFINE
                )
            ) - 1 downto 0
        );
        wr_data_i : in  signed(LANE_B_W - 1 downto 0);
        wr_en_i : in  std_logic;

        commit_i : in  std_logic;
        gen_o : out unsigned(GEN_W - 1 downto 0);

        u_o : out lqr_out_vec(0 to M - 1); -- control -> DAC
        u_valid_o : out std_logic -- = lqr.done_o, latch strobe
    );
end entity;



architecture main of lqr_top is
    -- Constant
    constant N : positive := cond_width(AXES, true, G_VELOCITY, G_PREV);
    constant REF : positive := resolve_ref(N, G_REF); -- Setpoint block width

    -- Signals
    signal tick, cond_valid : std_logic;
    signal cond_x : mac_data_vec(0 to N - 1);
    signal sp_reg : mac_data_vec(0 to REF - 1);

begin

    -- Ensure input scaling is correct between LQR and conditioning
    assert DES_FRAC = STATE_F
        report "Input nm scaling miss-aligned! cond DES_FRAC /= lqr STATE_F"
    severity failure;

    -- Create the servo-rate
    u_div : entity work.servo_div 
        generic map (
            DIV => DIV
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            tick_o => tick
        );

    -- Process the input variables
    -- for the control algorithm.
    u_cond : entity work.cond_input
        generic map (
            AXES => AXES,
            HIST_DEPTH => HIST_DEPTH,
            INTER_SCALE => INTER_SCALE,
            G_STATE => true,
            G_VELOCITY => G_VELOCITY,
            G_PREV => G_PREV
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            tick_i => tick,
            pos_i => pos_i,
            x_o => cond_x,
            valid_o => cond_valid
        );
    
    -- Execute the LQR
    u_lqr : entity work.lqr
        generic map (
            M => M,
            N => N,
            G_PHI => 0,
            G_REF => G_REF,
            G_UPREV => G_UPREV,
            G_SETPOINT => G_SETPOINT,
            G_AFFINE => G_AFFINE
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            sp_i => sp_reg,
            wr_addr_i => wr_addr_i,
            wr_data_i => wr_data_i,
            wr_en_i => wr_en_i,
            commit_i => commit_i,
            gen_o => gen_o,
            x_i => cond_x,
            start_i => cond_valid,
            done_o => u_valid_o,
            u_o => u_o
        );

    -- Wire the SP at each tick
    -- (required since it's on a port and an LQR which
    -- has no SP term much manually reject the wire)
    process(clk_i) begin
        if rising_edge(clk_i) then
            if init_i = '1' then
                sp_reg <= (others => (others => '0'));
            elsif tick = '1' then
                -- Send all inputs to nm
                for r in 0 to REF - 1 loop
                    sp_reg(r) <= to_nm(sp_i(r), INTER_SCALE);
                end loop;
            end if;
        end if;
    end process;

end architecture main;