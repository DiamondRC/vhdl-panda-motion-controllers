--------------------------------------------------------------------------------
--  File:   state_export_tb.vhd
--  Desc:   Simulate exports to check the seqlock the PS ACP slave sees.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.panda_consts.all;
use work.state_abi.all;
use work.acp_tb_pkg.all;

entity state_export_td is
end entity;

architecture rtl of state_export_td is
    constant CLK_PERIOD : time     := MASTER_CLK_PERIOD;
    constant AXES : positive := 3;
    constant MEM_WORDS : positive := 64;
    constant MAX_BURSTS : positive := 16;

    -- Burst count derived from the axis count:
    -- 1 seq(odd) + the payload chunks + 1 seq(even).
    constant CHUNK : natural := 8;
    constant PAY_BEATS : natural := payload_beats(AXES);
    constant PAY_BURSTS : natural := (PAY_BEATS + CHUNK - 1) / CHUNK; -- ceil-div
    constant EXP_BURSTS : natural := 2 + PAY_BURSTS; -- odd + payload + even

    signal clk : std_logic := '0';
    signal init : std_logic := '0';
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    -- DUT control
    signal tick, export_en, valid : std_logic := '0';
    signal pos, vel, setp, setv : state_word_vec(0 to AXES - 1) :=
        (others => (others => '0'));
    signal busy, error : std_logic;

    -- AXI wires DUT <-> mock
    signal awvalid, awready, wvalid, wready, wlast, bvalid, bready : std_logic;
    signal awaddr : std_logic_vector(31 downto 0);
    signal awid, bid, wid : std_logic_vector(2 downto 0);
    signal awlen : std_logic_vector(3 downto 0);
    signal awsize : std_logic_vector(2 downto 0);
    signal awburst : std_logic_vector(1 downto 0);
    signal bresp : std_logic_vector(1 downto 0);
    signal awcache : std_logic_vector(3 downto 0);
    signal awuser : std_logic_vector(4 downto 0);
    signal awprot : std_logic_vector(2 downto 0);
    signal awlock : std_logic_vector(1 downto 0);
    signal awqos : std_logic_vector(3 downto 0);
    signal wdata : std_logic_vector(63 downto 0);
    signal wstrb : std_logic_vector(7 downto 0);

    signal mem : word64_vec(0 to MEM_WORDS - 1);

    -- Observers
    signal saw_odd : std_logic := '0';
    signal aw_count : natural := 0;
    signal aw_log : addr_vec(0 to MAX_BURSTS - 1) := (others => (others => '0'));

    -- Expected test values.
    function exp_pos (k : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(100 + k, 32));
    end function;

    function exp_vel (k : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(200 + k, 32));
    end function;

    function exp_setp(k : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(300 + k, 32));
    end function;

    function exp_setv(k : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(400 + k, 32));
    end function;

