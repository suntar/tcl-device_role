######################################################################
# pulse_source role

package require Itcl
package require Device

namespace eval device_role::pulse_source {

######################################################################
## Interface class. All driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc id_regexp {} {}

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage

  # methods which should be defined by driver:
  method set_pulse      {freq volt cycles {offs 0} {ph 0}} {};
  method do_pulse {} {};

  method set_volt  {} {};    # get voltage value
  method set_freq  {} {};    # get frequency value
  method set_offs  {} {};    # get offset value
  method set_cycl  {} {};    # get cycles value
  method set_phase {} {};    # get phase

  method get_volt  {v} {};    # get voltage value
  method get_freq  {v} {};    # get frequency value
  method get_offs  {v} {};    # get offset value
  method get_cycl  {v} {};    # get cycles value
  method get_phase {v} {};    # get phase
}


######################################################################
# Use HP/Agilent/Keysight 1-channel generators as a ac_source.
#
# No channels supported

itcl::class keysight_33220A {
  inherit interface
  proc id_regexp {} {return {,33220A,}}

  constructor {d ch} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set dev $d
    set max_v 20
    set min_v 0.002
  }

  method set_pulse {fre amp cyc {offs 0} {ph 0}} {
    # clear errors
    while {1} {
      set stb [gen1 cmd *STB?]
      if {($stb&4) == 0} {break}
      gen1 cmd SYST:ERR?
    }

    ## Burst mode with BUS trigger.
    if {[$dev cmd "UNIT:ANGL?"] != "DEG"}      {$dev cmd "UNIT:ANGL DEG"}
    if {[$dev cmd "TRIG:SOURCE?"] != "BUS"}    {$dev cmd "TRIG:SOURCE BUS"}
    if {[$dev cmd "BURST:STATE?"] != "1"}      {$dev cmd "BURST:STATE on"}
    if {[$dev cmd "BURST:MODE?"] != "TRIG"}    {$dev cmd "BURST:MODE TRIG"}
    if {[$dev cmd "BURST:NCYC?"] != $cyc}      {$dev cmd "BURST:NCYC $cyc"}
    if {[$dev cmd "SOUR:FUNC?"] != "SIN"}      {$dev cmd "SOUR:FUNC SIN"}
    if {[$dev cmd "SOUR:FREQ?"] != $fre}       {$dev cmd "SOUR:FREQ $fre"}
    if {[$dev cmd "SOUR:VOLT?"] != $amp}       {$dev cmd "SOUR:VOLT $amp"}
    if {[$dev cmd "SOUR:VOLT:OFFS?"] != $offs} {$dev cmd "SOUR:VOLT:OFFS $offs"}
    if {[$dev cmd "SOUR:VOLT:UNIT?"] != "VPP"} {$dev cmd "SOUR:VOLT:UNIT VPP"}
    if {[$dev cmd "SOUR:PHAS?"] != "$ph"}      {$dev cmd "SOUR:PHAS $ph"}
    if {[$dev cmd "OUTP:LOAD?"] != "INF"}      {$dev cmd "OUTP:LOAD INF"}
    if {[$dev cmd "OUTP:SYNC?"] != "1"}        {$dev cmd "OUTP:SYNC ON"}
    if {[$dev cmd "OUTP?"] != "1"}             {$dev cmd "OUTP ON"}

    # print error if any:
    set stb [$dev cmd *STB?]
    if {($stb&4) != 0} {
      error "Generator error: [$dev cmd SYST:ERR?]"
    }
  }

  method do_pulse {} {
    $dev write *TRG
  }

  method get_volt {} { return [$dev cmd "SOUR:VOLT?"] }
  method get_freq {} { return [$dev cmd "SOUR:FREQ?"] }
  method get_offs {} { return [$dev cmd "SOUR:VOLT:OFFS?"] }
  method get_cycl {} { return [$dev cmd "BURST:NCYC?"] }
  method get_phase {} { return [$dev cmd "SOUR:PHAS?"] }

  method set_volt  {v} { $dev cmd "SOUR:VOLT $v" }
  method set_freq  {v} { $dev cmd "SOUR:FREQ $v" }
  method set_offs  {v} { $dev cmd "SOUR:VOLT:OFFS $v" }
  method set_cycl  {v} { $dev cmd "BURST:NCYC? $v" }
  method set_phase {v} { $dev cmd "SOUR:PHAS $v" }

}


######################################################################
} # namespace
