######################################################################
# A simple voltage_supply role

package require Itcl
package require Device

namespace eval device_role::voltage_supply {

  ## Detect device model, create and return driver object for it
  proc create {name chan} {
    # Create device if needed, ask for ID.
    # Many drivers can use a single device (different channels, different roles)
    if {[info commands $name]=={}} { Device $name }
    set ID [$name cmd *IDN?]

    set n [namespace current]
    set driver {}
    foreach m {tenma_72-2550 sr844 keysight_33510B keysight_33511B} {
      set re [set ${n}::${m}::id_regexp]
      if {[regexp $re $ID]} {
        return ${n}::[$m #auto ${n}::${name} $chan]
      }
    }
    error "Do not know how to use device as a $n: $ID"
  }


  ## Interface class. All power_supply driver classes are children of it
  itcl::class interface {
    inherit device_role::base_interface

    # variables which should be filled by driver:
    public variable max_v; # max voltage
    public variable min_v; # min voltage
    public variable min_v_step; # min step in voltage

    # Drivers should provide constructor with "device" and "channel" parameters
    constructor {} {}
    # methods which should be defined by driver:
    method set_volt {val} {}; # set maximum voltage
    method get_volt {} {};    # measure actual value of current
  }
}
