--------------------------------------------------------------------------------
--  File:   brett_pid_ff.vhd
--  Desc:   Attempt implementation matching Brett's PID controller for PandA.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Custom packages
use work.global_constants.all;
use work.global_enums.all;
use work.global_subtypes.all;
use work.fp_utils.all;

entity brett_pid is
    port (
        clk_i          : in std_logic;
        init_i         : in std_logic;

        pid_period_i   : in panda_port  := (others => '0');

        k_tot_i        : in panda_port  := (others => '0');
        kp_i           : in panda_port  := (others => '0');
        kv_i           : in panda_port  := (others => '0');
        ki_i           : in panda_port  := (others => '0');
        kd_i           : in panda_port  := (others => '0');
        kvff_i         : in panda_port  := (others => '0');
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
    signal v_mul      : signed(V_MUL_SIZE - 1 downto 0)
        := (others => '0');
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
    signal v_des_mul  : signed(V_DES_MUL_SIZE - 1 downto 0)
        := (others => '0');
    signal v_des_sca  : signed(V_DES_SCA_SIZE - 1 downto 0)
        := (others => '0');
    signal a_des_sub  : signed(A_DES_SUB_SIZE - 1 downto 0)
        := (others => '0');
    signal a_des_mul  : signed(A_DES_MUL_SIZE - 1 downto 0)
        := (others => '0');
    signal a_des_sca  : signed(A_DES_SCA_SIZE - 1 downto 0)
        := (others => '0');
    signal p1_des_mul : signed(P1_DES_MUL_SIZE - 1 downto 0)
        := (others => '0');
    signal p1_des_sca : signed(P1_DES_SCA_SIZE - 1 downto 0)
        := (others => '0');
    signal p0_des_abs : signed(P0_DES_ABS_SIZE - 1 downto 0)
        := (others => '0');
    signal p0_des_mul : signed(P0_DES_MUL_SIZE - 1 downto 0)
        := (others => '0');
    signal p0_des_sca : signed(P0_DES_SCA_SIZE - 1 downto 0)
        := (others => '0');

    -- Sum term
    signal sum_scaled : signed(SUM_SCALED_SIZE - 1 downto 0)
        := (others => '0');
    signal sum_int    : signed(SUM_INT_SIZE - 1 downto 0)   
        := (others => '0');

    -- PID clock
    -- 625 is ~200kHz
    signal clk_count  : unsigned(PANDA_PORT_SIZE - 1 downto 0)
        := (others => '0');
    signal trigger    : std_logic
        := '0';

    -- Error
    signal prev_err   : signed(POS_ERR_SIZE - 1 downto 0);

    -- Master Clock
    signal pm_mul     : signed(PM_MUL_SIZE - 1 downto 0)
        := (others => '0');
    signal ri_nm      : signed(RI_NM_SIZE - 1 downto 0)
        := (others => '0');

    -- Misc
    signal v_des_cal  : signed(V_DES_CAL_SIZE - 1 downto 0)
        := (others => '0');
    signal prev_v_des : signed(V_DES_CAL_SIZE - 1 downto 0)
        := (others => '0');
    signal prev_set   : signed(RI_NM_SIZE - 1 downto 0)
        := (others => '0');
    signal d_err      : signed(D_ERR_SIZE - 1 downto 0)
        := (others => '0');
    signal round_out  : signed(PANDA_PORT_SIZE - 1 downto 0)
        := (others => '0');
    signal sca_mul    : signed(SCALE_MUL_SIZE - 1 downto 0)
        := (others => '0');
    signal scale_out  : signed(SCALE_OUT_SIZE - 1 downto 0)
        := (others => '0');
    signal max_out    : signed(MAX_OUT_SIZE - 1 downto 0)
        := (others => '0');
    signal prev_pos   : signed(RI_NM_SIZE - 1 downto 0)
        := (others => '0');
    signal vel        : signed(VEL_SIZE - 1 downto 0)
        := (others => '0');
    signal pos_err    : signed(POS_ERR_SIZE - 1 downto 0)
        := (others => '0');
    signal max_i_term : signed(MAX_I_SIZE - 1 downto 0)
        := (others => '0');
    signal pos_store  : signed(RI_NM_SIZE - 1 downto 0)
        := (others => '0');
    signal set_store  : signed(RI_NM_SIZE - 1 downto 0)
        := (others => '0');
    signal do_work    : std_logic
        := '0';
    signal state      : pid_state
        := INITIAL;


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
            -- Encoders read in units of 256pm.
            -- Must convert into units of 1nm.
            -- => multiply by * 256/1000 = 0.256.
            pm_mul <= resize(
                (signed(real_input_i) * PV_SCALE),
                pm_mul'length
            );

            -- Round result
            ri_nm <= round_sym(
                pm_mul, PM_SCA_FRAC, ri_nm'length
            );

            if init_i = '1' then
                -- Error
                pos_err       <= (others => '0');
                prev_err      <= (others => '0');
                d_err         <= (others => '0');

                -- Velocity
                prev_pos      <= (others => '0');
                prev_v_des    <= (others => '0');
                vel           <= (others => '0');
                v_des_cal     <= (others => '0');

                -- P term
                p_mul         <= (others => '0');
                p_scaled      <= (others => '0');

                -- V term
                v_mul         <= (others => '0');
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
                v_des_mul     <= (others => '0');
                v_des_sca     <= (others => '0');
                a_des_sub     <= (others => '0');
                a_des_mul     <= (others => '0');
                a_des_sca     <= (others => '0');
                p1_des_mul    <= (others => '0');
                p1_des_sca    <= (others => '0');
                p0_des_abs    <= (others => '0');
                p0_des_mul    <= (others => '0');
                p0_des_sca    <= (others => '0');

                -- Sum
                sum_scaled    <= (others => '0');
                sum_int       <= (others => '0');

                -- Misc
                prev_set      <= (others => '0');
                max_i_term    <= (others => '0');
                round_out     <= (others => '0');
                scale_out     <= (others => '0');
                max_out       <= (others => '0');

                real_output_o <= (others => '0');
                do_work       <= '0';

            elsif trigger = '1' then
                -- Start logic next master clock
                do_work <= '1';

                -- Calculate the position error
                pos_err <= pad_signed(
                    signed(setpoint_i), DES_FRAC, pos_err'length
                ) - ri_nm;

                -- Store instantaneous inputs for later usage
                pos_store <= ri_nm;
                set_store <= pad_signed(
                    signed(setpoint_i), DES_FRAC, set_store'length
                );

                -- Update previous values
                prev_pos  <= pos_store;
                prev_set  <= set_store;
                prev_err  <= pos_err;

            elsif do_work = '1' then
                -- Do work
                case state is
                    when INITIAL   =>
                        -- Measure Velocity
                        vel        <= (
                            pos_store - prev_pos
                        ) * resize(signed(dt_inv_i), DT_I_SIZE);

                        -- Calculate desired velocity
                        v_des_cal  <= (
                            set_store - prev_set
                        ) * resize(signed(dt_inv_i), DT_I_SIZE);
                        -- ) * to_signed(1*(2**DT_I_FRAC), DT_I_SIZE);

                        -- Main terms
                        p_mul      <= resize(signed(kp_i), KP_I_SIZE) *
                                      pos_err;

                        i_mul_dt   <= resize(signed(ki_i), KI_I_SIZE) *
                                      resize(signed(dt_i), DT_SIZE);

                        d_mul_dt   <= resize(signed(kd_i), KD_I_SIZE) * 
                                      resize(signed(dt_inv_i), DT_I_SIZE);

                        -- FF terms
                        p1_des_mul <= resize(signed(kpff1_i), KP1FF_I_SIZE) * 
                                      set_store;

                        p0_des_abs <= resize(signed(kpff0_i), KP0FF_I_SIZE) * 
                                      abs(set_store);

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

                    when STAGE_2   => 
                        v_mul      <= (
                            resize(signed(kv_i), KV_I_SIZE) * vel
                        );

                        i_mul_err  <= pos_err * i_mul_dt;

                        d_mul_err  <= d_mul_dt * d_err;

                        v_des_mul  <= resize(signed(kvff_i), KVFF_I_SIZE) * 
                                      v_des_cal;

                        a_des_sub  <= v_des_cal - prev_v_des;
                        
                        p0_des_mul <= p0_des_abs * set_store;

                        -- store last desired velocity
                        -- need to wait tick until calculated
                        prev_v_des <= v_des_cal;

                        state      <= STAGE_3;
                    
                    when STAGE_3     =>
                        a_des_mul    <= resize(signed(kaff_i), KAFF_I_SIZE) * 
                                      a_des_sub;

                        -- Scale terms to consistent precision
                        -- with symmetric rounding.
                        p_scaled <= round_sym(
                            p_mul, P_SCA_FRAC, p_scaled'length
                        );
                        v_scaled     <= -round_sym( -- V is -ve in sum
                            v_mul, V_SCA_FRAC, v_scaled'length
                        );
                        i_sca_part   <= round_sym(
                            i_mul_err, I_SCA_FRAC, i_sca_part'length
                        );
                        d_scaled     <= round_sym(
                            d_mul_err, D_SCA_FRAC, d_scaled'length
                        );
                        v_des_sca    <= round_sym(
                            v_des_mul, V_FF_SCA_FRAC, v_des_sca'length
                        );

                        p1_des_sca <= round_sym(
                            p1_des_mul, P1_DES_SCA_FRAC, p1_des_sca'length
                        );

                        p0_des_sca <= round_sym(
                            p0_des_mul, P0_DES_SCA_FRAC, p0_des_sca'length
                        );

                        state        <= STAGE_4;

                    when STAGE_4     =>
                        -- if sum_int < max_out and v_des /= 0 then
                        if sum_int < resize(
                            signed(max_output_i), sum_int'length
                        ) and (
                            v_des_cal /= to_signed(0, V_DES_CAL_SIZE)
                        )
                        then
                            i_scaled <= i_scaled +
                            resize(i_sca_part, I_SCALED_SIZE);
                        end if;

                        -- Scale integral limit to fixed point
                        -- Always positive.
                        max_i_term   <= shift_left(
                            resize(
                                signed(max_integral_i),
                                max_i_term'length
                            ),
                            MAX_FRAC
                        );

                        state        <= STAGE_5;

                    when STAGE_5     =>
                        -- if sum_int < max_out and v_des /= 0 then
                        if sum_int < resize(
                            signed(max_output_i), sum_int'length
                        ) and (
                            v_des_cal /= to_signed(0, V_DES_CAL_SIZE)
                        ) then
                            if i_scaled > resize(
                                max_i_term, i_scaled'length
                            ) then
                                i_scaled <= resize(
                                    max_i_term, i_scaled'length
                                );
                            end if;

                            if i_scaled < resize(
                                -max_i_term, i_scaled'length
                            ) then
                                i_scaled <= resize(
                                    -max_i_term, i_scaled'length
                                );
                            end if;
                        end if;

                        a_des_sca <= round_sym(
                            a_des_mul, A_SCA_FRAC, a_des_sca'length
                        );

                        state        <= STAGE_6;

                    when STAGE_6 => 
                        sum_scaled <= resize(
                            (
                                p_scaled +
                                v_scaled +
                                i_scaled +
                                d_scaled +
                                v_des_sca +
                                a_des_sca +
                                p1_des_sca +
                                p0_des_sca
                            ), sum_scaled'length
                        );
                        state      <= STAGE_7;

                    when STAGE_7    => 
                        sum_int <= round_sym(
                            sum_scaled, MAX_FRAC, sum_int'length
                        );

                        state       <= STAGE_8;

                    when STAGE_8  =>
                        sca_mul   <= resize(signed(k_tot_i), K_TOT_I_SIZE) *
                                     sum_int;

                        state     <= STAGE_9;

                    when STAGE_9  =>
                        -- Will over/underflow, no clamp
                        scale_out <= round_sym(
                            sca_mul, SCA_OUT_SCA_FRAC, scale_out'length
                        );

                        state     <= DONE;

                    when DONE => 
                        -- Output value and clean-up
                        -- if scale_out > resize(
                        --     signed(max_output_i), scale_out'length
                        -- ) then
                        --     round_out <= resize(
                        --         signed(max_output_i), round_out'length
                        --     );
                        -- elsif scale_out < resize(
                        --     -signed(max_output_i), scale_out'length
                        -- ) then
                        --     round_out <= resize(
                        --         -signed(max_output_i), round_out'length
                        --     );
                        -- else
                        --     -- Toggle Direction
                        --     if dir_toggle_i(0) = '1' then
                        --         round_out <= resize(
                        --             -scale_out, round_out'length
                        --         );
                        --     else
                        --         round_out <= resize(
                        --             scale_out, round_out'length
                        --         );
                        --     end if;
                        -- end if;

                        if scale_out > resize(
                            signed(max_output_i), scale_out'length
                        ) then
                            real_output_o <= std_logic_vector(
                                resize(
                                    signed(max_output_i), round_out'length
                                )
                            );
                        elsif scale_out < resize(
                            -signed(max_output_i), scale_out'length
                        ) then
                            real_output_o <= std_logic_vector(
                                resize(
                                    -signed(max_output_i), round_out'length
                                )
                            );
                        else
                            -- Toggle Direction
                            if dir_toggle_i(0) = '1' then
                                real_output_o <= std_logic_vector(
                                    resize(
                                        -scale_out, round_out'length
                                    )
                                );
                            else
                                real_output_o <= std_logic_vector(
                                    resize(
                                        scale_out, round_out'length
                                    )
                                );
                            end if;
                        end if;

                        state   <= INITIAL;
                        do_work <= '0';

                    when others =>
                        state   <= INITIAL;
                        do_work <= '0';

                end case;
            end if;
        end if;  -- Clock
    end process; -- Main logic

end no_pipeline;