--------------------------------------------------------------------------------
--  File:   acp_write_master.vhd
--  Desc:   Sends state information to the Linux optimiser.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- ACP Write Master
--
-- Sends state information over the AXI bus via ACP to the embedded Linux
-- system's L2 cache as low-latency as possible. The current state is used
-- to drive the onboard optimiser algorithm.
--
-- Based on the PandA axi_write_master.vhd example.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.num_utils.all; 

entity acp_write_master is
    generic (
        AXI_ADDR_WIDTH: natural := 32;
        AXI_DATA_WIDTH : natural := 64;
        AXI_ID_WIDTH : natural := 3;
        AXI_USER_WIDTH : natural := 5;
        AXI_BURST_WIDTH : natural := 4
    );

    port (
        clk_i  : in std_logic; -- PandA master clock
        init_i : in std_logic; -- PandA reset

        -- Per-transaction parameters
        burst_len_i : in  std_logic_vector(AXI_BURST_WIDTH - 1 downto 0);

        -- Write address channel
        m_axi_awvalid : out std_logic;
        m_axi_awready : in  std_logic;
        m_axi_awaddr : out std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
        m_axi_awid : out std_logic_vector(AXI_ID_WIDTH - 1 downto 0);
        m_axi_awlen : out std_logic_vector(3 downto 0);
        m_axi_awsize : out std_logic_vector(2 downto 0);
        m_axi_awburst : out std_logic_vector(1 downto 0); -- AXI3 = 2-bits
        m_axi_awcache : out std_logic_vector(3 downto 0); -- driven "1111"
        m_axi_awuser : out std_logic_vector(AXI_USER_WIDTH - 1 downto 0); -- coherency
        m_axi_awprot : out std_logic_vector(2 downto 0);
        m_axi_awlock : out std_logic_vector(1 downto 0);
        m_axi_awqos : out std_logic_vector(3 downto 0);

        -- Write data channel 
        m_axi_wvalid : out std_logic;
        m_axi_wready : in std_logic;
        m_axi_wid : out std_logic_vector(AXI_ID_WIDTH - 1 downto 0);
        m_axi_wdata : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
        m_axi_wstrb : out std_logic_vector(AXI_DATA_WIDTH / 8 - 1 downto 0);
        m_axi_wlast : out std_logic;

        -- Write response channel
        m_axi_bvalid : in std_logic;
        m_axi_bready : out std_logic;
        m_axi_bresp : in std_logic_vector(1 downto 0);
        m_axi_bid : in std_logic_vector(AXI_ID_WIDTH - 1 downto 0);
 
        -- Framer-side interface
        start_i : in std_logic; -- kick-off one burst at addr_i
        addr_i : in std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
        wdata_i : in std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
        wnext_o : out std_logic; -- pulse: advance framer to next beat
        done_o : out std_logic; -- B received
        error_o : out std_logic -- BRESP error
    );

end entity;

architecture rtl of acp_write_master is
    --
    signal axi_burst_len : unsigned(AXI_BURST_WIDTH - 1 downto 0);
    signal awvalid : std_logic := '0';
    signal wvalid : std_logic := '0';
    signal wlast: std_logic;
    signal wnext : std_logic;
    signal wlen_count : unsigned(AXI_BURST_WIDTH - 1 downto 0) := (others => '0');
begin
    -- Write Address Channel
    m_axi_awid <= (others => '0'); -- single-threaded
    m_axi_awburst <= "01"; -- INCR
    m_axi_awlock <= "00"; -- normal access
    m_axi_awprot <= "000"; -- non-secure, unpriv, data
    m_axi_awqos <= "0000";

    
    m_axi_awcache <= "1111"; -- AWCACHE[1] = cacheable, [3] = write-allocate
    m_axi_awuser <= (others => '1'); -- AWUSER[0] = coherent

    
    m_axi_awsize <= to_svector( -- 2^awsize bytes per beat;  
        ceil_log2(AXI_DATA_WIDTH / 8), 3
    );
    axi_burst_len <= unsigned(burst_len_i) - 1;
    m_axi_awlen <= std_logic_vector(axi_burst_len(3 downto 0)); -- awlen = beats-1
      
    m_axi_awaddr <= addr_i;
    m_axi_awvalid <= awvalid;

    -- Write Data Channel
    m_axi_wid <= (others => '0'); -- AXI3 write ID, single-thread
    m_axi_wdata <= wdata_i;
    m_axi_wstrb <= (others => '1'); -- whole 32B lines, no partial -> no L2 RMW
    m_axi_wlast <= wlast;
    m_axi_wvalid <= wvalid;

    -- Write Response Channel
    m_axi_bready <= '1'; -- always accept writes
    wnext <= m_axi_wready and wvalid; -- beat acce0ted this cycle

    -- AWVALID: raise on start, hold until accepted
    write_addr_channel : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if init_i then
                awvalid <= '0';
            elsif m_axi_awready and awvalid then
                awvalid <= '0';
            elsif start_i then
                awvalid <= '1';
            end if;
        end if;
    end process;

    -- WVALID: raise on start, hold until burst completes at WLAST
    write_data_channel : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if init_i then
                wvalid <= '0';
            elsif wnext and wlast then
                wvalid <= '0';
            elsif start_i then
                wvalid <= '1';
            end if;
        end if;
    end process;

    -- WLAST on the terminal beat of the burst
    wlast <= '1' when wlen_count = axi_burst_len and wnext = '1' else '0';

    -- Monitor burst lengths
    burst_length_count : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if init_i or wlast then
                wlen_count <= (others => '0');
            elsif wnext then
                wlen_count <= wlen_count + 1;
            end if;
        end if;
    end process;

    -- Status
    wnext_o <= wnext; -- present the next beat
    done_o <= m_axi_bvalid; -- B landed (1-cycle, bready=1)
    error_o <= m_axi_bvalid and (m_axi_bresp(1) or m_axi_bresp(0));

end architecture;
