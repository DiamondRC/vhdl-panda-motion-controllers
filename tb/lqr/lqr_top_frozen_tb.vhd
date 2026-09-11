--------------------------------------------------------------------------------
--  File:   lqr_top_frozen_tb.vhd
--  Desc:   Datapath TB for lqr_top at the deployment shape.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.panda_consts.all;
use work.num_utils.all;
use work.matrix_consts.all;
use work.mac_utils.all;
use work.lqr_consts.all;
use work.cond_consts.all;
use work.lqr_block_tb_pkg.all;


entity lqr_top_frozen_td is
end entity;

architecture rtl of lqr_top_frozen_td is
    constant p_clk_period : time := MASTER_CLK_PERIOD;
    constant DIV : natural := 128; -- small => fast test ticks
    constant AW : natural := ceil_log2(M * NI);

    signal clk_i : std_logic := '0';
    signal init_i : std_logic := '0';
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    signal pos_i : mac_data_vec(0 to AXES - 1) := (others => (others => '0'));
    signal sp_i : mac_data_vec(0 to REF - 1) := (others => (others => '0'));

    signal wr_addr_i : unsigned(AW - 1 downto 0) := (others => '0');
    signal wr_data_i : signed(LANE_B_W - 1 downto 0) := (others => '0');
    signal wr_en_i : std_logic := '0';

    signal commit_i : std_logic := '0';
    signal gen_o : unsigned(GEN_W - 1 downto 0);

    signal u_o : lqr_out_vec(0 to M - 1);
    signal u_valid_o : std_logic;

    -- Test data (raw counts). SP holds [ sp_pos | sp_vel ] (REF wide).
    constant P0 : mac_data_vec(0 to AXES - 1) := (pv(10), pv(20), pv(30));
    constant P1 : mac_data_vec(0 to AXES - 1) := (pv(12), pv(22), pv(28));
    constant P2 : mac_data_vec(0 to AXES - 1) := (pv(8), pv(25), pv(35));
    constant SP : mac_data_vec(0 to REF - 1) := (
        pv(5), pv(10), pv(15), pv(1), pv(2), pv(3)
    );

begin

    clkgen : process
    begin
        while not sim_done loop
            clk_i <= not clk_i;
            wait for p_clk_period / 2;
        end loop;
        wait;
    end process;

    watchdog : process
    begin
        wait until sim_done for 8000 * p_clk_period;
        assert sim_done
            report "lqr_top_frozen_tb TIMEOUT - a servo pass never completed"
            severity failure;
        wait;
    end process;

    uut : entity work.lqr_top
        generic map (
            AXES => AXES,
            M => M,
            DIV => DIV,
            HIST_DEPTH => 2,
            INTER_SCALE => INTER_SCALE,
            G_PHI => 0,
            G_REF => 6,
            G_EXPORT => false,
            G_VELOCITY => true,
            G_PREV => true,
            G_UPREV => true,
            G_SETPOINT => true,
            G_AFFINE => true
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            pos_i => pos_i,
            sp_i => sp_i,
            wr_addr_i => wr_addr_i,
            wr_data_i => wr_data_i,
            wr_en_i => wr_en_i,
            commit_i => commit_i,
            gen_o => gen_o,
            u_o => u_o,
            u_valid_o => u_valid_o,

            m_axi_awready => '0',
            m_axi_wready => '0',
            m_axi_bvalid => '0',
            m_axi_bresp => "00",
            m_axi_bid => "000"
        );

    process
        variable u_prev : mac_data_vec(0 to M - 1) := (others => (others => '0'));

        -- Fill the inactive gain buffe.
        -- (M x NI, addr = row * NI + col) + commit.
        procedure load(constant k : in mac_gain_mat) is
            constant NC : natural := k'high(2) + 1;
        begin
            for r in 0 to k'high(1) loop
                for c in 0 to k'high(2) loop
                    wr_addr_i <= to_unsigned(r * NC + c, wr_addr_i'length);
                    wr_data_i <= k(r, c);
                    wr_en_i <= '1';
                    wait until rising_edge(clk_i);
                end loop;
            end loop;
            wr_en_i <= '0';

            commit_i <= '1';
            wait until rising_edge(clk_i);
            commit_i <= '0';
        end procedure;

        -- Drive one pass, check u_o, thread u_prev.
        procedure servo_check(
            constant name : in string;
            constant pc : in mac_data_vec;
            constant pp : in mac_data_vec;
            constant sp : in mac_data_vec
        ) is
            variable r : servo_res;
        begin
            r := servo(pc, pp, sp, K, u_prev);
            pos_i <= pc;
            sp_i <= sp;

            wait until u_valid_o = '1';
            wait until falling_edge(clk_i);

            for j in 0 to M - 1 loop
                if u_o(j) /= r.u(j) then
                    fail <= '1';
                    report name & ": u(" & integer'image(j) & ") got " &
                        integer'image(to_integer(u_o(j))) & ", expected " &
                        integer'image(to_integer(r.u(j))) severity error;
                end if;
            end loop;

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

        load(K);
        sp_i <= SP;

        -- Warm-up holds P0 (vel = 0, prev = P0), then the position sequence.
        servo_check("k0", P0, P0, SP);
        servo_check("k1", P1, P0, SP);
        servo_check("k2", P2, P1, SP);

        wait until rising_edge(clk_i);
        if fail = '0' then
            report "lqr_top_frozen_tb PASSED" severity note;
        else
            report "lqr_top_frozen_tb FAILED" severity failure;
        end if;
        sim_done <= true;
        wait;
    end process;

end architecture;
