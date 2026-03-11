SHELL := /bin/bash

VIVADO_BATCH = bash -c 'source ./setup_env.sh && vivado -mode batch -log vivado.log -journal vivado.jou -source scripts/vivado/main.tcl -tclargs'
VIVADO_GUI   = bash -c 'source ./setup_env.sh && vivado'

# Determine projects by unqiue folders in src/, sort alphabetically
PROJECTS := $(sort $(patsubst src/%,%,$(wildcard src/*/)))

# Set the testbench as the top file
$(foreach proj,$(PROJECTS),$(eval $(proj)_TOP = $(proj)_tb))

# Generic targets
.PHONY: $(PROJECTS) $(addsuffix _gui,$(PROJECTS)) $(addsuffix _open,$(PROJECTS)) $(addsuffix _clean,$(PROJECTS))

# Base args for each project
PART ?= xc7z030sbg485-1
VERBOSE ?= false
CLEAN ?= false

BASE_ARGS = -proj_name $(*) -top_module $(*_TOP) -part $(PART)

# TODO - figure out args formatting
$(PROJECTS):
	@echo "Building $@..."
	$(VIVADO_BATCH) $(BASE_ARGS) -v $(VERBOSE) -c $(CLEAN)

%_gui:
	$(eval PROJ := $(*)) $(eval TOP := $(PROJ)_TOP)
	$(VIVADO_BATCH) $(BASE_ARGS) -proj_name $(PROJ) -top_module $(TOP) -v $(VERBOSE) -c true && \
	vivado build/vivado/$(PROJ)/$(PROJ).xpr &

%_open:
	$(VIVADO_GUI) build/vivado/$(*)/$(*).xpr &

%_clean:
	rm -rf build/vivado/$(*)
