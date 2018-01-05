######################################################################
# A gauge role

package require Itcl
package require Device

namespace eval device_role::gauge {

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
