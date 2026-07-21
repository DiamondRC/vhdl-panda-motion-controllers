library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

-- Custom packages
use work.lqr_constants.all;
use work.global_subtypes.all;
use work.state_enum.all;

entity ts_mac is
    generic (
        -- Number of DSPs to use per cycle
        K_CHUNK        : natural := 3;
        N_IN           : natural := 3;
        N_OUT          : natural := 3;
        GAIN_HI        : natural := 16 - 1;
        GAIN_LO        : natural := 16
    );
    port (
        clk            : in std_logic;
        reset          : in std_logic;

        first_matrix   : in panda_port  := (others => '0'); -- 
        second_matrix  : in panda_port  := (others => '0'); -- 
        result_matrix  : in panda_port  := (others => '0'); -- 
        done           : out std_logic;
    );
end entity ts_mac;

architecture main of ts_mac is
    -- Array definitions
    type prod_array is array (0 to K_CHUNK-1) of sfixed(PROD_HI downto PROD_LO);
    type err_vec    is array (0 to N_ERR-1)   of sfixed(ERR_HI downto ERR_LO);
    type gain_row   is array (0 to K_CHUNK-1) of sfixed(K_HI downto K_LO);

    -- Matrix consts
    signal chunk_start    : natural range 0 to N_ERR := 0;
    signal row_i          : natural range 0 to N_OUT - 1 := 0;

    -- Intermediates
    signal prod_arr       : prod_array;
    signal err_v          : err_vec;
    signal gain_r         : gain_row;

    -- Multiplication

    -- Accumulation
    signal chunk_sum      : sfixed(ACC_HI downto ACC_LO);
    signal acc_out        : sfixed(ACC_HI downto ACC_LO);

begin
    process(clk)
    begin
        if rising_edge(clk) then
            -- This isn't going to work, constantly accumulating sums


            -- Time-multiplexed MAC (multiply accumulate) with pipelining
            gen_dsp : if K_CHUNK > 1 generate
                gen_loop : for i in 0 to K_CHUNK-1 generate
                    -- Calculate the index for each DSP
                    signal term_idx : natural := chunk_start + i;
                begin
                    prod_arr(i) <= gain_r(row_i)(term_idx) * err_v(term_idx);
                    chunk_sum <= resize(chunk_sum + prod_arr(i), chunk_sum'high, chunk_sum'low);
                end loop gen_loop;
            end generate gen_dsp;

            gen_single : if K_CHUNK = 1 generate
                prod_arr(0) <= gain_r(row_i)(chunk_start) * err_v(chunk_start);
                chunk_sum <= resize(chunk_sum + prod_arr(0), chunk_sum'high, chunk_sum'low);
            end generate gen_single;

            -- Reset accumulator at start of row
            if chunk_start = 0 then
                acc_out <= (others => '0');
            end if;

            -- Accumulate the chunk sum
            acc_out <= resize(acc_out + chunk_sum, acc_out'high, acc_out'low);

            -- Advance chunk
            if chunk_start + K_CHUNK >= N_ERR then
                -- Row done
                if row_i = N_OUT-1 then
                    state <= ROUND_OUT;
                else
                    row_i <= row_i + 1;
                    chunk_start <= 0;
                end if;
            else
                chunk_start <= chunk_start + K_CHUNK;
            end if;

        end if;  -- Clock
    end process; -- Main logic
end main;