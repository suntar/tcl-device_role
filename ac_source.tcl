######################################################################
# A ac_source role

package require Itcl
package require Device

namespace eval device_role::ac_source {

######################################################################
## Interface class. All driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}

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
# TEST device. Does nothing.

itcl::class TEST {
  inherit interface
  proc test_id {id} {}
  variable freq
  variable volt
  variable offs
  variable phase

  constructor {d ch} {
    set freq 1000
    set volt 0.1
    set offs  0
    set phase 0
  }

  method set_ac {f v {o 0}} {
    set freq $f
    set volt $v
    set offs $o
  }
  method set_ac_fast {f v {o 0}} {
    set_ac $f $v $o
  }
  method off {} {
    set volt 0
    set offs 0
  }
  method get_volt {} { return $volt }
  method get_freq {} { return $freq }
  method get_offs {} { return $offs }
  method get_phase {} { return $phase }

  method set_volt {v}  { set volt $v }
  method set_freq {v}  { set freq $v }
  method set_offs {v}  { set offs $v }
  method set_phase {v} { set phase $v }

  method set_sync {state} { }
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
  proc test_id {id} {
    if {[regexp {,33510B,} $id]} {return {33510B}}
    if {[regexp {,33522A,} $id]} {return {33522A}}
  }
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

itcl::class keysight_1ch {
  inherit interface
  proc test_id {id} {
    if {[regexp {,33509B,} $id]} {return {33509B}}
    if {[regexp {,33511B,} $id]} {return {33511B}}
    if {[regexp {,33520A,} $id]} {return {33520A}}
  }

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
  proc test_id {id} {
    if {[regexp {,33220A,} $id]} {return {33220A}}
  }

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
