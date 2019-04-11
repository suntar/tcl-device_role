######################################################################
# burst_source role

package require Itcl
package require Device

namespace eval device_role::burst_source {

######################################################################
## Interface class. All driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage

  # methods which should be defined by driver:
  method set_burst      {freq volt cycles {offs 0} {ph 0}} {};
  method do_burst {} {};

  method set_volt  {v} {};    # set voltage value
  method set_freq  {v} {};    # set frequency value
  method set_offs  {v} {};    # set offset value
  method set_cycl  {v} {};    # set cycles value
  method set_phase {v} {};    # set phase value

  method get_volt  {} {};    # get voltage value
  method get_freq  {} {};    # get frequency value
  method get_offs  {} {};    # get offset value
  method get_cycl  {} {};    # get cycles value
  method get_phase {} {};    # get phase value
}

######################################################################
# Test device. Does nothing

itcl::class TEST {
  inherit interface
  proc test_id {id} {}
  variable fre
  variable amp
  variable cyc
  variable offs
  variable ph

  constructor {d ch id} {
    set fre 1000
    set amp 0.1
    set cyc 10
    set offs 0
    set ph   0
    set max_v 10
    set min_v 0
  }

  method set_burst {f a c {o 0} {p 0}} {
    if {$a < $min_v} {set a $min_v}
    if {$a > $max_v} {set a $max_v}
    set fre  $f
    set amp  $a
    set cyc  $c
    set offs $o
    set ph   $p
  }

  method do_burst {} {}

  method get_volt {} { return $amp }
  method get_freq {} { return $fre }
  method get_offs {} { return $offs }
  method get_cycl {} { return $cyc }
  method get_phase {} { return $ph }

  method set_volt  {v} { set amp  $v }
  method set_freq  {v} { set fre  $v }
  method set_offs  {v} { set offs $v }
  method set_cycl  {v} { set cyc  $v }
  method set_phase {v} { set ph   $v }
}

######################################################################
# Use HP/Agilent/Keysight 2-channel generators as a ac_source.
#
# No channels supported

itcl::class keysight_2ch {
  inherit interface keysight_gen
  proc test_id {id} { return [test_id_2ch $id] }
  variable chan;  # channel to use (1..2)

  constructor {d ch id} {
    if {$ch!=1 && $ch!=2} {
      error "$this: bad channel setting: $ch"}
    set chan $ch
    set dev $d
    set max_v 20
    set min_v 0.002
    ## Burst mode with BUS trigger.
    set_par $dev "SOUR${chan}:FUNC"        "SIN"
    set_par $dev "SOUR${chan}:VOLT:UNIT"   "VPP"
    set_par $dev "SOUR${chan}:PHASE"       0; # BURST mode requires zero phase!
    set_par $dev "OUTP${chan}:LOAD"        "INF"
    set_par $dev "TRIG:SOURCE"             "INF"
    set_par $dev "SOUR${chan}:BURST:STATE" "1"
    set_par $dev "SOUR${chan}:BURST:MODE"  "TRIG"
    set_par $dev "OUTP:SYNC"         1
    set_par $dev "OUTP${chan}"       1
  }

  method set_burst {fre amp cyc {offs 0} {ph 0}} {
    set_par $dev "SOUR${chan}:BURST:NCYC"  $cyc
    set_par $dev "SOUR${chan}:FREQ"        $fre
    set_par $dev "SOUR${chan}:VOLT"        $amp
    set_par $dev "SOUR${chan}:VOLT:OFFS"   $offs
    set_par $dev "SOUR${chan}:BURST:PHASE" $ph
  }

  method do_burst {} {
    $dev cmd *TRG
  }

  method get_volt  {} { return [$dev cmd "SOUR${chan}:VOLT?"] }
  method get_freq  {} { return [$dev cmd "SOUR${chan}:FREQ?"] }
  method get_offs  {} { return [$dev cmd "SOUR${chan}:VOLT:OFFS?"] }
  method get_cycl  {} { return [$dev cmd "SOUR${chan}:BURST:NCYC?"] }
  method get_phase {} { return [$dev cmd "SOUR${chan}:BURST:PHASE?"] }

  method set_volt  {v} { set_par $dev "SOUR${chan}:VOLT" $v }
  method set_freq  {v} { set_par $dev "SOUR${chan}:FREQ" $v }
  method set_offs  {v} { set_par $dev "SOUR${chan}:VOLT:OFFS"  $v }
  method set_cycl  {v} { set_par $dev "SOUR${chan}:BURST:NCYC" $v }
  method set_phase {v} { set_par $dev "SOUR${chan}:BURST:PHASE" $v }
}

######################################################################
# Use HP/Agilent/Keysight 1-channel generators as a ac_source.
#
# No channels supported

itcl::class keysight_1ch {
  inherit interface keysight_gen
  proc test_id {id} { return [test_id_1ch $id] }


  constructor {d ch id} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set dev $d
    set max_v 20
    set min_v 0.002
    ## Burst mode with BUS trigger.
    err_clear $dev
    set_par $dev "FUNC"        "SIN"
    set_par $dev "VOLT:UNIT"   "VPP"
    set_par $dev "OUTP:LOAD"   "INF"
    set_par $dev "TRIG:SOURCE" "INF"
    set_par $dev "PHASE"        0; # BURST mode requires zero phase!
    set_par $dev "BURST:STATE" "1"
    set_par $dev "BURST:MODE"  "TRIG"
    set_par $dev "OUTP:SYNC"   1
    set_par $dev "OUTP"        1
    err_check $dev
  }

  method set_burst {fre amp cyc {offs 0} {ph 0}} {
    set_par $dev "BURST:NCYC"  $cyc
    set_par $dev "FREQ"        $fre
    set_par $dev "VOLT"        $amp
    set_par $dev "VOLT:OFFS"   $offs
    set_par $dev "BURST:PHASE" $ph
  }

  method do_burst {} {
    $dev cmd *TRG
  }

  method get_volt  {} { return [$dev cmd "VOLT?"] }
  method get_freq  {} { return [$dev cmd "FREQ?"] }
  method get_offs  {} { return [$dev cmd "VOLT:OFFS?"] }
  method get_cycl  {} { return [$dev cmd "BURST:NCYC?"] }
  method get_phase {} { return [$dev cmd "BURST:PHASE?"] }

  method set_volt  {v} { set_par $dev "VOLT" $v }
  method set_freq  {v} { set_par $dev "FREQ" $v }
  method set_offs  {v} { set_par $dev "VOLT:OFFS"  $v }
  method set_cycl  {v} { set_par $dev "BURST:NCYC" $v }
  method set_phase {v} { set_par $dev "BURST:PHASE" $v }

}


######################################################################
} # namespace
