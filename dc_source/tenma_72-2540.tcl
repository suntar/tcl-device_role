# ID string:
#   TENMA72-2540V2.0

package require Itcl

itcl::class device_role::dc_source::tenma_72-2540 {
  inherit device_role::dc_source::tenma_base

  proc id_regexp {} {return {^TENMA72-2540V2.0}}

  constructor {d ch} {
    device_role::dc_source::tenma_base::constructor $d $ch
  } {
    set max_i 5.09
    set max_v 31.0
  }
}
