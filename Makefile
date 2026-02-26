SHELL := /bin/bash

VIVADO := bash -c 'source ./setup_env.sh && vivado -mode batch -log vivado.log -journal vivado.jou -source "scripts/vivado/pid_basic.tcl"'

.PHONY: pid_basic pid_basic_clean pid_basic_synth

pid_basic:
	$(VIVADO)

pid_basic_gui:
	$(VIVADO) && bash -c 'source ./setup_env.sh && vivado build/vivado/pid_basic/pid_basic.xpr &'

pid_basic_open:
	vivado build/vivado/pid_basic/pid_basic.xpr &

pid_basic_synth:
	sed -i 's/# *launch_runs/launch_runs/' scripts/vivado/pid_basic.tcl
	$(MAKE) pid_basic
	sed -i 's/launch_runs/# launch_runs/' scripts/vivado/pid_basic.tcl 

pid_basic_sim_gui:
	source ./setup_env.sh && vivado -mode batch -source "scripts/vivado/pid_basic.tcl" && \
	vivado build/vivado/pid_basic/pid_basic.xpr &

pid_basic_clean:
	rm -rf build/vivado/pid_basic