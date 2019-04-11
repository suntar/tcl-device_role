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

  constructor {d ch id} {
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
# Use HP/Agilent/Keysight 1- and 2-channel generators as an ac_source.
itcl::class keysight_2ch {
  inherit interface keysight_gen
  proc test_id {id} {keysight_gen::test_id $id}
  variable chan;  # channel to use (1..2)
  variable sour_pref; # 2-channel generators need SOUR1 or SOUR2
                      # prefix for some commends

  constructor {d ch id} {
    if {[get_nch $id] == 1} {
      if {$ch!={}} {error "channels are not supported for the device $d"}
      set sour_pref {}
      set chan {}
    }\
    else {
      if {$ch!=1 && $ch!=2} {
        error "$this: bad channel setting: $ch"}
      set sour_pref "SOUR${ch}:"
      set chan $ch
    }
    set dev $d
    set max_v 20
    set min_v 0.002
    set_par $dev "${sour_pref}BURST:STATE" "0"
    set_par $dev "${sour_pref}VOLT:UNIT" "VPP"
    set_par $dev "${sour_pref}FUNC"      "NOIS"
    set_par $dev "OUTP${chan}:LOAD"      "INF"
  }

  method set_noise {bw volt {offs 0}} {
    set_par $dev "${sour_pref}VOLT" $volt
    set_par $dev "${sour_pref}VOLT:OFFS" $offs
    set_par $dev "${sour_pref}FUNC:NOISE:BANDWIDTH" $bw
    set_par $dev "OUTP${chan}" "1"
  }
  method set_noise_fast {bw volt {offs 0}} {
    set_noise $bw $volt $offs
  }
  method off {} {
    set_par $dev "${sour_pref}VOLT" $min_v
    set_par $dev "${sour_pref}VOLT:OFFS" 0
    set_par $dev "${sour_pref}FUNC:NOISE:BANDWIDTH" 10e6
    set_par $dev "OUTP${chan}" "0"
  }
  method get_volt {} {
    if {[$dev cmd "OUTP${chan}?"] == 0} {return 0}
    return [$dev cmd "${sour_pref}VOLT?"]
  }
  method get_bw   {} {
    return [$dev cmd "${sour_pref}FUNC:NOISE:BANDWIDTH?"]
  }
  method get_offs {} {
    return [$dev cmd "${sour_pref}VOLT:OFFS?"]
  }
}


######################################################################
} # namespace
