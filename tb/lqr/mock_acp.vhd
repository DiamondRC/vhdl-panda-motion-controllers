--------------------------------------------------------------------------------
--  File:   mock_acp.vhd
--  Desc:   Behavioural AXI3 write-only slave modelling S_AXI_ACP for block TBs.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Based on existing PandA tests.
-- 
-- Accepts one write burst at a time and stores each beat into a backing memory
-- indexed by (awaddr / 8).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.acp_tb_pkg.all;

entity mock_acp is
    generic (
        MEM_WORDS : positive := 64   -- 64-bit words of backing store
    );
    port (
        clk_i : in  std_logic;

        -- AXI write channel (slave view)
        awvalid_i : in  std_logic;
        awready_o : out std_logic;
        awaddr_i : in  std_logic_vector(31 downto 0);

        wvalid_i : in  std_logic;
        wready_o : out std_logic;
        wdata_i : in  std_logic_vector(63 downto 0);
        wstrb_i : in  std_logic_vector(7 downto 0);
        wlast_i : in  std_logic;

        bvalid_o : out std_logic;
        bready_i : in  std_logic;
        bresp_o : out std_logic_vector(1 downto 0);

        -- Adversarial control
        w_wait_i : in  natural   := 0;
        berr_i : in  std_logic := '0';

        -- Inspection
        mem_o : out word64_vec(0 to MEM_WORDS - 1)
    );
end entity;

architecture rtl of mock_acp is
    type st_t is (IDLE, ACTIVE, RESP);
    signal st : st_t := IDLE;
    signal mem : word64_vec(0 to MEM_WORDS - 1) := (others => (others => '0'));
    signal wcnt : natural := 0; -- WREADY stall countdown
    signal berr_l : std_logic := '0'; -- SLVERR latched for this burst
begin
    mem_o <= mem;
    bresp_o <= "10" when berr_l = '1' else "00"; -- SLVERR / OKAY
    awready_o <= '1' when st = IDLE else '0';
    wready_o <= '1' when (st = ACTIVE and wcnt = 0) else '0';
    bvalid_o <= '1' when st = RESP else '0';

    process(clk_i)
        variable base : natural := 0; -- word index of burst base
        variable beat : natural := 0; -- beat within burst
    begin
        if rising_edge(clk_i) then
            case st is
                when IDLE =>
                    if awvalid_i = '1' then
                        base := to_integer(unsigned(awaddr_i)) / 8;
                        beat := 0;
                        berr_l <= berr_i; -- latch the error intent
                        wcnt <= w_wait_i; -- initial back-pressure
                        st <= ACTIVE;
                    end if;

                when ACTIVE =>
                    if wcnt > 0 then
                        wcnt <= wcnt - 1; -- stall (WREADY low)
                    elsif wvalid_i = '1' then -- WREADY high, accept
                        if base + beat < MEM_WORDS then
                            mem(base + beat) <= wdata_i;
                        end if;

                        beat := beat + 1;
                        if wlast_i = '1' then
                            st <= RESP;
                        else
                            wcnt <= w_wait_i; -- reload gap to next beat
                        end if;
                    end if;

                when RESP =>
                    if bready_i = '1' then
                        st <= IDLE;
                    end if;
            end case;
        end if;
    end process;
end architecture;