begin
    ----------------------------------------------------------------------------
    -- Clock
    ----------------------------------------------------------------------------
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    ----------------------------------------------------------------------------
    -- DUT + mock slave
    ----------------------------------------------------------------------------
    dut : entity work.state_export
        generic map (
            BASE_ADDR => x"00000000",
            AXES => AXES,
            CHUNK => CHUNK
        )
        port map (
            clk_i => clk,
            init_i => init,
            tick_i => tick,
            export_en_i => export_en,
            valid_i => valid,
            pos_i => pos,
            vel_i => vel,
            setp_i => setp,
            setv_i => setv,
            busy_o => busy,
            error_o => error,

            m_axi_awvalid => awvalid,
            m_axi_awready => awready,
            m_axi_awaddr => awaddr,
            m_axi_awid => awid,
            m_axi_awlen => awlen,
            m_axi_awsize => awsize,
            m_axi_awburst => awburst,
            m_axi_awcache => awcache,
            m_axi_awuser => awuser,
            m_axi_awprot => awprot,
            m_axi_awlock => awlock,
            m_axi_awqos => awqos,

            m_axi_wvalid => wvalid,
            m_axi_wready => wready,
            m_axi_wid => wid,
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
            awvalid_i => awvalid,
            awready_o => awready,
            awaddr_i => awaddr,

            wvalid_i => wvalid,
            wready_o => wready,
            wdata_i => wdata,
            wstrb_i => wstrb,
            wlast_i => wlast,

            bvalid_o => bvalid,
            bready_i => bready,
            bresp_o => bresp,

            mem_o => mem
        );

    bid <= "000"; -- mock doesn't drive BID

    ----------------------------------------------------------------------------
    -- Bus observers/snoopers
    ----------------------------------------------------------------------------
    
    -- Whole-line guarantee:
    -- Every accepted beat must be full-width else we'll thrash the L2 cache w/
    -- misallignment - mulit-line reads and accompanying merges.
    strb_mon : process(clk)
    begin
        if rising_edge(clk) then
            if wvalid = '1' and wready = '1' then
                assert wstrb = x"FF"
                    report "partial-line write (WSTRB /= 0xFF) -> would force L2 RMW"
                    severity error;
                if wstrb /= x"FF" then fail <= '1'; end if;
            end if;
        end if;
    end process;

    -- Burst log + odd-seq witness.
    obs : process(clk)
    begin
        if rising_edge(clk) then
            if awvalid = '1' and awready = '1' and aw_count < MAX_BURSTS then
                aw_log(aw_count) <= awaddr;
                aw_count <= aw_count + 1;
            end if;

            -- While an export is in flight, seq in memory must be odd.
            if busy = '1' and mem(0)(0) = '1' then
                saw_odd <= '1';
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Stimulus + checks
    ----------------------------------------------------------------------------
    stim : process
        procedure check(cond : boolean; msg : string) is
        begin
            assert cond report msg severity error;
            if not cond then
                fail <= '1';
            end if;
        end procedure;
        variable idx_a, idx_b : natural;
    begin
        -- Reset
        init <= '1';
        wait for 4 * CLK_PERIOD;
        init <= '0';
        wait until rising_edge(clk);

        -- Send known payload
        for k in 0 to AXES - 1 loop
            pos(k) <= exp_pos(k);
            vel(k) <= exp_vel(k);
            setp(k) <= exp_setp(k);
            setv(k) <= exp_setv(k);
        end loop;

        export_en <= '1';
        valid <= '1';
        wait until rising_edge(clk);

        -- One export tick
        tick <= '1';
        wait until rising_edge(clk);
        tick <= '0';

        -- Run the export to completion
        wait until rising_edge(clk) and busy = '1'; -- started
        wait until rising_edge(clk) and busy = '0'; -- finished
        wait until rising_edge(clk);

        ------------------------------------------------------------------------
        -- CHECK 1: burst count + order (seq -> payload -> seq), whole-line
        ------------------------------------------------------------------------
        check(aw_count = EXP_BURSTS, "unexpected burst count");
        check(unsigned(aw_log(0)) = SEQ_OFF, "burst 0 not the seq line");
        check(
            unsigned(aw_log(1)) = PAYLOAD_OFF,
            "burst 1 not the payload line"
        );
        check(
            unsigned(aw_log(EXP_BURSTS - 1)) = SEQ_OFF,
            "final burst not the seq line"
        );

        for i in 0 to EXP_BURSTS - 1 loop
            check(aw_log(i)(4 downto 0) = "00000", "burst not 32B aligned");
        end loop;

        ------------------------------------------------------------------------
        -- CHECK 2: seq brackets the payload (odd in flight, even at rest)
        ------------------------------------------------------------------------
        check(saw_odd = '1', "seq never went odd during the export");
        check(
            mem(0)(31 downto 0) = std_logic_vector(to_unsigned(2, 32)),
            "seq not even/2 after the export"
        );

        ------------------------------------------------------------------------
        -- CHECK 3: payload decodes to the ABI
        ------------------------------------------------------------------------
        check(
            mem(PAYLOAD_OFF / BEAT_BYTES)(31 downto 0) =
                std_logic_vector(to_unsigned(1, 32)),
            "stamp mismatch"
        );
    
        for k in 0 to AXES - 1 loop
            idx_a := axis_off(k) / BEAT_BYTES; -- {vel, pos}
            idx_b := (axis_off(k) + BEAT_BYTES) / BEAT_BYTES; -- {set_v, set_p}
            check(mem(idx_a)(31 downto 0)  = exp_pos(k), "pos mismatch");
            check(mem(idx_a)(63 downto 32) = exp_vel(k), "vel mismatch");
            check(mem(idx_b)(31 downto 0)  = exp_setp(k), "set_p mismatch");
            check(mem(idx_b)(63 downto 32) = exp_setv(k), "set_v mismatch");
        end loop;

        ------------------------------------------------------------------------
        -- CHECK 4: no error response
        ------------------------------------------------------------------------
        check(error = '0', "master flagged a BRESP error");

        -- Summary
        if fail = '0' then
            report "state_export_tb PASSED" severity note;
        else
            report "state_export_tb FAILED" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;
end architecture;
