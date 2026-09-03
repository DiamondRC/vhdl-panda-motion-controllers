--------------------------------------------------------------------------------
--  File:   mock_acp.vhd
--  Desc:   Model a AXI3 write-only salve to mock an S_AXI_ACP port.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Based on existing PandA tests.
-- 
-- Accepts one write burst at a time, stores each beat into a backing memory
-- indexed by (awaddr / 8) and finally returns an OKAY B response.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.acp_tb_pkg.all;

entity mock_acp is
    generic (
        -- 64-bit words of backing store
        MEM_WORDS : positive := 64
    );
    port (
        clk_i : in std_logic;

        -- AXI write channel (slave view)
        awvalid_i : in std_logic;
        awready_o : out std_logic;
        awaddr_i : in std_logic_vector(31 downto 0);

        wvalid_i : in std_logic;
        wready_o : out std_logic;
        wdata_i : in std_logic_vector(63 downto 0);
        wstrb_i : in std_logic_vector(7 downto 0);
        wlast_i : in std_logic;

        bvalid_o : out std_logic;
        bready_i : in std_logic;
        bresp_o : out std_logic_vector(1 downto 0);

        -- Inspection
        mem_o : out word64_vec(0 to MEM_WORDS - 1)
    );
end entity;

architecture rtl of mock_acp is
    type st_t is (IDLE, ACTIVE, RESP);

    signal st : st_t := IDLE;
    signal mem : word64_vec(0 to MEM_WORDS - 1) := (others => (others => '0'));
begin
    mem_o <= mem;
    bresp_o <= "00"; -- okay
    awready_o <= '1' when st = IDLE else '0';
    wready_o <= '1' when st = ACTIVE else '0';
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
                        st <= ACTIVE;
                    end if;

                when ACTIVE =>
                    if wvalid_i = '1' then
                        if base + beat < MEM_WORDS then
                            mem(base + beat) <= wdata_i;
                        end if;

                        beat := beat + 1;
                        if wlast_i = '1' then
                            st <= RESP;
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
