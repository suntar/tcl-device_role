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
    set min_v 0
    set max_v 10
  }

  method set_ac {f v {o 0}} {
    if {$v < $min_v} {set v $min_v}
    if {$v > $max_v} {set v $max_v}
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
  inherit interface keysight_gen
  proc test_id {id} { return [test_id_2ch $id] }
  variable chan;  # channel to use (1..2)

  constructor {d ch} {
    if {$ch!=1 && $ch!=2} {
      error "$this: bad channel setting: $ch"}
    set chan $ch
    set dev $d
    set max_v 20
    set min_v 0.002
    set_par $dev "SOUR${chan}:BURST:STATE" "0"
    set_par $dev "SOUR${chan}:VOLT:UNIT" "VPP"
    set_par $dev "UNIT:ANGL"             "DEG"
    set_par $dev "SOUR${chan}:FUNC"      "SIN"
    set_par $dev "OUTP${chan}:LOAD"      "INF"
  }

  method set_ac {freq volt {offs 0}} {
    err_clear $dev
    $dev cmd SOUR${chan}:APPLY:SIN $freq,$volt,$offs
    err_check $dev
    set_par $dev "OUTP${chan}" "1"
  }

  method set_ac_fast {freq volt {offs 0}} {
    set_ac $freq $volt $offs
  }

  method off {} {
    set_par $dev "SOUR${chan}:VOLT" $min_v
    set_par $dev "OUTP${chan}" 0
  }

  method get_volt {}  {
    if {[$dev cmd "OUTP${chan}?"] == 0} {return 0}
    return [$dev cmd "SOUR${chan}:VOLT?"]
  }
  method get_freq {} { return [$dev cmd "SOUR${chan}:FREQ?"] }
  method get_offs {} { return [$dev cmd "SOUR${chan}:VOLT:OFFS?"] }
  method get_phase {} { return [$dev cmd "SOUR${chan}:PHAS?"] }

  method set_volt {v}  {
    if {$v==0} { off; return}
    set_par $dev "SOUR${chan}:VOLT" $v
    set_par $dev "OUTP${chan}" 1
  }
  method set_freq {v}  { set_par $dev "SOUR${chan}:FREQ" $v }
  method set_offs {v}  { set_par $dev "SOUR${chan}:VOLT:OFFS" $v }
  method set_phase {v} { set_par $dev "SOUR${chan}:PHAS" $v }

  method set_sync {state} {
    set_par $dev "OUTP:SYNC:SOUR" "CH${chan}"
    if {$state} { set_par $dev "OUTP:SYNC" 1 }\
    else        { set_par $dev "OUTP:SYNC" 0 }
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
  inherit interface keysight_gen
  proc test_id {id} { return [test_id_1ch $id] }

  constructor {d ch} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set dev $d
    set max_v 20
    set min_v 0.002
    set_par $dev "BURST:STATE" "0"
    set_par $dev "VOLT:UNIT" "VPP"
    set_par $dev "UNIT:ANGL" "DEG"
    set_par $dev "FUNC"      "SIN"
    set_par $dev "OUTP:LOAD" "INF"
  }

  method set_ac {freq volt {offs 0}} {
    err_clear $dev
    $dev cmd APPLY:SIN $freq,$volt,$offs
    err_check $dev "can't set APPLY:SIN $freq,$volt,$offs"
    set_par $dev "OUTP" "1"
  }

  method set_ac_fast {freq volt {offs 0}} {
    set_ac $freq $volt $offs
  }

  method off {} {
    set_par $dev "VOLT" $min_v
    set_par $dev "OUTP" 0
  }

  method get_volt {}  {
    if {[$dev cmd "OUTP?"] == 0} {return 0}
    return [$dev cmd "VOLT?"]
  }
  method get_freq {}  { return [$dev cmd "FREQ?"] }
  method get_offs {}  { return [$dev cmd "VOLT:OFFS?"] }
  method get_phase {} { return [$dev cmd "PHAS?"] }

  method set_volt {v}  {
    if {$v==0} { off; return}
    set_par $dev "VOLT" $v
    set_par $dev "OUTP" 1
  }
  method set_freq {v}  { set_par $dev "FREQ" $v }
  method set_offs {v}  { set_par $dev "VOLT:OFFS" $v }
  method set_phase {v} { set_par $dev "PHAS" $v }

  method set_sync {state} {
    if {$state} { set_par $dev "OUTP:SYNC" 1 }\
    else        { set_par $dev "OUTP:SYNC" 0 }
  }
}

######################################################################
} # namespace
