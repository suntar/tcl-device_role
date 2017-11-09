# Use generator Keysight 33511B (1 channel) as a voltage_suply.
#
# ID string:
#Agilent
#Technologies,33511B,MY52300310,2.03-1.19-2.00-52-00
#
# No channels supported

package require Itcl

itcl::class device_role::dc_source::keysight_33511B {
  inherit device_role::dc_source::interface

  proc id_regexp {} {return {,33511B,}}

  constructor {d ch} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set dev $d
    set max_v 10
    set min_v 0
    set min_v_step 0.001
  }

  method set_volt {val} {
    $dev cmd SOUR:FUNC DC
    $dev cmd OUTP:LOAD INF
    $dev cmd SOUR:VOLT:UNIT VPP
    $dev cmd SOUR:VOLT:OFFS $val
    $dev cmd OUTP ON
  }
  method set_volt_fast {val} {
    $dev cmd SOUR:VOLT:OFFS $val
  }
  method off {} {
    $dev cmd SOUR:VOLT:OFFS 0
    $dev cmd OUTP${chan} OFF
  }
  method get_volt {} { return [$dev cmd "SOUR:VOLT:OFFS? "] }
}
