# Use Lockin SR844 auxilary outputs as a voltage_suply.
#
# ID string:
#   Stanford_Research_Systems,SR844,s/n50066,ver1.006
#
# Use channels 1 or 2 to set auxilary output

package require Itcl

itcl::class device_role::dc_source::sr844 {
  inherit device_role::dc_source::interface

  variable chan;  # channel to use (1..2)

  proc id_regexp {} {return {,SR844,}}

  constructor {d ch} {
    if {$ch!=1 && $ch!=2} {
      error "$this: bad channel setting: $ch"}
    set chan $ch

    set dev $d
    set max_v +10.5
    set min_v -10.5
    set min_v_step 0.001
  }

  method set_volt {val} {
    $dev cmd "AUXO${chan},$val"
  }
  method set_volt_fast {val} {
    $dev cmd "AUXO${chan},$val"
  }
  method off {} {
    set_volt 0
  }
  method get_volt {} { return [$dev cmd "AUXO?${chan}"] }
}
