# Tcl package index file
# This file is NOT generated by the "pkg_mkIndex" command 

set _name    DeviceRole
set _version 1.2

set _files {}
lappend _files "$dir/role.tcl"
lappend _files "$dir/noise_source.tcl"
lappend _files "$dir/ac_source.tcl"
lappend _files "$dir/dc_source.tcl"
lappend _files "$dir/pulse_source.tcl"
lappend _files "$dir/power_supply.tcl"
lappend _files "$dir/gauge.tcl"

set _pcmd {}
foreach _f $_files { lappend _pcmd "source $_f" }
lappend _pcmd "package provide $_name $_version"
package ifneeded $_name $_version [join $_pcmd \n]

