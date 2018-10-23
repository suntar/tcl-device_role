######################################################################
# A ac_source role

package require Itcl
package require Device

namespace eval device_role::ac_source {

######################################################################
## Interface class. All driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc id_regexp {} {}

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage

  # methods which should be defined by driver:
  method set_ac {freq volt {offs 0}} {};      # reconfigure output, set frequency, voltage, offset
  method set_ac_fast {freq volt {offs 0}} {}; # set frequency, voltage, offset
  method off       {} {};    # turn off the signal

  method get_volt  {} {};    # get voltage value
  method get_freq  {} {};    # get frequency value
  method get_offs  {} {};    # get offset value
  method get_phase {} {};    # get phase

  method set_volt {v}  {}
  method set_freq {v}  {}
  method set_offs {v}  {}
  method set_phase {v} {}

  method set_sync  {state} {}; # set state of front-panel sync connector
}

######################################################################
# Use HP/Agilent/Keysight 2-channel generators
# as an ac_source.
#
# ID string:
# Agilent Technologies,33510B,MY52201807,3.05-1.19-2.00-52-00
# Agilent Technologies,33522A,MY50005619,2.03-1.19-2.00-52-00
#
# Use channels 1 or 2 to set output

itcl::class keysight_2ch {
  inherit interface
  proc id_regexp {} {return {,(33510B|33522A),}}

  variable chan;  # channel to use (1..2)

  constructor {d ch} {
    if {$ch!=1 && $ch!=2} {
      error "$this: bad channel setting: $ch"}
    set chan $ch
    set dev $d
    set max_v 20
    set min_v 0.002
    $dev cmd SOUR${chan}:VOLT:UNIT VPP
    $dev cmd UNIT:ANGL DEG
    $dev cmd SOUR${chan}:FUNC SIN
    $dev cmd OUTP${chan}:LOAD INF
  }

  method set_ac {freq volt {offs 0}} {
    $dev cmd SOUR${chan}:APPLY:SIN $freq,$volt,$offs
    $dev cmd OUTP${chan} ON
  }

  method set_ac_fast {freq volt {offs 0}} {
    $dev cmd SOUR${chan}:APPLY:SIN $freq,$volt,$offs
  }

  method off {} {
    $dev cmd SOUR${chan}:APPLY:SIN 1,$min_v,0
    $dev cmd OUTP${chan} OFF
  }

  method get_volt {} { return [$dev cmd "SOUR${chan}:VOLT?"] }
  method get_freq {} { return [$dev cmd "SOUR${chan}:FREQ?"] }
  method get_offs {} { return [$dev cmd "SOUR${chan}:VOLT:OFFS?"] }
  method get_phase {} { return [$dev cmd "SOUR${chan}:PHAS?"] }

  method set_volt {v}  { $dev cmd "SOUR${chan}:VOLT $v" }
  method set_freq {v}  { $dev cmd "SOUR${chan}:FREQ $v" }
  method set_offs {v}  { $dev cmd "SOUR${chan}:VOLT:OFFS $v" }
  method set_phase {v} { $dev cmd "SOUR${chan}:PHAS $v" }

  method set_sync {state} {
    $dev cmd OUTP:SYNC:SOUR CH${chan}
    if {$state} { $dev cmd OUTP:SYNC ON }\
    else        { $dev cmd OUTP:SYNC OFF }
  }
}

######################################################################
# Use HP/Agilent/Keysight 1-channel generators as a ac_source.
#
# ID string:
#Agilent
#Technologies,33511B,MY52300310,2.03-1.19-2.00-52-00
#
# No channels supported

itcl::class keysight_33511B {
  inherit interface
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

  method set_volt {v}  { $dev cmd "SOUR:VOLT $v" }
  method set_freq {v}  { $dev cmd "SOUR:FREQ $v" }
  method set_offs {v}  { $dev cmd "SOUR:VOLT:OFFS $v" }
  method set_phase {v} { $dev cmd "SOUR:PHAS $v" }

  method set_sync {state} {
    if {$state} { $dev cmd OUTP:SYNC ON }\
    else        { $dev cmd OUTP:SYNC OFF }
  }
}

itcl::class keysight_33220A {
  inherit interface
  proc id_regexp {} {return {,33220A,}}

  constructor {d ch} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set dev $d
    set max_v 20
    set min_v 0.002
    $dev cmd VOLT:UNIT VPP
    $dev cmd UNIT:ANGL DEG
    $dev cmd SOUR:FUNC SIN
    $dev cmd OUTP:LOAD INF
  }

  method set_ac {freq volt {offs 0}} {
    $dev cmd APPLY:SIN $freq,$volt,$offs
    $dev cmd OUTP ON
  }

  method set_ac_fast {freq volt {offs 0}} {
    $dev cmd APPLY:SIN $freq,$volt,$offs
  }

  method off {} {
    $dev cmd APPLY 1,$min_v,0
    $dev cmd OUTP OFF
  }

  method get_volt {} { return [$dev cmd "SOUR:VOLT?"] }
  method get_freq {} { return [$dev cmd "SOUR:FREQ?"] }
  method get_offs {} { return [$dev cmd "SOUR:VOLT:OFFS?"] }
  method get_phase {} { return [$dev cmd "SOUR:PHAS?"] }

  method set_volt {v}  { $dev cmd "SOUR:VOLT $v" }
  method set_freq {v}  { $dev cmd "SOUR:FREQ $v" }
  method set_offs {v}  { $dev cmd "SOUR:VOLT:OFFS $v" }
  method set_phase {v} { $dev cmd "SOUR:PHAS $v" }

  method set_sync {state} {
    if {$state} { $dev cmd OUTP:SYNC ON }\
    else        { $dev cmd OUTP:SYNC OFF }
  }
}

######################################################################
} # namespace
