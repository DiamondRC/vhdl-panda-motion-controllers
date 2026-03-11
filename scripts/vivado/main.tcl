proc main {args} {
    # Parse user args
    array set options { 
        part xc7z030sbg485-1 
        proj_name "" 
        top_module "" 
        v false 
        c false 
    }

    # Strip input arguments and prepare them as build options
    set i 0
    while {$i < [llength $args]} {
        set arg [lindex $args $i]
        if {[string match "-*" $arg]} {
            set key [string range $arg 1 end]
            incr i
            if {$i < [llength $args]} {
                set options($key) [lindex $args $i]
                incr i
            } else {
                puts "WARNING: Missing value for $arg, using default"
            }
        } else {
            incr i
        }
    }

    # Check mandatory user args
    if {$options(proj_name) eq ""} {
         error "Usage: source main.tcl -proj_name <name> [-part <part_id>] [-top_module <name>] [-v <bool>] [-c <bool>]"
    }

    # Defensive auto-gen of top file if not specified
    if {$options(top_module) eq ""} {
        set options(top_module) "${options(proj_name)}_tb"
        puts "INFO: Using default top_module: $options(top_module)"
    }

    # Setup relative paths
    set script_dir [file dirname [file normalize [info script]]]
    set repo_root  [file normalize [file join $script_dir ".." ".."]]
    set proj_dir [file join $repo_root "build/vivado/${options(proj_name)}"]
    set src_dir [file join $repo_root "src/${options(proj_name)}"]
    set tb_dir [file join $repo_root "tb/${options(proj_name)}"]
    set common_dir [file join $repo_root "src/common"]

    # Silence vivado log creation if not verbose
    if {$options(v)} {
        set_param general.maxThreads 8
        set_param simulator. elaboration.checktopmodule 0
    }

    # Optional clean build
    if {$options(c)} {
        file delete -force $proj_dir
        file mkdir $proj_dir
    }

    # Create/open the project
    if {[llength [get_projects]] == 0 || [get_projects] ne $options(proj_name)} {
        create_project -force $options(proj_name) $proj_dir -part $options(part)
    }

    # Disable gui auto project file hierarchy
    set_property source_mgmt_mode None [current_project]

    # Add project VHD files
    foreach file [glob -nocomplain [file join $src_dir "*.vhd"]] {
        add_files -norecurse [list $file]
        set_property library work [get_files $file]
    }

    # Add any common sources
    foreach file [glob -nocomplain [file join $common_dir "*.vhd"]] {
        add_files -norecurse [list $file]
        set_property library work [get_files $file]
    }

    # Setup simulation and add test benches
    set sim_fileset [get_filesets sim_1]
    foreach file [glob -nocomplain [file join $tb_dir "*.vhd"]] {
        add_files -norecurse [list $file] -fileset $sim_fileset
        set_property library work [get_files $file]
    }

    # Try to force top module if specified
    set_property top $options(top_module) $sim_fileset
    update_compile_order -fileset $sim_fileset
    puts "Simulation top set to: [get_property TOP [get_filesets sim_1]]"

    # Launch GUI
    update_compile_order -fileset sources_1
    launch_simulation -mode behavioral -scripts_only
    puts "Project created: $proj_dir/$options(proj_name).xpr"
}

# Main entry point
main {*}$::argv