######################################################################
# A noise_source role

package require Itcl
package require Device

namespace eval device_role::noise_source {

######################################################################
## Interface class. All power_supply driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}

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
  proc test_id {id} {}
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
    set_par $dev "SOUR${chan}:FUNC"      "NOIS"
    set_par $dev "OUTP${chan}:LOAD"      "INF"
  }

  method set_noise {bw volt {offs 0}} {
    set_par $dev "SOUR${chan}:VOLT" $volt
    set_par $dev "SOUR${chan}:VOLT:OFFS" $offs
    set_par $dev "SOUR${chan}:FUNC:NOISE:BANDWIDTH" $bw
    set_par $dev "OUTP${chan}" "1"
  }
  method set_noise_fast {bw volt {offs 0}} {
    set_noise $bw $volt $offs
  }
  method off {} {
    set_par $dev "SOUR${chan}:VOLT" $min_v
    set_par $dev "SOUR${chan}:VOLT:OFFS" 0
    set_par $dev "SOUR${chan}:FUNC:NOISE:BANDWIDTH" 10e6
    set_par $dev "OUTP${chan}" "0"
  }
  method get_volt {} {
    if {[$dev cmd "OUTP${chan}?"] == 0} {return 0}
    return [$dev cmd "SOUR${chan}:VOLT?"]
  }
  method get_bw   {} {
    return [$dev cmd "SOUR${chan}:FUNC:NOISE:BANDWIDTH?"]
  }
  method get_offs {} {
    return [$dev cmd "SOUR${chan}:VOLT:OFFS?"]
  }
}

######################################################################
# Use 1-channel Keysight/Agilent/HP generator as a noise_source.
#
# ID strings:
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
    set_par $dev "FUNC"      "NOIS"
    set_par $dev "OUTP:LOAD" "INF"
  }

  method set_noise {bw volt {offs 0}} {
    set_par $dev "VOLT" $volt
    set_par $dev "VOLT:OFFS" $offs
    set_par $dev "FUNC:NOISE:BANDWIDTH" $bw
    set_par $dev "OUTP" "1"
  }
  method set_noise_fast {bw volt {offs 0}} {
    set_noise $bw $volt $offs
  }
  method off {} {
    set_par $dev "VOLT" $min_v
    set_par $dev "VOLT:OFFS" 0
    set_par $dev "FUNC:NOISE:BANDWIDTH" 10e6
    set_par $dev "OUTP" "0"
  }
  method get_volt {} {
    if {[$dev cmd "OUTP?"] == 0} {return 0}
    return [$dev cmd "VOLT?"]
  }
  method get_bw   {} {
    return [$dev cmd "FUNC:NOISE:BANDWIDTH?"]
  }
  method get_offs {} {
    return [$dev cmd "VOLT:OFFS?"]
  }
}

######################################################################
} # namespace
