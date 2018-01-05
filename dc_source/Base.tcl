######################################################################
# A simple dc_source role

package require Itcl
package require Device

namespace eval device_role::dc_source {

  ## Interface class. All power_supply driver classes are children of it
  itcl::class interface {
    inherit device_role::base_interface

    # variables which should be filled by driver:
    public variable max_v; # max voltage
    public variable min_v; # min voltage
    public variable min_v_step; # min step in voltage

    # methods which should be defined by driver:
    method set_volt      {val} {}; # set voltage and all output settings
    method set_volt_fast {val} {}; # set voltage without touching other settings
    method get_volt {} {};    # measure actual voltage value
  }
}
