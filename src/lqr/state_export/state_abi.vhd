--------------------------------------------------------------------------------
--  File:   state_abi.vhd
--  Desc:   Byte/Beat layout of the exported states.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- State ABI
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

package state_abi is
    -- Geometry: every field is 32-bit; ACP beats are 64-bit, A9 line = 32 B.
    constant WORD_BYTES : natural := 4;
    constant BEAT_BYTES : natural := 8;
    constant LINE_BYTES : natural := 32;
    constant WORDS_PER_BEAT : natural := BEAT_BYTES / WORD_BYTES; -- 2
    constant BEATS_PER_LINE : natural := LINE_BYTES / BEAT_BYTES; -- 4
    constant EXPORT_FRAC : natural := 6; -- compromise on precision v. size
    
    -- Line 0: seq alone, so its odd/even writes stay whole-line.
    constant SEQ_OFF : natural := 0;
    constant SEQ_BEATS : natural := BEATS_PER_LINE; -- burst len, phase A/C
    
    -- Payload region starts at line 1.
    constant PAYLOAD_OFF : natural := LINE_BYTES; -- 0x20
    constant STAMP_OFF : natural := PAYLOAD_OFF; -- stamp first
    constant AXIS0_OFF : natural := PAYLOAD_OFF + BEAT_BYTES; -- after stamp beat -> 0x28
    constant AXIS_STRIDE : natural := 16; -- 4 words / axis

    -- Field sub-offsets within one axis.
    constant POS_OFF : natural := 0;
    constant VEL_OFF : natural := 4;
    constant SETP_OFF : natural := 8;
    constant SETV_OFF : natural := 12;
    
    -- AXES-dependent sizing
    function payload_words(axes : positive) return natural; -- 1(stamp) + 4*axes
    function payload_beats(axes : positive) return natural; -- padded to whole lines
    function axis_off(k : natural) return natural; -- byte offset of axis k

    -- A single 32-bit field (seq/stamp/pos/vel/…) and a per-axis vector of them.
    subtype state_word is std_logic_vector(8*WORD_BYTES - 1 downto 0); -- 32-bit
    type state_word_vec is array (natural range <>) of state_word;

    -- ACP write-master bundle
    -- Bundled so the master threads one port per level up through the
    -- PandABlocks wrappers instead of ~22 loose signals! @_@
    type acp_mosi_t is record
        awvalid : std_logic;
        awaddr : std_logic_vector(31 downto 0);
        awid : std_logic_vector(2 downto 0);
        awlen : std_logic_vector(3 downto 0);
        awsize : std_logic_vector(2 downto 0);
        awburst : std_logic_vector(1 downto 0);
        awcache : std_logic_vector(3 downto 0);
        awuser : std_logic_vector(4 downto 0);
        awprot : std_logic_vector(2 downto 0);
        awlock : std_logic_vector(1 downto 0);
        awqos : std_logic_vector(3 downto 0);
        wvalid : std_logic;
        wid : std_logic_vector(2 downto 0);
        wdata : std_logic_vector(63 downto 0);
        wstrb : std_logic_vector(7 downto 0);
        wlast : std_logic;
        bready : std_logic;
    end record;

    type acp_miso_t is record
        awready : std_logic;
        wready : std_logic;
        bvalid : std_logic;
        bresp : std_logic_vector(1 downto 0);
        bid : std_logic_vector(2 downto 0);
    end record;

    -- Idle default for elaboratation: slave never ready.
    constant ACP_MISO_IDLE : acp_miso_t := (
        awready => '0',
        wready => '0',
        bvalid => '0',
        bresp => "00",
        bid => "000"
    );

end package;

package body state_abi is
    function payload_words(axes : positive) return natural is
    begin
        return 1 + 4 * axes; -- stamp + {pos,vel,set_p,set_v} / axis
    end function;

    -- ceil(words / 2) beats, rounded up to a whole cache line.
    function payload_beats(axes : positive) return natural is
        constant raw : natural := (payload_words(axes) + WORDS_PER_BEAT - 1) / WORDS_PER_BEAT;
        constant lines : natural := (raw + BEATS_PER_LINE - 1) / BEATS_PER_LINE;
    begin
        return lines * BEATS_PER_LINE;
    end function;

    function axis_off(k : natural) return natural is
    begin
        return AXIS0_OFF + k * AXIS_STRIDE;
    end function;

end package body;
