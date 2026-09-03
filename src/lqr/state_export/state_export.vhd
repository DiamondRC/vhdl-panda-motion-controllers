--------------------------------------------------------------------------------
--  File:   state_export.vhd
--  Desc:   Frame the states to whole cache lines and export.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- State Export
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.state_abi.all;
use work.num_utils.all;

entity state_export is
    generic (
        BASE_ADDR : std_logic_vector(31 downto 0) := x"3FFF0000"; -- DTS contract
        AXES : positive := 3;
        CHUNK : natural := 8; -- whole line payload burst

        -- AXI widths
        AXI_ADDR_WIDTH: natural := 32;
        AXI_DATA_WIDTH : natural := 64;
        AXI_ID_WIDTH : natural := 3;
        AXI_USER_WIDTH : natural := 5;
        AXI_BURST_WIDTH : natural := 4
    );
    port (
        clk_i  : in std_logic; -- PandA master clock
        init_i : in std_logic; -- PandA reset

        tick_i : in std_logic; -- Export one snapshot?
        export_en_i : in std_logic; -- Gain export/non-linear?
        valid_i : in std_logic; -- Payload meaningful?
        
        pos_i, vel_i : in state_word_vec(0 to AXES-1);
        setp_i, setv_i : in state_word_vec(0 to AXES-1);

        busy_o : out std_logic; -- Export in progress?
        error_o : out std_logic; -- Issues?

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
        m_axi_bid : in std_logic_vector(AXI_ID_WIDTH - 1 downto 0)
    );
end entity;

architecture rtl of state_export is
    -- Constants
    constant PAY_BEATS : natural := payload_beats(AXES); -- total payload beats
    constant HI_PAD : state_word := (others => '0'); -- free high word of stamp/beat

    -- FSM
    type state_t is (IDLE, WR_SEQ_ODD, WR_PAYLOAD, WR_SEQ_EVEN);
    signal state : state_t := IDLE;

    -- Frozen snapshot
    signal seq : unsigned(31 downto 0) := (others => '0'); -- even at rest
    signal stamp : unsigned(31 downto 0) := (others => '0');
    signal pos_l, vel_l, setp_l, setv_l : state_word_vec(0 to AXES-1);

    -- Payload loop
    signal pay_ptr : natural range 0 to PAY_BEATS := 0; -- start beat of current chunk_beats
    signal burst_beat : natural range 0 to CHUNK := 0; -- beat within current burst

    -- Master handshake
    signal mst_start, mst_wnext, mst_done : std_logic;
    signal mst_addr : std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
    signal mst_wdata : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
    signal mst_blen : std_logic_vector(AXI_BURST_WIDTH- 1 downto 0);

