--------------------------------------------------------------------------------
--  File:   brett_pid.vhd
--  Desc:   Attempt implementation matching Brett's PID controller for PandA.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Custom packages
use work.global_constants.all;
use work.global_enums.all;
use work.global_subtypes.all;

entity brett_pid is
    port (
        clk_i          : in std_logic;
        init_i         : in std_logic;

        pid_period_i   : in panda_port  := (others => '0');

        kp_i           : in panda_port  := (others => '0');
        kv_i           : in panda_port  := (others => '0');
        ki_i           : in panda_port  := (others => '0');
        kd_i           : in panda_port  := (others => '0');
        kaff_i         : in panda_port  := (others => '0');
        kpff0_i        : in panda_port  := (others => '0');
        kpff1_i        : in panda_port  := (others => '0');

        do_vel_diff_i  : in panda_port  := (others => '0');
        dir_toggle_i   : in panda_port  := (others => '0');
        dt_i           : in panda_port  := (others => '0');
        dt_inv_i       : in panda_port  := (others => '0');
        max_integral_i : in panda_port  := (others => '0');
        max_output_i   : in panda_port  := (others => '0');

        real_input_i   : in panda_port  := (others => '0'); -- Measured value
        setpoint_i     : in panda_port  := (others => '0'); -- Desired value

        real_output_o  : out panda_port := (others => '0') -- Output value
    );
end entity brett_pid;

architecture no_pipeline of brett_pid is
    -- P term
    signal p_mul      : signed(P_MUL_SIZE -1 downto 0)
        := (others => '0');
    signal p_scaled   : signed(P_SCALED_SIZE - 1 downto 0)
        := (others => '0');

    -- V term
    signal v_scaled   : signed(V_SCALED_SIZE - 1 downto 0)
        := (others => '0');

    -- I term
    signal i_mul_dt   : signed(I_MUL_DT_SIZE - 1 downto 0)
        := (others => '0');
    signal i_mul_err  : signed(I_MUL_ERR_SIZE - 1 downto 0)
        := (others => '0');
    signal i_sca_part : signed(I_SCA_PRT_SIZE - 1 downto 0)
        := (others => '0');
    signal i_scaled   : signed(I_SCALED_SIZE - 1 downto 0)
        := (others => '0');

    -- D term
    signal d_mul_dt   : signed(D_MUL_DT_SIZE - 1 downto 0)
        := (others => '0');
    signal d_mul_err  : signed(D_MUL_ERR_SIZE - 1 downto 0)
        := (others => '0');
    signal d_scaled   : signed(D_SCALED_SIZE - 1 downto 0)
        := (others => '0');

    -- FF term
    signal ff_scaled  : signed(FF_SCALED_SIZE - 1 downto 0)
        := (others => '0');

    -- Sum term
    signal sum_scaled : signed(SUM_SCALED_SIZE - 1 downto 0)
        := (others => '0');
    signal sum_int    : signed(SUM_INT_SIZE - 1 downto 0)   
        := (others => '0');

    -- Master clock
    signal prev_pos   : signed(PANDA_PORT_SIZE - 1 downto 0)
        := (others => '0');
    signal vel        : signed(VEL_SIZE - 1 downto 0)
        := (others => '0');
    signal pos_err    : signed(POS_ERR_SIZE - 1 downto 0)
        := (others => '0');
    signal max_i_term : signed(MAX_I_SIZE - 1 downto 0)
        := (others => '0');

    -- PID clock
    -- 625 is ~200kHz
    signal clk_count  : unsigned(PANDA_PORT_SIZE - 1 downto 0)
        := (others => '0');
    signal trigger    : std_logic
        := '0';

    -- Error
    signal prev_err   : signed(POS_ERR_SIZE - 1 downto 0);

    -- Misc
    signal d_err      : signed(D_ERR_SIZE - 1 downto 0);
    signal do_work    : std_logic
        := '0';
    signal state      : pid_state
        := IDLE;
    signal round_out  : signed(PANDA_PORT_SIZE - 1 downto 0);


