set_property -dict {PACKAGE_PIN M4 IOSTANDARD LVCMOS18} [get_ports {reset_i}];
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS18} [get_ports {trig_slo_i}];
set_property -dict {PACKAGE_PIN M3 IOSTANDARD LVCMOS18} [get_ports {trig_fst_i}];
set_property -dict {PACKAGE_PIN D7 IOSTANDARD LVCMOS18} [get_ports {kp_pos_i}];
set_property -dict {PACKAGE_PIN K7 IOSTANDARD LVCMOS18} [get_ports {ki_pos_i}];
set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS18} [get_ports {kd_pos_i}];
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS18} [get_ports {ff_pos_i}];
set_property -dict {PACKAGE_PIN B13 IOSTANDARD LVCMOS18} [get_ports {kp_vel_i}];
set_property -dict {PACKAGE_PIN H13 IOSTANDARD LVCMOS18} [get_ports {ki_vel_i}];
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS18} [get_ports {kd_vel_i}];
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS18} [get_ports {ff_vel_i}];
set_property -dict {PACKAGE_PIN B14 IOSTANDARD LVCMOS18} [get_ports {clock_rate_1}];
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS18} [get_ports {dir_toggle_i}];
set_property -dict {PACKAGE_PIN K14 IOSTANDARD LVCMOS18} [get_ports {real_input_i}];
set_property -dict {PACKAGE_PIN H1 IOSTANDARD LVCMOS18} [get_ports {setpoint_i}];

set_property -dict { PACKAGE_PIN P7 IOSTANDARD LVCMOS18} [get_ports {real_output_o}];

set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS18} [get_ports {clk_i}];
create_clock -period 8 [get_ports clk_i]


set_property IOSTANDARD LVCMOS33 [get_ports -of_objects [get_iobanks 13]];