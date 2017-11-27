# ID string:
#   KORADKA6003PV2.0

package require Itcl

itcl::class device_role::power_supply::tenma_72-2550 {
  inherit device_role::power_supply::tenma_base

  proc id_regexp {} {return {^KORADKA6003PV2.0}}

  constructor {d ch} {
    device_role::power_supply::tenma_base::constructor $d $ch
  } {
    set max_i 3.09
    set max_v 60.0
  }
}
