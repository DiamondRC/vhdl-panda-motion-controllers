--------------------------------------------------------------------------------
--  File:   bram_buffer_td.vhd
--  Desc:   A testbench to check the atomic safety of the DMA to BRAM data
--          stream. Tearing guarded with a double-buffer.
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
use work.mac_utils.all;


entity bram_buffer_td is
end entity bram_buffer_td;

architecture rtl of bram_buffer_td is
    -- System
    constant p_clk_period : time := MASTER_CLK_PERIOD;
    signal sim_done : boolean := false;
    signal fail : std_logic := '0';

    -- Shared
    signal clk_i : std_logic := '0';
    signal init_i : std_logic := '0';

    -- Buffer constants
    constant NUM_BUFFERS : natural := 2;
    constant DEPTH : natural := 4;
    constant DATA_W : natural := 16;

    -- BRAM ports
    signal wr_addr_i : unsigned(ceil_log2(DEPTH) - 1 downto 0)
        := (others => '0');
    signal wr_data_i : signed(DATA_W - 1 downto 0)
        := (others => '0');
    signal wr_en_i : std_logic := '0';
    signal commit_i : std_logic := '0';

    signal rd_addr_i : unsigned(ceil_log2(DEPTH) - 1 downto 0)
        := (others => '0');
    signal rd_data_o : signed(DATA_W - 1 downto 0);

    -- Buffer items
    signal pass_start_i : std_logic := '0';
    signal gen_o : unsigned(GEN_W - 1 downto 0);


    -- Test definitions
    procedure fill (
        -- Fill the inactive buffer
        constant base : in integer;

        signal clk_i     : in  std_logic;
        signal wr_addr_i : out unsigned;
        signal wr_data_i : out signed;
        signal wr_en_i   : out std_logic
    ) is
    begin
        for k in 0 to DEPTH - 1 loop
            wr_addr_i <= to_unsigned(k, wr_addr_i'length);
            wr_data_i <= to_signed(base + k, wr_data_i'length);
            wr_en_i   <= '1';
            wait until rising_edge(clk_i);
        end loop;
        wr_en_i <= '0';
    end procedure;
    
    procedure commit_pulse (
        -- Pulse the commit flag for a cycle.
        signal clk_i    : in  std_logic;
        signal commit_i : out std_logic
    ) is
    begin
        commit_i <= '1';
        wait until rising_edge(clk_i);
        commit_i <= '0';
    end procedure;

    procedure pass_pulse (
        -- Pulse pass_start for a cycle.
        signal clk_i        : in  std_logic;
        signal pass_start_i : out std_logic
    ) is
    begin
        pass_start_i <= '1';
        wait until rising_edge(clk_i);
        pass_start_i <= '0';
    end procedure;

    procedure rd_check (
        -- Read the whole buffer,
        -- checking each address against base + addr.
        constant name : in string;
        constant base : in integer;

        signal clk_i     : in  std_logic;
        signal rd_addr_i : out unsigned;
        signal rd_data_o : in  signed;
        signal fail_o    : out std_logic
    ) is
    begin
        for k in 0 to DEPTH - 1 loop
            rd_addr_i <= to_unsigned(k, rd_addr_i'length);
            wait until rising_edge(clk_i);
            wait until rising_edge(clk_i);
            wait until falling_edge(clk_i);

            if rd_data_o /= to_signed(base + k, rd_data_o'length) then
                fail_o <= '1';
                report name &
                    ": addr " &
                    integer'image(k) &
                    " got " &
                    integer'image(to_integer(rd_data_o)) &
                    ", expected " &
                    integer'image(base + k)
                severity error;
            end if;

        end loop;
    end procedure;

    procedure gen_check (
        -- Check the generation counter.
        constant name : in string;
        constant exp  : in natural;

        signal clk_i  : in  std_logic;
        signal gen_o  : in  unsigned;
        signal fail_o : out std_logic
    ) is
    begin
        wait until falling_edge(clk_i);

        if gen_o /= to_unsigned(exp, gen_o'length) then
            fail_o <= '1';
            report name &
                ": gen got " &
                integer'image(to_integer(gen_o)) &
                ", expected " &
                integer'image(exp)
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

    uut: entity work.bram_buffer
    generic map (
        NUM_BUFFERS => NUM_BUFFERS,
        DEPTH => DEPTH,
        DATA_W => DATA_W
    )
    port map (
        clk_i => clk_i,
        init_i => init_i,

        wr_addr_i => wr_addr_i,
        wr_data_i => wr_data_i,
        wr_en_i => wr_en_i,
        commit_i => commit_i,

        rd_addr_i => rd_addr_i,
        rd_data_o => rd_data_o,
        pass_start_i => pass_start_i,

        gen_o => gen_o
    );

process
begin
    -- Begin
    wait until rising_edge(clk_i);

    -- Reset the buffer
    init_i <= '1';
    wait until rising_edge(clk_i);
    init_i <= '0';
    wait until rising_edge(clk_i);

    -- ------------------------------------------------------------
    -- Deferred swap / no torn read
    -- ------------------------------------------------------------
    -- Fill + commit + swap => the active buffer is pattern A.
    fill(
        100, 
        clk_i, wr_addr_i, wr_data_i, wr_en_i
    );
    commit_pulse(clk_i, commit_i);
    pass_pulse(clk_i, pass_start_i);
    rd_check(
        "t1 initial A",
        100,
        clk_i, rd_addr_i, rd_data_o, fail
    );
    gen_check(
        "t1 first swap",
        1,
        clk_i, gen_o, fail
    );

    -- Mid-pass update: fill pattern B and commit, do not pass_start.
    fill(
        200,
        clk_i, wr_addr_i, wr_data_i, wr_en_i
    );
    commit_pulse(clk_i, commit_i);

    -- The swap is deferred: reads must still be pattern A + gen unchanged.
    rd_check(
        "t1 still A",
        100,
        clk_i, rd_addr_i, rd_data_o, fail
    );
    gen_check("t1 deferred", 1, clk_i, gen_o, fail);

    -- Cross a pass boundary: reads flip to pattern B, gen increments.
    pass_pulse(clk_i, pass_start_i);
    rd_check(
        "t1 now B",
        200,
        clk_i, rd_addr_i, rd_data_o, fail
    );
    gen_check("t1 second swap", 2, clk_i, gen_o, fail);

    -- ------------------------------------------------------------
    -- Ping-pong over several swaps
    -- ------------------------------------------------------------

    -- ------------------------------------------------------------
    -- Spatial isolation - writes to the inactive
    --         buffer never disturb reads of the active
    -- ------------------------------------------------------------

    -- Report the overall result
    wait until rising_edge(clk_i);
    if fail = '0' then
        report "BRAM BUFFER TESTS PASS" severity note;
    else
        report "BRAM BUFFER TESTS FAILED" severity failure;
    end if;
    sim_done <= true;

    wait;
end process;

end architecture rtl;
