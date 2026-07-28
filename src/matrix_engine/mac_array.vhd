--------------------------------------------------------------------------------
--  File:   mac_array.vhd
--  Desc:   The orchestrator which drives the PandA MAC Engine.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- The MAC Array
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

-- use work.panda_consts.all;
-- use work.fp_utils.all;
-- use work.num_utils.all;
use work.matrix_consts.all;
-- use work.mac_utils.all;

entity mac_array is
    generic (
        G_ENGINES : positive := 1;
        G_LANES : positive := 1;

        -- TODO - generalise dims such that
        -- each pipelined matrix array can 
        -- have their own custom dimensions.
        M : positive := 3;
        N : positive := 3
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
end entity mac_array;

architecture main of mac_array is

begin
    -- Instantiate the concentrated engine
    gen_concentrated : if G_ENGINES = 1 generate
        u_engine : entity work.mac_engine
            generic map (
                G_LANES => G_LANES,
                M => M,
                N => N
            )
            port map (
                clk_i => clk_i,
                init_i => init_i,

                k_i => k_i,
                x_i => x_i,

                start_i => start_i,

                done_o => done_o,
                u_o => u_o
            );
    end generate;

    -- Instantiate the parrallel engine
    gen_pipelined : if G_ENGINES > 1 generate
        -- Remember to remove when starting,
        -- this will fail elaboration loudly!
        constant unsupported : positive := 0;
    begin
        -- TODO
        assert false
            report "Pipelined topology not yet implemented"
            severity failure;
    end generate;

end main;
