library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.panda_consts.all;
use work.num_utils.all;
use work.matrix_consts.all;
use work.mac_utils.all;
use work.fp_utils.all;
use work.lqr_consts.all;
use work.cond_consts.all;
use work.state_abi.all;
use work.acp_tb_pkg.all;

use work.lqr_block_tb_pkg.nm_gold;
use work.lqr_block_tb_pkg.pv;

entity lqr_export_integration_td is
end entity;

architecture rtl of lqr_export_integration_td is
    constant CLK_PERIOD : time := MASTER_CLK_PERIOD;
    constant AXES : positive := 3;
    constant M : positive := 3;
    constant DIV : positive := 64;
    constant HIST_DEPTH : positive := 2;
    constant MEM_WORDS : positive := 16;

    constant N : positive := cond_width(AXES, true, true, false);
    constant REF : positive := resolve_ref(N, 0);
    constant NI : positive := n_int(N, M, REF, 0, true, false, false);
    constant AW : positive := ceil_log2(M * NI);

    signal clk : std_logic := '0';
    signal init : std_logic := '0';
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    signal pos_i : mac_data_vec(0 to AXES - 1) := (others => (others => '0'));
    signal sp_i : mac_data_vec(0 to REF - 1) := (others => (others => '0'));

    signal wr_addr : unsigned(AW - 1 downto 0) := (others => '0');
    signal wr_data : signed(LANE_B_W - 1 downto 0) := (others => '0');
    signal wr_en : std_logic := '0';
    signal commit : std_logic := '0';
    signal gen : unsigned(GEN_W - 1 downto 0);
    signal u_o : lqr_out_vec(0 to M - 1);
    signal u_valid : std_logic;

    signal awvalid, awready, wvalid, wready, wlast, bvalid, bready : std_logic;
    signal awaddr : std_logic_vector(31 downto 0);
    signal awlen : std_logic_vector(3 downto 0);
    signal wdata : std_logic_vector(63 downto 0);
    signal wstrb : std_logic_vector(7 downto 0);
    signal bresp : std_logic_vector(1 downto 0);
    signal bid : std_logic_vector(2 downto 0) := "000";
    signal berr : std_logic := '0';
    signal dut_err : std_logic;
    signal dut_busy : std_logic;
    signal err_seen : std_logic := '0';

    signal mem : word64_vec(0 to MEM_WORDS - 1);

    type int_vec is array (natural range <>) of integer;
    constant POS_CNT : int_vec(0 to AXES - 1) := (1000, 1100, 1200);
    constant SP_CNT : int_vec(0 to AXES - 1) := (500, 600, 700);
    constant SV_CNT : int_vec(0 to AXES - 1) := (10, 20, 30);

    function exp_word(count : integer) return std_logic_vector is
    begin
        return std_logic_vector(
            requantise(nm_gold(pv(count)), STATE_F - EXPORT_FRAC, 32, HALF_AWAY)
        );
    end function;

