######################################################################
# Usage:
#
#   set dev [DeviceRole ps0:1L power_supply]
#   $dev set_curr 0.1
#
# This means "use channel 1L of Device ps0 as a power_supply".
# power_supply commands can be founs in ./power_supply.tcl file.
# Channel can be sat for some devices, see power_supply/*.tcl

package require Itcl

namespace eval device_role {}

proc DeviceRole {name role} {
  ## parse device name:
  set chan {}
  if {[regexp {^([^:]*):(.*)} $name x n c]} {
    set name $n
    set chan $c
  }\

  return [device_role::${role}::create $name $chan]
}


## Base interface class. All role interfaces are children of it
itcl::class device_role::base_interface {
  proc id_regex {} {}; ## return regexp for *IDN? response used to detect device model
  variable dev; ## Device handler (see Device library)

  # Drivers should provide constructor with "device" and "channel" parameters
  constructor {} {}
  destructor {itcl::delete object $dev}

  method lock {} {$dev lock}
  method unlock {} {$dev unlock}
  method set_logfile {f} {$dev set_logfile $f}
}
