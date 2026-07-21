library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Custom packages
use work.global_constants.all;
use work.global_enums.all;
use work.global_subtypes.all;
use work.fp_utils.all;

entity PidMain is
    generic (
        fst_pid   : in  std_logic;
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        kill      : in  std_logic;

        kp        : in  std_logic;
        ki        : in  std_logic;
        kd        : in  std_logic;
        dt        : in  std_logic;
        dt_inv    : in  std_logic;

        pos_store : in  std_logic;
        set_store : in  std_logic;
        pos_err   : in  std_logic;
        prev_pos  : in  std_logic;
        prev_set  : in  std_logic;
        prev_err  : in  std_logic;

        max_itg   : in  std_logic;
        max_out   : in  std_logic;

        pid_out   : out std_logic;
        busy      : out std_logic
    );
end entity PidMain;

architecture Behavioral of PidMain is
    -- 1. Declare your internal signals here!
    signal state : state_type := INITIAL; -- state_type defined in your package
    signal vel   : signed(31 downto 0);
    -- ... declare all other internal registers (p_mul, i_scaled, etc.)
begin
    -- Main logic
    process(clk_i)
    begin
        if reset = '1' then
            state <= INITIAL;
            -- Reset your signals here
        elsif rising_edge(clk) then
            -- Do work
            case state is
                when INITIAL   =>
                    -- Measure Velocity
                    vel        <= (
                        pos_store - prev_pos
                    ) * resize(signed(dt_inv), DT_I_SIZE);
            
                    -- Calculate desired velocity
                    v_des_cal  <= (
                        set_store - prev_set
                    ) * resize(signed(dt_inv), DT_I_SIZE);
            
                    -- Main terms
                    p_mul      <= resize(signed(kp), KP_I_SIZE) *
                                  pos_err;
            
                    i_mul_dt   <= resize(signed(ki), KI_I_SIZE) *
                                  resize(signed(dt), DT_SIZE);
            
                    d_mul_dt   <= resize(signed(kd), KD_I_SIZE) * 
                                  resize(signed(dt_inv), DT_I_SIZE);
            
                    if do_vel_diff_i(0) = '1' then
                        -- Calculate dx...
                        d_err  <= pos_store - prev_pos;
                    else
                        -- ...or calculate de
                        d_err  <= pos_err - prev_err;
                    end if;
                    
                    state      <= STAGE_2;
                    
                when STAGE_2   => 
                    i_mul_err  <= pos_err * i_mul_dt;
                    
                    d_mul_err  <= d_mul_dt * d_err;
                    
                    -- store last desired velocity
                    -- need to wait tick until calculated
                    prev_v_des <= v_des_cal;
                    
                    state      <= STAGE_3;
                    
                when STAGE_3     =>
                    -- Scale terms to consistent precision
                    -- with symmetric rounding.
                    p_scaled     <= round_sym(
                        p_mul, P_SCA_FRAC, p_scaled'length
                    );
                    i_sca_part   <= round_sym(
                        i_mul_err, I_SCA_FRAC, i_sca_part'length
                    );
                    d_scaled     <= round_sym(
                        d_mul_err, D_SCA_FRAC, d_scaled'length
                    );
                    
                    state        <= STAGE_4;
                    
                when STAGE_4     =>
                    -- if sum_int < max_out and v_des /= 0 then
                    if sum_int < resize(
                        signed(max_out), sum_int'length
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
                            signed(max_itg),
                            max_i_term'length
                        ),
                        MAX_FRAC
                    );
                    
                    state        <= STAGE_5;
                    
                when STAGE_5     =>
                    -- if sum_int < max_out and v_des /= 0 then
                    if sum_int < resize(
                        signed(max_out), sum_int'length
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
                        
                    state        <= STAGE_6;
                        
                when STAGE_6 => 
                    sum_scaled <= resize(
                        (
                            p_scaled +
                            i_scaled +
                            d_scaled
                        ), sum_scaled'length
                    );
                    state      <= STAGE_7;
                        
                when STAGE_7    => 
                    sum_int <= round_sym(
                        sum_scaled, MAX_FRAC, sum_int'length
                    );
                        
                    state       <= DONE;
                        
                when DONE => 
                    if sum_int > resize(
                        signed(max_out), sum_int'length
                    ) then
                    
                        if  
                            real_output_o <= std_logic_vector(
                                resize(
                                    signed(max_out), round_out'length
                                )
                            );
                        else
                    
                        end if;
                    
                    
                    elsif sum_int < resize(
                        -signed(max_out), sum_int'length
                    ) then
                        real_output_o <= std_logic_vector(
                            resize(
                                -signed(max_out), round_out'length
                            )
                        );
                    else
                        -- Toggle Direction
                        if dir_toggle_i(0) = '1' then
                            real_output_o <= std_logic_vector(
                                resize(
                                    -sum_int, round_out'length
                                )
                            );
                        else
                            real_output_o <= std_logic_vector(
                                resize(
                                    sum_int, round_out'length
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
        end if;  -- Clock
    end process;

end architecture Behavioral;