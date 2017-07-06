######################################################################
# A gauge role

package require Itcl
package require Device

namespace eval device_role::gauge {

  ## Detect device model, create and return driver object for it
  proc create {name chan} {
    # Create device if needed, ask for ID.
    # Many drivers can use a single device (different channels, different roles)
    if {[info commands $name]=={}} { Device $name }
    set ID [$name cmd *IDN?]

    set n [namespace current]
    set driver {}
    foreach m {sr844 keysight_34461A} {
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

    # methods which should be defined by driver:
    method get {} {}; # do the measurement, return one or more numbers

    method get_auto {} {}; # set the range automatically, do the measurement

    method list_ranges  {} {}; # get list of possible range settings
    method list_tconsts {} {}; # get list of possible time constant settings

    method set_range  {val} {}; # set the range
    method set_tconst {val} {}; # set the time constant
    method get_range  {} {}; # get current range setting
    method get_tconst {} {}; # get current time constant setting

  }
}
