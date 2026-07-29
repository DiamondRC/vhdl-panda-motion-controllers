--------------------------------------------------------------------------------
--  File:   lqr.vhd
--  Desc:   An LQR control algorithm to drive the PandA.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- LQR Controller
--
-- The engine computes u = K.phi(x), an affine map of a lifted feature vector
-- phi (Koopman / polynomial-LQR view). Features enter at the x_eng assembly
-- seam and widen N.
--
-- There's two easy ways to build phi later which reuse the engine:
--   1. Multiplicative (x_i*x_j, x^2, x'Qx etc): the wide lane is a general A*B
--      multiplier => can source both operands from state, not gain. 
--      Reuse engines (G_ENGINES > 1) to calulate.
--   2. Scalar (sin, tanh, RBF etc): BRAM lookup indexed by quantised state,
--      optional MAC accelerated PWL interp.
--
-- The cost lever is |phi| (quadratic feats -> O(n^2) columns -> bigger K/BRAM),
-- not the datapath.
--
-- TB's/DMA stream which writes gains K into BRAM must lay columns out
-- in the following order:
--
--      [state | features | one]
--
-- with the affine b in the last column.
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

entity lqr is 
    generic (
        G_ENGINES : positive := 1;
        G_LANES : positive := 1;
        M : positive := 3; -- outputs
        N : positive := 3; -- live state inputs

        -- 
        G_FEATURES : natural := 0; -- How many additional K_i * i in control
        G_AFFINE : boolean := false -- If the controller is affine.
    );
    port (
        clk_i  : in std_logic; -- PandA master clock
        init_i : in std_logic; -- PandA reset

        -- Gain stream
        wr_addr_i : in  unsigned(
            ceil_log2(M * n_int(N, G_FEATURES, G_AFFINE)) - 1 downto 0
        );
        wr_data_i : in  signed(LANE_B_W - 1 downto 0);
        wr_en_i   : in  std_logic;

        commit_i  : in  std_logic;
        gen_o     : out unsigned(GEN_W - 1 downto 0);
        
        -- Live state(s)
        x_i : in mac_data_vec(0 to N - 1);

        start_i : in  std_logic;
        done_o  : out std_logic;

        -- Requantised, saturated control output
        u_o : out lqr_out_vec(0 to M - 1)
    );
end entity lqr;

architecture main of lqr is
    -- Constants
    constant N_INT : positive := n_int(N, G_FEATURES, G_AFFINE);

    -- Signals
    signal x_eng : mac_data_vec(0 to N_INT - 1); -- Assembled engine input
    signal u_raw : mac_acc_vec(0 to M - 1); -- Wide accumulator out
begin
    -- Check lane allignments/correctness
    assert state_fx'length = LANE_A_W
        report "state_fx width /= LANE_A_W" severity failure;
    assert gain_fx'length = LANE_B_W
        report "gain_fx width /= LANE_B_W"  severity failure;

    -- Input assembly stream
    x_eng(0 to N - 1) <= x_i; -- TODO - error = x_i - setpoint slots here

    gen_feat : for f in 0 to G_FEATURES - 1 generate
        x_eng(N + f) <= (others => '0'); -- TODO - phi
    end generate;

    gen_affine : if G_AFFINE generate
        x_eng(N_INT - 1) <= ONE_FX; -- 1.0 => b*1 lands at PROD_F
    end generate;


    -- The engine
    u_mac_array : entity work.mac_array
        generic map (
            G_ENGINES => G_ENGINES,
            G_LANES => G_LANES,
            M => M,
            N => N_INT
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            wr_addr_i => wr_addr_i,
            wr_data_i => wr_data_i,
            wr_en_i => wr_en_i,
            commit_i => commit_i,
            gen_o => gen_o,
            x_i => x_eng,
            start_i => start_i,
            done_o => done_o,
            u_o => u_raw
        );

    -- The output stage
    gen_out : for r in 0 to M - 1 generate
        u_o(r) <= requantise(
            -- Round + saturate MAC accum result to port format
            u_raw(r), PROD_F - OUT_F, OUT_W, HALF_AWAY
        );
    end generate;

end architecture;