######################################################################
# A noise_source role

package require Itcl
package require Device

namespace eval device_role::noise_source {

######################################################################
## Interface class. All power_supply driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc id_regexp {} {}

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage

  # methods which should be defined by driver:
  method set_noise      {bw volt {offs 0}} {}; # reconfigure the output, set bandwidth, voltage and offset
  method set_noise_fast {bw volt {offs 0}} {}; # set bandwidth, voltage and offset
  method get_volt  {} {};    # get voltage value
  method get_bw    {} {};    # get bandwidth value
  method get_offs  {} {};    # get bandwidth value
  method off       {} {};    # turn off the signal
}

######################################################################
# TEST device. Does nothing

itcl::class TEST {
  inherit interface
  variable volt
  variable bw
  variable offs

  constructor {d ch} {
    set volt 0
    set bw 1000
    set offs 0
    set max_v 10
    set min_v 0
  }

  method set_noise {b v {o 0}} {
    if {$v < $min_v} {set v $min_v}
    if {$v > $max_v} {set v $max_v}
    set volt $v
    set offs $o
    set bw   $b
  }
  method set_noise_fast {b v {o 0}} { set_noise $b $v $o }
  method off {} {
    set volt 0
    set offs 0
  }
  method get_volt {} { return $volt }
  method get_bw   {} { return $bw }
  method get_offs {} { return $offs }
}

######################################################################
# Use HP/Agilent/Keysight 2-channel generators
# as a noise_source.
#
# ID strings:
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
  method off {} {
    $dev cmd SOUR${chan}:VOLT $min_v
    $dev cmd SOUR${chan}:VOLT:OFFS 0
    $dev cmd SOUR${chan}:FUNC:NOISE:BANDWIDTH 10e6
    $dev cmd OUTP${chan} OFF
  }
  method get_volt {} { return [$dev cmd "SOUR${chan}:VOLT?"] }
  method get_bw   {} { return [$dev cmd "SOUR${chan}:FUNC:NOISE:BANDWIDTH?"] }
  method get_offs {} { return [$dev cmd "SOUR${chan}:VOLT:OFFS?"] }
}

######################################################################
# Use generator Keysight 33511B (1 channel) as a noise_source.
#
# ID string:
#Agilent
#Technologies,33511B,MY52300310,2.03-1.19-2.00-52-00
#
# No channels supported

itcl::class keysight_1ch {
  inherit interface
  proc id_regexp {} {return {,(33509B|33511B|33220A),}}

  constructor {d ch} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set dev $d
    set max_v 20
    set min_v 0.002
  }

  method set_noise {bw volt {offs 0}} {
    $dev cmd SOUR:FUNC NOISE
    $dev cmd OUTP:LOAD INF
    $dev cmd SOUR:VOLT:UNIT VPP
    $dev cmd SOUR:VOLT $volt
    $dev cmd SOUR:VOLT:OFFS $offs
    $dev cmd SOUR:FUNC:NOISE:BANDWIDTH $bw
    $dev cmd OUTP ON
  }
  method set_noise_fast {bw volt {offs 0}} {
    $dev cmd SOUR:VOLT $volt
    $dev cmd SOUR:VOLT:OFFS $offs
    $dev cmd SOUR:FUNC:NOISE:BANDWIDTH $bw
  }
  method off {} {
    $dev cmd SOUR:VOLT $min_v
    $dev cmd SOUR:VOLT:OFFS 0
    $dev cmd SOUR:FUNC:NOISE:BANDWIDTH 10e6
    $dev cmd OUTP OFF
  }
  method get_volt {} { return [$dev cmd "SOUR:VOLT?"] }
  method get_bw   {} { return [$dev cmd "SOUR:FUNC:NOISE:BANDWIDTH?"] }
  method get_offs {} { return [$dev cmd "SOUR:VOLT:OFFS?"] }
}

######################################################################
} # namespace