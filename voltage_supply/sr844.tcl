# Use Lockin SR844 auxilary outputs as a voltage_suply.
#
# ID string:
#   Stanford_Research_Systems,SR844,s/n50066,ver1.006
#
# Use channels 1 or 2 to set auxilary output

package require Itcl

itcl::class device_role::voltage_supply::sr844 {
  inherit device_role::voltage_supply::interface

  variable chan;  # channel to use (1..2)

  common id_regexp {,SR844,}

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
    ## strange! lock-in sets the voltage only if I repeat it twice
    $dev cmd "AUXO${chan},$val"
    $dev cmd "AUXO${chan},$val"
  }
  method get_volt {} { return [$dev cmd "AUXO?${chan}"] }
}
