######################################################################
# A noise_source role

package require Itcl
package require Device

namespace eval device_role::noise_source {

  ## Detect device model, create and return driver object for it
  proc create {name chan} {
    # Create device if needed, ask for ID.
    # Many drivers can use a single device (different channels, different roles)
    if {[info commands $name]=={}} { Device $name }
    set ID [$name cmd *IDN?]

    set n [namespace current]
    set driver {}
    foreach m {keysight_2ch keysight_33511B} {
      set re [${n}::${m}::id_regexp]
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

    # methods which should be defined by driver:
    method set_noise      {bw volt {offs 0}} {}; # reconfigure the output, set bandwidth, voltage and offset
    method set_noise_fast {bw volt {offs 0}} {}; # set bandwidth, voltage and offset
    method get_volt  {} {};    # get voltage value
    method get_bw    {} {};    # get bandwidth value
    method get_offs  {} {};    # get bandwidth value
    method off       {} {};    # turn off the signal
  }
}
