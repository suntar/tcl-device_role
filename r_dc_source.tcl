######################################################################
# dc_source role

package require Itcl
package require Device

namespace eval device_role::dc_source {

######################################################################
## Interface class. All driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage
  public variable min_v_step; # min step in voltage

  # methods which should be defined by driver:
  method set_volt      {val} {}; # set voltage and all output settings
  method set_volt_fast {val} {}; # set voltage without touching other settings
  method get_volt {} {};    # measure actual voltage value
}

######################################################################
# TEST device. Does nothing
itcl::class TEST {
  inherit interface
  proc test_id {id} {}
  variable volt

  constructor {d ch id} {
    set volt  0
    set max_v 10
    set min_v -10
    set min_v_step 0.01
  }

  method set_volt {v}      {
    if {$v < $min_v} {set v $min_v}
    if {$v > $max_v} {set v $max_v}
    set volt $v
  }
  method set_volt_fast {v} { set_volt $v }
  method off {}            { set volt 0  }
  method get_volt {}       { return $volt }
}

######################################################################
# Use HP/Agilent/Keysight 1- and 2-channel generators as a DC source.

itcl::class keysight_2ch {
  inherit keysight_gen interface
  proc test_id {id} {keysight_gen::test_id $id}

  constructor {d ch id} {keysight_gen::constructor $d $ch $id} {
    set max_v 10
    set min_v -10
    set min_v_step 0.001
    set_par "${sour_pref}BURST:STATE" "0"
    set_par "${sour_pref}VOLT:UNIT" "VPP"
    set_par "OUTP${chan}:LOAD"      "INF"
    set_par "${sour_pref}FUNC"      "DC"
  }

  method set_volt {val} {
    set_par "${sour_pref}VOLT:OFFS" $val
    set_par "OUTP${chan}" "1"
  }
  method set_volt_fast {val} {
    set_volt $val
  }
  method off {} {
    set_par "${sour_pref}VOLT:OFFS" 0
    set_par "OUTP${chan}" "0"
  }
  method get_volt {} {
    if {[$dev cmd "OUTP${chan}?"] == 0} {return 0}
    return [$dev cmd "${sour_pref}VOLT:OFFS? "]
  }
}

# Use Lockin SR844 auxilary outputs as a voltage_suply.
#
# ID string:
#   Stanford_Research_Systems,SR844,s/n50066,ver1.006
#
# Use channels 1 or 2 to set auxilary output

itcl::class sr844 {
  inherit interface
  proc test_id {id} {
    if {[regexp {,SR844,} $id]} {return 1}
  }

  variable chan;  # channel to use (1..2)
  constructor {d ch id} {
    if {$ch!=1 && $ch!=2} {
      error "$this: bad channel setting: $ch"}
    set chan $ch

    set dev $d
    set max_v +10.5
    set min_v -10.5
    set min_v_step 0.001
  }

  method set_volt {val} {
    $dev cmd "AUXO${chan},$val"
  }
  method set_volt_fast {val} {
    $dev cmd "AUXO${chan},$val"
  }
  method off {} {
    set_volt 0
  }
  method get_volt {} { return [$dev cmd "AUXO?${chan}"] }
}

######################################################################
# Use Korad/Velleman/Tenma device in a voltage_suply.
# See https://sigrok.org/wiki/Korad_KAxxxxP_series
#
# There are many devices with different id strings and limits
#   KORADKA6003PV2.0    tenma 2550 60V 3A
#   TENMA72-2540V2.0    tenma 2540 30V 5A
#   TENMA 72-2540 V2.1  tenma 2540 30V 5A
# No channels are supported

# Base class
itcl::class tenma_base {
  inherit interface
  proc test_id {id} {}

  constructor {d ch id} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set dev $d
    set max_v 60.0
    set min_v 0.0
    set min_v_step 0.01
  }

  method set_volt {val} {
    # set max current
    $dev cmd "ISET1:3.09"
    set val [expr {round($val*100)/100.0}]
    $dev cmd "VSET1:$val"
    $dev cmd "OUT1"
  }
  method set_volt_fast {val} {
    set val [expr {round($val*100)/100.0}]
    $dev cmd "VSET1:$val"
  }
  method off {} {
    $dev cmd "VSET1:0"
    $dev cmd "OUT0"
  }

  method get_volt {} { return [$dev cmd "VOUT1?"] }
}

##################################################
itcl::class tenma_72-2550 {
  inherit tenma_base
  proc test_id {id} {
    if {[regexp {KORADKA6003PV2.0} $id]} {return {72-2550}}
  }
  constructor {d ch id} {
    tenma_base::constructor $d $ch
  } {
    set max_i 3.09
    set max_v 60.0
  }
}

##################################################
itcl::class tenma_72-2550_v20 {
  inherit tenma_base
  proc test_id {id} {
    if {[regexp {TENMA72-2550V2.0} $id]} {return {72-2550}}
  }

  constructor {d ch id} {
    tenma_base::constructor $d $ch
  } {
    set max_i 3.09
    set max_v 60.0
  }
}

##################################################
itcl::class tenma_72-2540_v20 {
  inherit tenma_base
  proc test_id {id} {
    if {[regexp {TENMA72-2540V2.0} $id]} {return {72-2540}}
  }

  constructor {d ch id} {
    tenma_base::constructor $d $ch
  } {
    set max_i 5.09
    set max_v 31.0
  }
}

##################################################

itcl::class tenma_72-2540_v21 {
  inherit tenma_base
  proc test_id {id} {
    if {[regexp {TENMA 72-2540 V2.1} $id]} {return {72-2540}}
  }

  constructor {d ch id} {
    tenma_base::constructor $d $ch
  } {
    set max_i 5.09
    set max_v 31.0
  }
}

##################################################

itcl::class tenma_72-2535_v21 {
  inherit tenma_base
  proc test_id {id} {
    if {[regexp {TENMA 72-2535 V2.1} $id]} {return {72-2535}}
  }

  constructor {d ch id} {
    tenma_base::constructor $d $ch
  } {
    set max_i 3.09
    set max_v 31.0
  }
}

######################################################################
} # namespace
