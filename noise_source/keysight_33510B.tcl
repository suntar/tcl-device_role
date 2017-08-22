# Use generator Keysight 33510B (2 channels) as a noise_source.
#
# ID string:
# Agilent
# Technologies,33510B,MY52201807,3.05-1.19-2.00-52-00
#
# Use channels 1 or 2 to set output

package require Itcl

itcl::class device_role::noise_source::keysight_33510B {
  inherit device_role::noise_source::interface

  variable chan;  # channel to use (1..2)

  proc id_regexp {} {return {,33510B,}}

  constructor {d ch} {
    if {$ch!=1 && $ch!=2} {
      error "$this: bad channel setting: $ch"}
    set chan $ch

    set dev $d
    set max_v 20
    set min_v 0.002
  }

  method set_noise {bw volt {offs 0}} {
    $dev cmd SOUR${chan}:FUNC NOISE
    $dev cmd OUTP${chan}:LOAD INF
    $dev cmd SOUR${chan}:VOLT:UNIT VPP
    $dev cmd SOUR${chan}:VOLT $volt
    $dev cmd SOUR${chan}:VOLT:OFFS $offs
    $dev cmd SOUR${chan}:FUNC:NOISE:BANDWIDTH $bw
    $dev cmd OUTP${chan} ON
  }
  method set_noise_fast {bw volt {offs 0}} {
    $dev cmd SOUR${chan}:VOLT $volt
    $dev cmd SOUR${chan}:VOLT:OFFS $offs
    $dev cmd SOUR${chan}:FUNC:NOISE:BANDWIDTH $bw
  }
  method get_volt {} { return [$dev cmd "SOUR${chan}:VOLT?"] }
  method get_bw   {} { return [$dev cmd "SOUR${chan}:FUNC:NOISE:BANDWIDTH?"] }
  method get_offs {} { return [$dev cmd "SOUR${chan}:VOLT:OFFS?"] }
}
