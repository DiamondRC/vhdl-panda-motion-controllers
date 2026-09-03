--------------------------------------------------------------------------------
--  File:   lqr_block_dma_tb.vhd
--  Desc:   Block-level TB for the DMA LQR variant.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.panda_consts.all;
use work.matrix_consts.all;
use work.lqr_consts.all;
use work.lqr_block_tb_pkg.all;


entity lqr_block_dma_td is
end entity lqr_block_dma_td;

architecture rtl of lqr_block_dma_td is
    -- System
    constant p_clk_period : time := MASTER_CLK_PERIOD;
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    -- Ports
    signal clk_i : std_logic := '0';
    signal init_i : std_logic := '0';

    signal pos0_i, pos1_i, pos2_i : std_logic_vector(31 downto 0) := (others => '0');
    signal sp0_i, sp1_i, sp2_i : std_logic_vector(31 downto 0) := (others => '0');

    signal GAINS_ADDRESS : std_logic_vector(31 downto 0) := (others => '0');
    signal GAINS_ADDRESS_WSTB : std_logic := '0';
    signal GAINS_LENGTH : std_logic_vector(31 downto 0) := (others => '0');
    signal GAINS_LENGTH_WSTB : std_logic := '0';

    -- DMA bundle (block master <-> mock slave)
    signal dma_req : std_logic;
    signal dma_ack : std_logic;
    signal dma_done : std_logic;
    signal dma_addr : std_logic_vector(31 downto 0);
    signal dma_len : std_logic_vector(7 downto 0);
    signal dma_data : std_logic_vector(31 downto 0);
    signal dma_valid : std_logic;

    signal COMMIT : std_logic_vector(31 downto 0) := (others => '0');
    signal COMMIT_WSTB : std_logic := '0';

    signal GEN : std_logic_vector(31 downto 0);
    signal u0_o, u1_o, u2_o : std_logic_vector(31 downto 0);
    signal u_valid_o : std_logic;

    -- Backing memory the mock streams back (flattened K, row-major)
    signal gain_mem : word_vec(0 to GAIN_CNT - 1) := GAINS_FLAT;

    -- Test data (raw counts)
    constant P0 : mac_data_vec(0 to AXES - 1) := (pv(10), pv(20), pv(30));
    constant P1 : mac_data_vec(0 to AXES - 1) := (pv(12), pv(22), pv(28));
    constant P2 : mac_data_vec(0 to AXES - 1) := (pv( 8), pv(25), pv(35));
    constant SP : mac_data_vec(0 to AXES - 1) := (pv( 5), pv(10), pv(15));

