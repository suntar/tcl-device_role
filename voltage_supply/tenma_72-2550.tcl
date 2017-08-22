# Use Korad/Velleman/Tenma 72-2550 device in a voltage_suply.
# See https://sigrok.org/wiki/Korad_KAxxxxP_series
#
# ID string:
#   KORADKA6003PV2.0
#
# No channels are supported

package require Itcl

itcl::class device_role::voltage_supply::tenma_72-2550 {
  inherit device_role::voltage_supply::interface

  proc id_regexp {} {return {^KORADKA6003PV2.0}}

  constructor {d ch} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set dev $d
    set max_v 60.0
    set min_v 0.0
    set min_v_step 0.01
  }

  method set_volt {val} {
    # set max current
    $dev cmd "ISET1:3.09"
    set val [expr {round($val*100)/100.0}]
    $dev cmd "VSET1:$val"
  }
  method get_volt {} { return [$dev cmd "VOUT1?"] }
}
