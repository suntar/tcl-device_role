######################################################################
# ac_source role

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
  method off       {} {};    # turn off the signal
  method on        {} {};    # turn on the signal

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
  variable onoff

  constructor {d ch id} {
    set freq 1000
    set volt 0.1
    set offs  0
    set phase 0
    set onoff 1
    set min_v 0
    set max_v 10
  }

  method set_ac {f v {o 0}} {
    if {$v < $min_v} {set v $min_v}
    if {$v > $max_v} {set v $max_v}
    set freq $f
    set volt $v
    set offs $o
    set onoff 1
  }
  method off {} { set onoff 0 }
  method on  {} { set onoff 1 }
  method get_volt {} { return [expr {$onoff ? $volt : 0}]}
  method get_freq {} { return $freq }
  method get_offs {} { return [expr {$onoff ? $offs : 0}] }
  method get_phase {} { return $phase }

  method set_volt {v}  { set volt $v }
  method set_freq {v}  { set freq $v }
  method set_offs {v}  { set offs $v }
  method set_phase {v} { set phase $v }

  method set_sync {state} { }
}

######################################################################
# Use HP/Agilent/Keysight 1- and 2-channel generators as an ac_source.
#
# 2-channel devices (Use channels 1 or 2 to set output):
# Agilent Technologies,33510B,MY52201807,3.05-1.19-2.00-52-00
# Agilent Technologies,33522A,MY50005619,2.03-1.19-2.00-52-00
#
# 1-channel devices (No channels supported):
#Agilent
#Technologies,33511B,MY52300310,2.03-1.19-2.00-52-00
#

itcl::class keysight {
  inherit keysight_gen interface
  proc test_id {id} {keysight_gen::test_id $id}
  # we use Device from keysight_gen class
  method get_device {} {return $keysight_gen::dev}

  constructor {d ch id} {keysight_gen::constructor $d $ch $id} {
    set max_v 20
    set min_v 0.002
    set_par "${sour_pref}BURST:STATE" "0"
    set_par "${sour_pref}VOLT:UNIT" "VPP"
    set_par "UNIT:ANGL"             "DEG"
    set_par "${sour_pref}FUNC"      "SIN"
    set_par "OUTP${chan}:LOAD"      "INF"
  }

  method set_ac {freq volt {offs 0}} {
    err_clear
    $dev cmd "${sour_pref}APPLY:SIN $freq,$volt,$offs"
    err_check
    set_par "OUTP${chan}" "1"
  }
  method off {} {
#  # For Keysight generators it maybe useful to set VOLT to $min_v
#  # to reduce signal leakage.
#  # But this can work in some unexpected way if 
#  # voltage will be read and changed in the "off" state.
#    set old_v [get_volt]
#    set_par "${sour_pref}VOLT" $min_v
    set_par "OUTP${chan}" 0
  }
  method on {} {
#    set_par "${sour_pref}VOLT" $old_v
    set_par "OUTP${chan}" 1
  }
  method get_volt {}  {
    if {[$dev cmd "OUTP${chan}?"] == 0} {return 0}
    return [$dev cmd "${sour_pref}VOLT?"]
  }
  method get_freq  {} { return [$dev cmd "${sour_pref}FREQ?"] }
  method get_offs  {} { return [$dev cmd "${sour_pref}VOLT:OFFS?"] }
  method get_phase {} { return [$dev cmd "${sour_pref}PHAS?"] }

  method set_volt {v}  {
    if {$v==0} { off; return}
    set_par "${sour_pref}VOLT" $v
    set_par "OUTP${chan}" 1
  }
  method set_freq {v}  { set_par "${sour_pref}FREQ" $v }
  method set_offs {v}  { set_par "${sour_pref}VOLT:OFFS" $v }

  method set_phase {v} {
    set v [expr $v-int($v/360.0)*360]
    set_par "${sour_pref}PHAS" $v
  }

  method set_sync {state} {
    if {$chan != {}} {
      set_par "OUTP:SYNC:SOUR" "CH${chan}"
    }
    if {$state} { set_par "OUTP:SYNC" 1 }\
    else        { set_par "OUTP:SYNC" 0 }
  }
}

######################################################################
} # namespace
