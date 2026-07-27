--------------------------------------------------------------------------------
--  File:   bram_store_td.vhd
--  Desc:   A testbench to probe the PandA's BRAM.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
-- use work.fp_utils.all;
use work.num_utils.all;
-- use work.matrix_consts.all;
-- use work.mac_utils.all;


entity bram_store_td is
end entity bram_store_td;

architecture rtl of bram_store_td is
    -- System
    constant p_clk_period : time := MASTER_CLK_PERIOD;
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    -- Shared
    signal clk_i : std_logic := '0';
    -- signal init_i : std_logic := '0';

    -- Store Constants
    constant DEPTH : natural := 3 * 3;
    constant DATA_W : natural := 32;

    -- BRAM ports
    signal wr_addr_i : unsigned(ceil_log2(DEPTH) - 1 downto 0) :=
        (others => '0');
    signal wr_data_i : signed(DATA_W - 1 downto 0) :=
        (others => '0');
    signal wr_en_i : std_logic := '0';

    signal rd_addr_i : unsigned(ceil_log2(DEPTH) - 1 downto 0) :=
        (others => '0');
    signal rd_data_o : signed(DATA_W - 1 downto 0) :=
        (others => '0');

    -- Test definitions
    procedure wr (
        -- Write test
        constant addr : in natural;
        constant data : in integer;
        constant en : in std_logic;

        signal clk_i : in std_logic;
        signal wr_addr_i : out unsigned;
        signal wr_data_i : out signed;
        signal wr_en_i : out std_logic

    ) is
    begin
        -- Write to BRAM
        wr_addr_i <= to_unsigned(addr, wr_addr_i'length);
        wr_data_i <= to_signed(data, wr_data_i'length);
        wr_en_i <= en;

        -- Wait a cycle, ready
        wait until rising_edge(clk_i);
        wr_en_i <= '0';

    end procedure;

    procedure rd_check (
        -- Read test
        constant name : in string;
        constant addr : in natural;
        constant exp : in integer;

        signal clk_i : in std_logic;
        signal rd_addr_i : out unsigned;
        signal rd_data_o : in signed;
        signal fail_o : out std_logic
    ) is
    begin
        -- Read from BRAM
        rd_addr_i <= to_unsigned(addr, rd_addr_i'length);
        
        -- Two cycle delay (BRAM internal reg + BRAM external reg)
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);

        if rd_data_o /= to_signed(exp, rd_data_o'length) then
            fail_o <= '1';
            report name &
                ": got " &
                integer'image(to_integer(rd_data_o)) &
                 ", expected " &
                integer'image(exp)
            severity error;
        end if;

    end procedure;

    procedure check_latency (
        constant name : in string;
        constant old_addr, old_val : in integer;
        constant new_addr, new_val : in integer;

        signal clk_i : in std_logic;
        signal rd_addr_i : out unsigned;
        signal rd_data_o : in signed;
        signal fail_o : out std_logic
    ) is
    begin
        -- Fill pipe with old values
        rd_addr_i <= to_unsigned(old_addr, rd_addr_i'length);
        wait until rising_edge(clk_i); -- two cycles clears any
        wait until rising_edge(clk_i); -- contiminants

        -- Switch to new values
        rd_addr_i <= to_unsigned(new_addr, rd_addr_i'length);
        
        wait until rising_edge(clk_i); -- one cycle, still has old values
        if rd_data_o /= to_signed(old_val, rd_data_o'length) then
            fail_o <= '1';
            report name &
                " +1: expected old " &
                integer'image(old_val) &
                " got " &
                integer'image(to_integer(rd_data_o))
            severity error;
        end if;

        wait until rising_edge(clk_i); -- two cycles, new emerges
        if rd_data_o /= to_signed(new_val, rd_data_o'length) then
            fail_o <= '1';
            report name &
                " +2: expected new " &
                integer'image(new_val) &
                " got " &
                integer'image(to_integer(rd_data_o))
            severity error;
        end if;
    end procedure;

begin

    clkgen : process
    begin
        while not sim_done loop
            clk_i <= not clk_i;
            wait for p_clk_period / 2;
        end loop;
        wait;
    end process;

    bram : entity work.bram_store
    generic map (
        DEPTH => DEPTH,
        DATA_W => DATA_W
    )
    port map (
        clk_i => clk_i,

        wr_addr_i => wr_addr_i,
        wr_data_i => wr_data_i,
        wr_en_i => wr_en_i,

        rd_addr_i => rd_addr_i,
        rd_data_o => rd_data_o
    );

process
begin
    -- Begin
    wait until rising_edge(clk_i);
    
    -- Phase 1: preload
    wr(
        1, -- Address
        -1, -- Data
        '1', -- En
        clk_i, wr_addr_i, wr_data_i, wr_en_i
    );
    wr(
        2, -- Address
        131071, -- Data
        '1', -- En
        clk_i, wr_addr_i, wr_data_i, wr_en_i
    );

    -- Phase 2: write then read-back
    rd_check(
        "read negative",
        1, -- Address
        -1, -- Expected Value
        clk_i, rd_addr_i, rd_data_o, fail
    );
    rd_check(
        "read limit",
        2, -- Address
        131071, -- Expected Value
        clk_i, rd_addr_i, rd_data_o, fail
    );

    -- Phase 3: prove the 2-cycle skew
    check_latency(
        "latency",
        2, -- Old address
        131071, -- Old value
        1, -- New address
        -1, -- New value
        clk_i, rd_addr_i, rd_data_o, fail
    );
    
    -- Phase 4: write-enable gating
    wr(
        1, -- Address
        999, -- Data
        '0', -- En low => write no-op
        clk_i, wr_addr_i, wr_data_i, wr_en_i
    );
    rd_check(
        "wr_en gate",
        1, -- Address
        -1, -- Old value, not 999
        clk_i, rd_addr_i, rd_data_o, fail
    );

    -- Report the overall result
    wait until rising_edge(clk_i);
    if fail = '0' then
        report "BRAM TESTS PASS" severity note;
    else
        report "BRAM TESTS FAILED" severity failure;
    end if;
    sim_done <= true;

    wait;
end process;

end architecture rtl;