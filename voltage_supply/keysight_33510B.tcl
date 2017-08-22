# Use generator Keysight 33510B (2 channels) as a voltage_suply.
#
# ID string:
# Agilent
# Technologies,33510B,MY52201807,3.05-1.19-2.00-52-00
#
# Use channels 1 or 2 to set output

package require Itcl

itcl::class device_role::voltage_supply::keysight_33510B {
  inherit device_role::voltage_supply::interface

  variable chan;  # channel to use (1..2)

  proc id_regexp {} {return {,33510B,}}

  constructor {d ch} {
    if {$ch!=1 && $ch!=2} {
      error "$this: bad channel setting: $ch"}
    set chan $ch

    set dev $d
    set max_v 10
    set min_v 0
    set min_v_step 0.001
  }

  method set_volt {val} {
    $dev cmd SOUR${chan}:FUNC DC
    $dev cmd OUTP${chan}:LOAD INF
    $dev cmd SOUR${chan}:VOLT:UNIT VPP
    $dev cmd SOUR${chan}:VOLT:OFFS $val
    $dev cmd OUTP${chan} ON
  }
  method set_volt_fast {val} {
    $dev cmd SOUR${chan}:VOLT:OFFS $val
  }
  method get_volt {} { return [$dev cmd "SOUR${chan}:VOLT:OFFS? "] }
}
