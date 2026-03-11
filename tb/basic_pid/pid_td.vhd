--------------------------------------------------------------------------------
--  File:       pid_tb.vhd
--  Desc:       Testbench for Standalone PID.vhd
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

entity pid_tb is  end;

architecture rtl of pid_tb is

signal   clk_i      : std_logic := '0';
signal   init_i    : std_logic := '0';

signal   pid_period_i   : std_logic_vector(31 downto 0);

signal   kp_i   : std_logic_vector(31 downto 0);
signal   ki_i   : std_logic_vector(31 downto 0);
signal   kd_i   : std_logic_vector(31 downto 0);
signal   kff_i  : std_logic_vector(31 downto 0);
signal   dir_toggle_i : std_logic_vector(31 downto 0);

signal   dt_i : std_logic_vector(31 downto 0);
signal   dt_inverse_i : std_logic_vector(31 downto 0);
signal   use_vel_der_i : std_logic_vector(31 downto 0);

signal   max_integral_i : std_logic_vector(31 downto 0);
signal   max_output_i : std_logic_vector(31 downto 0);
signal   max_following_err_i : std_logic_vector(31 downto 0);

signal   real_input_i : std_logic_vector(31 downto 0); -- Measured value
signal   setpoint_i : std_logic_vector(31 downto 0); -- Desired value
signal   position_out_o : std_logic_vector(31 downto 0); -- Output value

signal   err_full_o : std_logic_vector(31 downto 0);
signal   err_prev_o : std_logic_vector(31 downto 0);
signal   err_diff_o : std_logic_vector(31 downto 0);


signal   done       : boolean   := false;
constant period     : time      := 8 ns; -- 125 MHz clk

begin

clkgen : process
begin
    while not done loop
        clk_i <= not clk_i;
        wait for period/2;
    end loop;
    wait;
end process;


process
begin
    init_i <= '0';
    pid_period_i <= std_logic_vector(to_signed(10, pid_period_i'length));
    max_following_err_i <= std_logic_vector(to_signed(1000000, pid_period_i'length));
    use_vel_der_i <= std_logic_vector(to_signed(0, pid_period_i'length));
    -- pid_period_i <= std_logic_vector(to_signed(10, pid_period_i'length));
    dt_i <= "0000000000" & "0000000000000000001010";
    dt_inverse_i <= "0000000000" & "0000110000110101000000";
    -- dt_inverse_i <= std_logic_vector(to_signed(100, pid_period_i'length));

    kp_i <= std_logic_vector(to_signed(129635, kp_i'length)); --16384 = 1, 1638.4 = 0.1
    -- kp_i <= std_logic_vector(to_signed(0, kp_i'length));
    -- kp_i <= "00000000000000" & "000000000000100110";
    -- ki_i <= std_logic_vector(to_signed(31457280, ki_i'length)); -- 15
    ki_i <= std_logic_vector(to_signed(0, ki_i'length)); -- 129635 = 7.9123
    kd_i <= std_logic_vector(to_signed(0, kd_i'length));
    -- kd_i <= "0" & "0000000000" & "001100110011001100110";
    kff_i <= std_logic_vector(to_signed(0, kd_i'length));

    dir_toggle_i <= std_logic_vector(to_signed(0, dir_toggle_i'length));

    max_integral_i <= std_logic_vector(to_signed(200000, max_integral_i'length));
    max_output_i <= std_logic_vector(to_signed(200000, max_output_i'length));

    setpoint_i  <= std_logic_vector(to_signed(0, setpoint_i'length));
    real_input_i <= std_logic_vector(to_signed(0, real_input_i'length));
    --
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    setpoint_i  <= std_logic_vector(to_signed(10, setpoint_i'length));
    real_input_i <= std_logic_vector(to_signed(0, real_input_i'length));
    --
    wait until rising_edge(clk_i);
    setpoint_i  <= std_logic_vector(to_signed(100, setpoint_i'length));
    real_input_i <= std_logic_vector(to_signed(0, real_input_i'length));
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    setpoint_i  <= std_logic_vector(to_signed(1000, setpoint_i'length));
    real_input_i <= std_logic_vector(to_signed(0, real_input_i'length));
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    setpoint_i  <= std_logic_vector(to_signed(10000, setpoint_i'length));
    real_input_i <= std_logic_vector(to_signed(0, real_input_i'length));
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    setpoint_i  <= std_logic_vector(to_signed(1000, setpoint_i'length));
    real_input_i <= std_logic_vector(to_signed(0, real_input_i'length));
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    setpoint_i  <= std_logic_vector(to_signed(100, setpoint_i'length));
    real_input_i <= std_logic_vector(to_signed(0, real_input_i'length));
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    setpoint_i  <= std_logic_vector(to_signed(10, setpoint_i'length));
    real_input_i <= std_logic_vector(to_signed(0, real_input_i'length));
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    -- real_input_i <= std_logic_vector(to_signed(800, real_input_i'length));
    -- ki_shift_i <= std_logic_vector(to_signed(18, dir_toggle_i'length));
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- real_input_i <= std_logic_vector(to_signed(900, real_input_i'length));
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- real_input_i <= std_logic_vector(to_signed(1000, real_input_i'length));
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- real_input_i <= std_logic_vector(to_signed(1100, real_input_i'length));
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- real_input_i <= std_logic_vector(to_signed(1200, real_input_i'length));
    -- --
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- real_input_i <= std_logic_vector(to_signed(1100, real_input_i'length));
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- real_input_i <= std_logic_vector(to_signed(1000, real_input_i'length));
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- real_input_i <= std_logic_vector(to_signed(900, real_input_i'length));
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- real_input_i <= std_logic_vector(to_signed(800, real_input_i'length));
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- real_input_i <= std_logic_vector(to_signed(900, real_input_i'length));
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- real_input_i <= std_logic_vector(to_signed(1000, real_input_i'length));
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- --
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);
    -- wait until rising_edge(clk_i);

    done <= true; -- stops the clk

    wait;
end process;

UUT: entity work.pid
    port map (clk_i, init_i, pid_period_i, kp_i, ki_i, kd_i, kff_i, dir_toggle_i, dt_i, dt_inverse_i, use_vel_der_i, max_integral_i, max_output_i, max_following_err_i, real_input_i, setpoint_i, position_out_o, err_full_o, err_prev_o, err_diff_o);


end architecture rtl;
