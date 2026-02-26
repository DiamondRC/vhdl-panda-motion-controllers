# Create relative paths
set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir ".." ".."]]
set proj_dir [file join $repo_root "build/vivado/pid_basic"]

# Create build dir
file delete -force $proj_dir
file mkdir $proj_dir

# Create project
create_project -force pid_basic $proj_dir -part xc7z030sbg485-1

set_property source_mgmt_mode None [current_project]

# Add project sources
set pid_files [glob -nocomplain [file join $repo_root "src/pid/basic/*.vhd"]]
foreach file $pid_files {
    add_files -norecurse [list $file]
    set_property library work [get_files $file]
}

# Add any common sources
set common_files [glob -nocomplain [file join $repo_root "src/common/*.vhd"]]
foreach file $common_files {
    add_files -norecurse [list $file]
    set_property library work [get_files $file]
}

# Add test benches
set tb_files [glob -nocomplain [file join $repo_root "tb/pid/basic/*.vhd"]]
set sim_fileset [get_filesets sim_1]
foreach file $tb_files {
    add_files -norecurse [list $file] -fileset $sim_fileset
    set_property library work [get_files $file]
}

# Force top module
set_property top pid_td $sim_fileset
update_compile_order -fileset $sim_fileset

# Verify in script
puts "Simulation top set to: [get_property TOP [get_filesets sim_1]]"

# Final setup
set_property source_mgmt_mode None [current_project]
update_compile_order -fileset sources_1

# Launch GUI
launch_simulation -mode behavioral -scripts_only

puts "Project created: $proj_dir/pid_basic.xpr"

# close_project