begin
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    watchdog : process
    begin
        wait until sim_done for 8000 * CLK_PERIOD;
        assert sim_done
            report "lqr_export_integration_tb TIMEOUT"
            severity failure;
        wait;
    end process;

    dut : entity work.lqr_top
        generic map (
            AXES => AXES,
            M => M,
            DIV => DIV,
            HIST_DEPTH => HIST_DEPTH,
            G_VELOCITY => true,
            G_PREV => false,
            G_UPREV => true,
            G_SETPOINT => false,
            G_AFFINE => false,
            G_EXPORT => true,
            BASE_ADDR => x"00000000",
            CHUNK => 8
        )
        port map (
            clk_i => clk,
            init_i => init,
            pos_i => pos_i,
            sp_i => sp_i,
            wr_addr_i => wr_addr,
            wr_data_i => wr_data,
            wr_en_i => wr_en,
            commit_i => commit,
            gen_o => gen,
            u_o => u_o,
            u_valid_o => u_valid,
            export_err_o => dut_err,
            export_busy_o => dut_busy,

            m_axi_awvalid => awvalid,
            m_axi_awready => awready,
            m_axi_awaddr => awaddr,
            m_axi_awid => open,
            m_axi_awlen => awlen,
            m_axi_awsize => open,
            m_axi_awburst => open,
            m_axi_awcache => open,
            m_axi_awuser => open,
            m_axi_awprot => open,
            m_axi_awlock => open,
            m_axi_awqos => open,

            m_axi_wvalid => wvalid,
            m_axi_wready => wready,
            m_axi_wid => open,
            m_axi_wdata => wdata,
            m_axi_wstrb => wstrb,
            m_axi_wlast => wlast,

            m_axi_bvalid => bvalid,
            m_axi_bready => bready,
            m_axi_bresp => bresp,
            m_axi_bid => bid
        );

    slave : entity work.mock_acp
        generic map (
            MEM_WORDS => MEM_WORDS
        )
        port map (
            clk_i => clk,
            init_i => init,
            awvalid_i => awvalid,
            awready_o => awready,
            awaddr_i => awaddr,
            awlen_i => awlen,

            wvalid_i => wvalid,
            wready_o => wready,
            wdata_i => wdata,
            wstrb_i => wstrb,
            wlast_i => wlast,

            bvalid_o => bvalid,
            bready_i => bready,
            bresp_o => bresp,

            w_wait_i => 0,
            berr_i => berr,

            mem_o => mem
        );

    err_mon : process(clk)
    begin
        if rising_edge(clk) then
            if dut_err = '1' then
                err_seen <= '1';
            end if;
        end if;
    end process;

    stim : process
        procedure check(cond : boolean; msg : string) is
        begin
            assert cond report msg severity error;
            if not cond then fail <= '1'; end if;
        end procedure;

        variable wa : natural;
    begin
        init <= '1';
        wait for 4 * CLK_PERIOD;
        init <= '0';
        wait until rising_edge(clk);

        for k in 0 to AXES - 1 loop
            pos_i(k) <= pv(POS_CNT(k));
            sp_i(k) <= pv(SP_CNT(k));
            sp_i(AXES + k) <= pv(SV_CNT(k));
        end loop;

        loop
            wait until rising_edge(clk);
            exit when mem(0)(0) = '0'
                and unsigned(mem(0)(31 downto 0)) >= 2;
        end loop;

        check(
            unsigned(mem(SEQ_OFF)(31 downto 0)) mod 2 = 0,
            "seq not even at rest"
        );
        check(
            unsigned(mem(PAYLOAD_OFF / BEAT_BYTES)(31 downto 0)) =
                unsigned(mem(0)(31 downto 0)) / 2,
            "stamp /= seq / 2"
        );

        for k in 0 to AXES - 1 loop
            wa := axis_off(k) / BEAT_BYTES;
            check(mem(wa)(31 downto 0) = exp_word(POS_CNT(k)), "pos mismatch");
            check(
                mem(wa)(63 downto 32) = std_logic_vector(to_signed(0, 32)),
                "vel not zero for a static position"
            );
            check(mem(wa + 1)(31 downto 0) = exp_word(SP_CNT(k)), "set_p mismatch");
            check(mem(wa + 1)(63 downto 32) = exp_word(SV_CNT(k)), "set_v mismatch");
        end loop;

        -- Our mock latches berr per burst at the burt's start so we must
        -- loop twice.
        berr <= '1';
        for i in 0 to 1 loop
            wait until rising_edge(clk) and dut_busy = '1';
            wait until rising_edge(clk) and dut_busy = '0';
        end loop;
        check(err_seen = '1', "SLVERR did not reach export_err_o");

        wait until rising_edge(clk);

        if fail = '0' then
            report "lqr_export_integration_tb PASSED" severity note;
        else
            report "lqr_export_integration_tb FAILED" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;
end architecture;