begin
    process(clk_i)
    -- Creates a local clock which is some
    -- number of ticks slower than the master
    -- PandA clock.
    begin
        if rising_edge(clk_i) then
            if init_i = '1' then
                trigger <= '0';
                clk_count <= (others => '0');
            else
                if clk_count = unsigned(pid_period_i) - 1 then
                    trigger <= '1';
                    clk_count <= (others => '0');
                else
                    trigger <= '0';
                    clk_count <= clk_count + 1;
                end if; -- Update count
            end if; -- Process reset
        end if; -- Clock
    end process;


    -- Main logic
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            -- Handle master processes

            -- Calculate the position error
            pos_err  <= signed(setpoint_i) - signed(real_input_i);

            -- TODO - move into main logic?
            -- Calculate the velocity
            -- This is performed on the master clock,
            -- so the division interval is constant.
            -- Thus, make 1/dt a constant we multiply by.
            prev_pos <= signed(real_input_i);
            vel      <= (
                            signed(real_input_i) - signed(prev_pos)
                        ) * VEL_CONST;

            -- Scale integral limit to fixed point
            max_i_term <= shift_left(resize(signed(max_integral_i), max_i_term'length), DT_FRAC);

            -- Output stored work
            real_output_o <= std_logic_vector(round_out);
            

            if init_i = '1' then
                -- Error
                pos_err       <= (others => '0');
                prev_err      <= (others => '0');
                d_err         <= (others => '0');

                -- Velocity
                prev_pos      <= (others => '0');
                vel           <= (others => '0');

                -- P term
                p_mul         <= (others => '0');
                p_scaled      <= (others => '0');

                -- V term
                v_scaled      <= (others => '0');

                -- I term
                i_mul_dt      <= (others => '0');
                i_mul_err     <= (others => '0');
                i_sca_part    <= (others => '0');
                i_scaled      <= (others => '0');

                -- D term
                d_mul_dt      <= (others => '0');
                d_mul_err     <= (others => '0');
                d_scaled      <= (others => '0');

                -- FF term
                ff_scaled     <= (others => '0');

                -- Sum
                sum_scaled    <= (others => '0');
                sum_int       <= (others => '0');

                -- Misc
                max_i_term    <= (others => '0');
                round_out     <= (others => '0');
                real_output_o <= (others => '0');
                do_work       <= '0';

            elsif trigger = '1' then
                -- Start logic next master clock
                do_work <= '1';

            elsif do_work = '1' then
                -- Do work
                case state is
                    when IDLE     =>
                        -- Begin calculation
                        p_mul     <= resize(signed(kp_i), KP_I_SIZE) *
                                     pos_err;

                        i_mul_dt  <= resize(signed(ki_i), KI_I_SIZE) *
                                     resize(signed(dt_i), DT_SIZE);
                                

                        d_mul_dt  <= resize(signed(kd_i), KD_I_SIZE) * 
                                     resize(signed(dt_inv_i), DT_I_SIZE);

                        -- Update previous error
                        prev_err  <= pos_err;

                        if do_vel_diff_i(0) = '1' then
                            -- TODO
                            -- d_err <= signed(real_input_i) - 
                            -- signed(prev_position);
                            d_err <= signed(pos_err) - signed(prev_err);
                        else
                            -- Uses last PID work's prev_err
                            d_err <= signed(pos_err) - signed(prev_err);
                        end if;

                        state     <= STAGE_2;

                    when STAGE_2  => 
                        i_mul_err <= pos_err * i_mul_dt;

                        d_mul_err <= d_mul_dt * d_err;

                        -- TMP
                        v_scaled  <= (others => '0');
                        ff_scaled <= (others => '0');

                        state     <= STAGE_3;
                    
                    when STAGE_3     =>
                        -- Scale part back to smallest
                        -- fixed point.
                        -- Integral remains fixed point at this stage,
                        -- round after adding to the sum.
                        i_sca_part   <= resize(
                            shift_right(
                                i_mul_err + 
                                shift_right(
                                    i_mul_err,
                                    DT_FRAC
                                ),
                            DT_FRAC), 
                            i_sca_part'length);

                        d_scaled     <= resize(
                            shift_right(
                                d_mul_err + 
                                shift_right(
                                    d_mul_err,
                                    DT_FRAC
                                ),
                            DT_FRAC), 
                            i_sca_part'length);

                        -- Pad terms if there's more precision in one
                        -- term than the others
                        -- TODO - integral, derivative term.
                        if P_SCALED_WIDTH /= 0 then
                            p_scaled <= p_mul &
                                    (P_SCALED_WIDTH - 1 downto 0 => '0');
                        else
                            p_scaled <= p_mul;
                        end if;

                        state        <= STAGE_4;

                    when STAGE_4     =>
                        -- Accumulate integral parts.
                        if (i_scaled + i_sca_part) >
                            resize(
                                max_i_term, i_scaled'length
                            )
                        then
                            i_scaled <= resize(
                                max_i_term, i_scaled'length
                            );

                        elsif (i_scaled + i_sca_part) <
                            resize(
                                -max_i_term, i_scaled'length
                            )
                        then
                            i_scaled <= resize(
                                -max_i_term, i_scaled'length
                            );

                        else
                            i_scaled <= i_scaled + i_sca_part;
                        end if;

                        state        <= STAGE_5;

                    when STAGE_5 => 
                        sum_scaled <= resize(
                            (
                                p_scaled +
                                v_scaled +
                                i_scaled +
                                d_scaled +
                                ff_scaled
                            ), sum_scaled'length
                        );
                        state      <= STAGE_6;
                    
                    when STAGE_6 => 
                        -- Check the sign of the sum and round
                        -- appropriately.
                        if sum_scaled >= 0 then
                            sum_int <= resize(
                                shift_right(
                                    sum_scaled + 
                                    shift_right(
                                        sum_scaled,
                                        DT_FRAC
                                    ),
                                    DT_FRAC
                                ),
                                sum_int'length
                            );
                        else
                            -- Avoids negative values rounding
                            -- towards -inf instead of 0.
                            sum_int <= resize(
                                shift_right(
                                    sum_scaled - 
                                    shift_right(
                                        sum_scaled,
                                        DT_FRAC
                                    ),
                                    DT_FRAC
                                ),
                                sum_int'length
                            );
                        end if;
                        state    <= DONE;

                    when DONE => 
                        -- Output value and clean-up
                        if sum_int > resize(
                            signed(max_output_i), sum_int'length
                        ) then
                            round_out <= resize(
                                signed(max_output_i), round_out'length
                            );
                        elsif sum_int < resize(
                            -signed(max_output_i), sum_int'length
                        ) then
                            round_out <= resize(
                                -signed(max_output_i), round_out'length
                            );
                        else
                            -- Toggle Direction
                            if dir_toggle_i(0) = '1' then
                                round_out <= resize(
                                    -sum_int, round_out'length
                                );
                            else
                                round_out <= resize(
                                    sum_int, round_out'length
                                );
                            end if;
                        end if;

                        state   <= IDLE;
                        do_work <= '0';

                    when others =>
                        state   <= IDLE;
                        do_work <= '0';

                end case;
            end if;
        end if;  -- Clock
    end process; -- Main logic

end no_pipeline;