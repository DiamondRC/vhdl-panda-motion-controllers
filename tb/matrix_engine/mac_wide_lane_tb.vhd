--------------------------------------------------------------------------------
--  File:   mac_wide_lane_tb.vhd
--  Desc:   The testbench to drive the wide MAC lane for the PandA.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use ieee.fixed_pkg.all;

use work.panda_consts.all;
-- use work.fp_utils.all;
use work.num_utils.all;
use work.matrix_consts.all;


entity mac_wide_lane_td is
end entity mac_wide_lane_td;

architecture rtl of mac_wide_lane_td is
    -- System
    constant p_clk_period : time := MASTER_CLK_PERIOD;
    signal sim_done : boolean := false;

    -- Shared
    signal clk_i : std_logic := '0';
    signal init_i : std_logic := '0';

    -- Narrow (1x1) lane ports
    signal n_a : signed(DSP_COEFF_W - 1 downto 0) := (others => '0');
    signal n_b : signed(DSP_DATA_W  - 1 downto 0) := (others => '0');
    signal n_load : std_logic := '0';
    signal n_en : std_logic := '0';
    signal n_acc : signed(DSP_ACC_W - 1 downto 0);

    -- Wide (2x2) lane ports
    signal w_a : signed(LANE_A_W - 1 downto 0) := (others => '0');
    signal w_b : signed(LANE_B_W - 1 downto 0) := (others => '0');
    signal w_load : std_logic := '0';
    signal w_en : std_logic := '0';
    signal w_acc : signed(LANE_ACC_W - 1 downto 0);

    -- Test definition
    procedure run_mac (
        constant name : in string;
        constant a0, a1, a2 : in signed;
        constant b0, b1, b2 : in signed;

        signal clk_i  : in  std_logic;
        signal a_i    : out signed;
        signal b_i    : out signed;
        signal load_i : out std_logic;
        signal en_i   : out std_logic;
        signal acc_o  : in  signed
    ) is
        -- Golden reference: 
        -- plain full-width multiply-accumulate
        variable exp : signed(acc_o'range);
    begin
        exp := resize(a0 * b0, acc_o'length)
             + resize(a1 * b1, acc_o'length)
             + resize(a2 * b2, acc_o'length);

        -- Feed the three terms, load on the first
        a_i <= a0;
        b_i <= b0;
        load_i <= '1';
        en_i <= '1';
        wait until rising_edge(clk_i);
        a_i <= a1;
        b_i <= b1;
        load_i <= '0';
        wait until rising_edge(clk_i);
        a_i <= a2;
        b_i <= b2;
        wait until rising_edge(clk_i);

        -- Drop enable to let the accumulator settle
        en_i <= '0';
        wait until rising_edge(clk_i);

        -- Report test result
        assert acc_o = exp
            report name &
                ": acc got " &
                integer'image(to_integer(acc_o)) &
                ", expected " &
                integer'image(to_integer(exp))
            severity error;
    end procedure;

    -- Test helpers
    function an(v : integer) return signed is
    begin
    return to_signed(v, DSP_COEFF_W); end;

    function bn(v : integer) return signed is
    begin
    return to_signed(v, DSP_DATA_W); end;

    function aw(v : integer) return signed is
    begin
    return to_signed(v, LANE_A_W); end;

    function bw(v : integer) return signed is
    begin
    return to_signed(v, LANE_B_W); end;

begin

    clkgen : process
    begin
        while not sim_done loop
            clk_i <= not clk_i;
            wait for p_clk_period / 2;
        end loop;
        wait;
    end process;

    -- A lane with a single DSP unit.
    narrow_uut: entity work.mac_wide_lane
    generic map (
        A_W => DSP_COEFF_W,
        B_W => DSP_DATA_W,
        ACC_W => DSP_ACC_W
    )
    port map (
        clk_i => clk_i,
        init_i => init_i,
        a_i => n_a,
        b_i => n_b,

        load_i => n_load,
        en_i => n_en,

        acc_o => n_acc
    );

    -- A lane featuring cacaded DSP units.
    wide_uut: entity work.mac_wide_lane
    generic map (
        A_W => LANE_A_W,
        B_W => LANE_B_W,
        ACC_W => LANE_ACC_W
    )
    port map (
        clk_i => clk_i,
        init_i => init_i,
        a_i => w_a,
        b_i => w_b,

        load_i => w_load,
        en_i => w_en,

        acc_o => w_acc
    );

process
begin
    -- Begin
    wait until rising_edge(clk_i);

    -- Reset the lanes
    init_i <= '1';
    wait until rising_edge(clk_i);
    init_i <= '0';
    wait until rising_edge(clk_i);

    -- Narrow (1x1) lane: the single-DSP anchor
    run_mac(
        "narrow basic",
        an(2), an(3), an(4),
        bn(5), bn(6), bn(7),
        clk_i, n_a, n_b, n_load, n_en, n_acc
    );
    run_mac(
        "narrow negatives",
        an(-2), an(3), an(-4),
        bn(5), bn(-6), bn(7),
        clk_i, n_a, n_b, n_load, n_en, n_acc
    );
    run_mac(
        "extreme single",
        an(1499999), an(-10), an(16777215),
        bn(131071), bn(-131070), bn(-131070),
        clk_i, n_a, n_b, n_load, n_en, n_acc
    );

    -- Wide (2x2) lane: the cascaded grid
    run_mac(
        "wide basic",
        aw(100), aw(200), aw(300),
        bw(5), bw(6), bw(7),
        clk_i, w_a, w_b, w_load, w_en, w_acc
    );
    run_mac(
        "wide cross-chunk",
        shift_left(aw(1), DSP_COEFF_W - 1) + aw(3), aw(1), aw(0),
        shift_left(bw(1), DSP_DATA_W - 1) + bw(5), bw(1), bw(0),
        clk_i, w_a, w_b, w_load, w_en, w_acc
    );
    run_mac(
        "wide max",
        max_s(LANE_A_W), aw(0), aw(0),
        max_s(LANE_B_W), bw(0), bw(0),
        clk_i, w_a, w_b, w_load, w_en, w_acc
    );
    run_mac(
        "wide min",
        min_s(LANE_A_W), aw(0), aw(0),
        min_s(LANE_B_W), bw(0), bw(0),
        clk_i, w_a, w_b, w_load, w_en, w_acc
    );
    run_mac(
        "wide mixed sign",
        max_s(LANE_A_W), aw(0), aw(0),
        min_s(LANE_B_W), bw(0), bw(0),
        clk_i, w_a, w_b, w_load, w_en, w_acc
    );

    -- If successful we can finish
    report "LANE TESTS PASS" severity note;
    sim_done <= true;

    wait;
end process;

end architecture rtl;