begin
    -- state of the export
    busy_o <= '0' when state = IDLE else '1';

    u_master : entity work.acp_write_master
        generic map (
            AXI_ADDR_WIDTH => AXI_ADDR_WIDTH,
            AXI_DATA_WIDTH => AXI_DATA_WIDTH,
            AXI_ID_WIDTH => AXI_ID_WIDTH,
            AXI_USER_WIDTH => AXI_USER_WIDTH,
            AXI_BURST_WIDTH => AXI_BURST_WIDTH
        )
        port map (
            clk_i => clk_i,
            init_i => init_i,
            burst_len_i => mst_blen,
            start_i => mst_start,
            addr_i => mst_addr,
            wdata_i => mst_wdata,
            wnext_o => mst_wnext,
            done_o => mst_done,
            error_o => error_o,

            m_axi_awvalid => m_axi_awvalid,
            m_axi_awready => m_axi_awready,
            m_axi_awaddr => m_axi_awaddr,
            m_axi_awid => m_axi_awid,
            m_axi_awlen => m_axi_awlen,
            m_axi_awsize => m_axi_awsize,
            m_axi_awburst => m_axi_awburst,
            m_axi_awcache => m_axi_awcache,
            m_axi_awuser => m_axi_awuser,
            m_axi_awprot => m_axi_awprot,
            m_axi_awlock => m_axi_awlock,
            m_axi_awqos => m_axi_awqos,

            m_axi_wvalid => m_axi_wvalid,
            m_axi_wready => m_axi_wready,
            m_axi_wid => m_axi_wid,
            m_axi_wdata => m_axi_wdata,
            m_axi_wstrb => m_axi_wstrb,
            m_axi_wlast => m_axi_wlast,

            m_axi_bvalid => m_axi_bvalid,
            m_axi_bready => m_axi_bready,
            m_axi_bresp => m_axi_bresp,
            m_axi_bid => m_axi_bid
        );

    -- ctrl: manages the current burst.
    ctrl : process(all)
        variable remain : natural;
        variable chunk_beats : natural;
    begin
        case state is
            when WR_SEQ_ODD | WR_SEQ_EVEN =>
                mst_addr <= BASE_ADDR;
                mst_blen <= to_svector(SEQ_BEATS, AXI_BURST_WIDTH);

            when WR_PAYLOAD =>
                mst_addr <= std_logic_vector(unsigned(BASE_ADDR) +
                    to_unsigned(PAYLOAD_OFF + pay_ptr * BEAT_BYTES, AXI_ADDR_WIDTH)
                );
                -- track what's left to send
                remain := PAY_BEATS - pay_ptr;

                if remain < CHUNK then
                    chunk_beats := remain;
                else
                    chunk_beats := CHUNK;
                end if;

                mst_blen <= to_svector(chunk_beats, AXI_BURST_WIDTH);

            when others =>
                mst_addr <= BASE_ADDR;
                mst_blen <= (others => '0');
        end case;
    end process;

    -- beat_mux: which word is sent this beat?
    beat_mux : process(all)
        variable g : natural; -- global payload beat index
        variable a : natural; -- axis
        variable half : natural; -- 0 = {vel,pos}, 1 = {setv,setp}
    begin
        case state is
            when WR_SEQ_ODD | WR_SEQ_EVEN =>
                if burst_beat = 0 then
                    -- write seq counter to the lowest word
                    mst_wdata <= HI_PAD & std_logic_vector(seq);
                else
                    -- pad line
                    mst_wdata <= (others => '0');
                end if;

            when WR_PAYLOAD =>
                g := pay_ptr + burst_beat;
                if g = 0 then
                    -- write the stamp for the optimiser
                    mst_wdata <= HI_PAD & std_logic_vector(stamp);
                else
                    -- determine the axis/state from the
                    -- global transaction index.
                    a := (g - 1) / 2;
                    half := (g - 1) mod 2;
                    
                    if a >= AXES then
                        -- insert a padding beat
                        mst_wdata <= (others => '0');
                    elsif half = 0 then
                        mst_wdata <= vel_l(a) & pos_l(a);
                    else
                        mst_wdata <= setv_l(a) & setp_l(a);
                    end if;
                end if;

            when others =>
                mst_wdata <= (others => '0');
        end case;
    end process;

    -- FSM: drive the seqlock write
    fsm : process(clk_i)
        variable remain : natural;
        variable chunk_beats : natural;
    begin
        if rising_edge(clk_i) then
            if init_i then
                state <= IDLE;
                seq <= (others => '0');
                stamp <= (others => '0');

                pay_ptr <= 0;
                burst_beat <= 0;
                mst_start <= '0';
            else
                -- default 1 cycle burst
                mst_start <= '0';

                -- advance within a burst
                if mst_wnext then
                    burst_beat <= burst_beat + 1;
                end if;

                case state is
                    when IDLE =>
                        -- begin state transaction
                        if tick_i and valid_i and export_en_i then
                            -- freeze snapshot
                            pos_l <= pos_i;
                            vel_l <= vel_i;
                            setp_l <= setp_i;
                            setv_l <= setv_i;

                            -- advance
                            stamp <= stamp + 1;
                            seq <= seq + 1; -- odd

                            -- reset
                            pay_ptr <= 0;
                            burst_beat <= 0;
                            
                            -- launch seq-odd
                            mst_start <= '1'; 
                            state <= WR_SEQ_ODD;

                            -- stamp
                        end if;

                    when WR_SEQ_ODD =>
                        if mst_done then
                            burst_beat <= 0;
                            -- send first payload chunk_beats
                            mst_start <= '1'; 
                            state <= WR_PAYLOAD;
                        end if;

                    when WR_PAYLOAD =>
                        if mst_done then
                            -- track chunk_beats transactions
                            remain := PAY_BEATS - pay_ptr;

                            -- track outstanding work
                            if remain < CHUNK then
                                chunk_beats := remain;
                            else
                                chunk_beats := CHUNK;
                            end if;

                            if pay_ptr + chunk_beats >= PAY_BEATS then
                                -- finish transaction
                                seq <= seq + 1;
                                burst_beat <= 0;
                                mst_start <= '1';
                                state <= WR_SEQ_EVEN;
                            else
                                -- send next chunk_beats
                                pay_ptr <= pay_ptr + chunk_beats;
                                burst_beat <= 0;
                                mst_start <= '1';
                            end if;
                        end if;

                    when WR_SEQ_EVEN =>
                        if mst_done then
                            -- even => stable for PS reads
                            state <= IDLE;
                        end if;
                end case;
            end if;
        end if; -- clk
    end process;

end architecture;