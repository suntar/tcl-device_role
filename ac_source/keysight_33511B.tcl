# Use generator Keysight 33511B (1 channel) as a ac_source.
#
# ID string:
#Agilent
#Technologies,33511B,MY52300310,2.03-1.19-2.00-52-00
#
# No channels supported

package require Itcl

itcl::class device_role::ac_source::keysight_33511B {
  inherit device_role::ac_source::interface

  proc id_regexp {} {return {,33511B,}}

  constructor {d ch} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set dev $d
    set max_v 20
    set min_v 0.002
    $dev cmd SOUR:VOLT:UNIT VPP
    $dev cmd UNIT:ANGL DEG
    $dev cmd SOUR:FUNC SIN
    $dev cmd OUTP:LOAD INF
  }

  method set_ac {freq volt {offs 0}} {
    $dev cmd SOUR:APPLY:SIN $freq,$volt,$offs
    $dev cmd OUTP ON
  }

  method set_ac_fast {freq volt {offs 0}} {
    $dev cmd SOUR:APPLY:SIN $freq,$volt,$offs
  }

  method off {} {
    $dev cmd SOUR:APPLY:SIN 1,$min_v,0
    $dev cmd OUTP OFF
  }

  method get_volt {} { return [$dev cmd "SOUR:VOLT?"] }
  method get_freq {} { return [$dev cmd "SOUR:FREQ?"] }
  method get_offs {} { return [$dev cmd "SOUR:VOLT:OFFS?"] }

  method get_phase {} { return [$dev cmd "SOUR:PHAS?"] }
  method set_phase {ph} { $dev cmd "SOUR:PHAS $ph" }

  method set_sync {state} {
    if {$state} { $dev cmd OUTP:SYNC ON }\
    else        { $dev cmd OUTP:SYNC OFF }
  }
}
