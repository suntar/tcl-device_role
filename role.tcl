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
package require Device

namespace eval device_role {}

proc DeviceRole {name role} {
  ## parse device name:
  set chan {}
  if {[regexp {^([^:]*):(.*)} $name x n c]} {
    set name $n
    set chan $c
  }\

  # role namespace
  set n ::device_role::${role}

  # return test device
  if {[string first TEST $name ]!=-1} {
    return [${n}::${name} #auto ${name} $chan]
  }

  # Create device if needed, ask for ID.
  # Many drivers can use a single device (different channels,
  # different roles) and device can be already opened
  # Some reference counter is needed here!
  if {[info commands $name]=={}} { Device $name }
  set ID [$name cmd *IDN?]
  if {$ID == {}} {error "Can't get device id: $name"}

  # Find all classes in the correct namespace.
  # Try to match ID string, return an object of the correct class.
  foreach m [itcl::find classes ${n}::*] {
    set re [${m}::id_regexp]
    if {$re == {}} continue; # skip base classes
    if {[regexp $re $ID]} { return [$m #auto ${name} $chan] }
  }
  error "Do not know how to use device $name as a $n: $ID"
}


## Base interface class. All role interfaces are children of it
itcl::class device_role::base_interface {
  variable dev; ## Device handler (see Device library)

  # Drivers should provide constructor with "device" and "channel" parameters
  constructor {} {}
  destructor { if {[info commands $dev]!={}} { itcl::delete object $dev } }

  method lock {} {$dev lock}
  method unlock {} {$dev unlock}
}