begin

    clkgen : process
    begin
        while not sim_done loop
            clk_i <= not clk_i;
            wait for p_clk_period / 2;
        end loop;
        wait;
    end process;

    uut : entity work.lqr_block_dma
        port map (
            clk_i => clk_i,
            init_i => init_i,
            pos0_i => pos0_i, pos1_i => pos1_i, pos2_i => pos2_i,
            sp0_i => sp0_i, sp1_i => sp1_i, sp2_i => sp2_i,
            GAINS_ADDRESS => GAINS_ADDRESS,
            GAINS_ADDRESS_WSTB => GAINS_ADDRESS_WSTB,
            GAINS_LENGTH => GAINS_LENGTH,
            GAINS_LENGTH_WSTB => GAINS_LENGTH_WSTB,
            dma_req_o => dma_req,
            dma_ack_i => dma_ack,
            dma_done_i => dma_done,
            dma_addr_o => dma_addr,
            dma_len_o => dma_len,
            dma_data_i => dma_data,
            dma_valid_i => dma_valid,
            COMMIT => COMMIT,
            COMMIT_WSTB => COMMIT_WSTB,
            GEN => GEN,
            u0_o => u0_o, u1_o => u1_o, u2_o => u2_o,
            u_valid_o => u_valid_o
        );

    dma : entity work.mock_dma
        generic map (
            DEPTH => GAIN_CNT,
            GAP => 2 -- stall the stream: prove back-pressure tolerance
        )
        port map (
            clk_i => clk_i,
            mem_i => gain_mem,
            dma_req_i => dma_req,
            dma_ack_o => dma_ack,
            dma_done_o => dma_done,
            dma_addr_i => dma_addr,
            dma_len_i => dma_len,
            dma_data_o => dma_data,
            dma_valid_o => dma_valid
        );

    process
        variable u_prev : mac_data_vec(0 to M - 1) := (others => (others => '0'));
        variable gen0 : unsigned(31 downto 0);

        -- Write ADDRESS + LENGTH, then let the mock stream the burst back.
        procedure load_dma is
        begin
            GAINS_ADDRESS <= (others => '0'); -- host buffer base
            GAINS_ADDRESS_WSTB <= '1';
            wait until rising_edge(clk_i);
            GAINS_ADDRESS_WSTB <= '0';
            GAINS_LENGTH <= std_logic_vector(to_unsigned(GAIN_CNT * 4, 32)); -- bytes
            GAINS_LENGTH_WSTB <= '1';
            wait until rising_edge(clk_i);
            GAINS_LENGTH_WSTB <= '0';
            wait until dma_done = '1'; -- burst complete
            wait until rising_edge(clk_i); -- let the last word land in BRAM
            wait until rising_edge(clk_i);
        end procedure;

        procedure servo_pass(
            constant name : in string;
            constant pc : in mac_data_vec;
            constant sp : in mac_data_vec
        ) is
            variable r : servo_res;
        begin
            r := servo(pc, sp, K, u_prev);
            pos0_i <= std_logic_vector(resize(pc(0), 32));
            pos1_i <= std_logic_vector(resize(pc(1), 32));
            pos2_i <= std_logic_vector(resize(pc(2), 32));
            sp0_i <= std_logic_vector(resize(sp(0), 32));
            sp1_i <= std_logic_vector(resize(sp(1), 32));
            sp2_i <= std_logic_vector(resize(sp(2), 32));

            wait until u_valid_o = '1';
            wait until falling_edge(clk_i);

            if signed(u0_o) /= resize(r.u(0), 32) then
                fail <= '1';
                report name & ": u(0) got " & integer'image(to_integer(signed(u0_o))) &
                    ", expected " & integer'image(to_integer(r.u(0))) severity error;
            end if;
            if signed(u1_o) /= resize(r.u(1), 32) then
                fail <= '1';
                report name & ": u(1) got " & integer'image(to_integer(signed(u1_o))) &
                    ", expected " & integer'image(to_integer(r.u(1))) severity error;
            end if;
            if signed(u2_o) /= resize(r.u(2), 32) then
                fail <= '1';
                report name & ": u(2) got " & integer'image(to_integer(signed(u2_o))) &
                    ", expected " & integer'image(to_integer(r.u(2))) severity error;
            end if;

            u_prev := r.unext;
            report name & " passes" severity note;
        end procedure;
    begin
        -- Reset
        wait until rising_edge(clk_i);
        init_i <= '1';
        wait until rising_edge(clk_i);
        init_i <= '0';
        wait until rising_edge(clk_i);

        gen0 := unsigned(GEN);

        -- DMA the inactive bank, then commit it live.
        load_dma;
        COMMIT_WSTB <= '1';
        wait until rising_edge(clk_i);
        COMMIT_WSTB <= '0';

        -- Servo passes (setpoint held).
        servo_pass("k0", P0, SP);
        servo_pass("k1", P1, SP);
        servo_pass("k2", P2, SP);

        -- Swap occurs after commit at the next pass boundary so
        -- a pass must run before GEN is incremented (one commit => +1).
        if unsigned(GEN) /= gen0 + 1 then
            fail <= '1';
            report "GEN did not increment after commit" severity error;
        end if;

        wait until rising_edge(clk_i);
        if fail = '0' then
            report "LQR BLOCK (DMA) TESTS PASS" severity note;
        else
            report "LQR BLOCK (DMA) TESTS FAILED" severity failure;
        end if;
        sim_done <= true;

        wait;
    end process;

end architecture rtl;
