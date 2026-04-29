--------------------------------------------------------------------------------
--  File:   pid_tb.vhd
--  Desc:   Testbed for generic PID controller on PandA.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Custom packages
use work.global_constants.all;
use work.global_enums.all;
use work.global_subtypes.all;

entity pid_tb is  end;

architecture rtl of pid_tb is
    signal clk_i          : std_logic := '0';
    signal init_i         : std_logic := '0';

    signal pid_period_i   : panda_port;

    signal kp_i           : panda_port;
    signal ki_i           : panda_port;
    signal kd_i           : panda_port;

    signal do_vel_diff_i  : panda_port;
    signal dir_toggle_i   : panda_port;
    signal dt_i           : panda_port;
    signal dt_inv_i       : panda_port;
    signal max_integral_i : panda_port;
    signal max_output_i   : panda_port;

    signal real_input_i   : panda_port;
    signal setpoint_i     : panda_port;

    signal real_output_o  : panda_port;

    -- Testbench only
    signal done           : boolean  := false;
    constant p_clk_period : time     := 8 ns; 


begin

    clkgen : process
    begin
        while not done loop
            clk_i <= not clk_i;
            wait for p_clk_period / 2;
        end loop;
        wait;
    end process;


process
begin
    -- Initial input values
    init_i         <= '1';
    pid_period_i   <= std_logic_vector(to_signed(3, pid_period_i'length));
    kp_i           <= "0" & "0000000000" & "000000000000000000000";
    ki_i           <= "0" & "0000000000" & "000000000000000000000";
    kd_i           <= "0" & "0000000001" & "000000000000000000000";
    do_vel_diff_i  <= std_logic_vector(to_unsigned(0, do_vel_diff_i'length));
    dir_toggle_i   <= std_logic_vector(to_signed(0, dir_toggle_i'length));
    dt_i           <= "0" & "0000000001" & "000000000000000000000";
    dt_inv_i       <= "0" & "0000000111" & "000000000000000000000";
    max_integral_i <= std_logic_vector(to_signed(200000, max_integral_i'length));
    max_output_i   <= std_logic_vector(to_signed(200000, max_output_i'length));
    real_input_i   <= std_logic_vector(to_signed(0, real_input_i'length));
    setpoint_i     <= std_logic_vector(to_signed(-100, setpoint_i'length));

    -- Begin waiting 
    wait until rising_edge(clk_i);
    init_i         <= '0';
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);

    for i in 0 to 30 loop
        wait until rising_edge(clk_i);
        -- do something each cycle
    end loop;

    done <= true; -- stops the clk

    wait;
end process;

UUT: entity work.pid
    port map (
        clk_i,
        init_i,

        pid_period_i,

        kp_i,
        ki_i,
        kd_i,

        do_vel_diff_i,
        dir_toggle_i,
        dt_i,
        dt_inv_i,
        max_integral_i,
        max_output_i,

        real_input_i,
        setpoint_i,

        real_output_o
    );


end architecture rtl;