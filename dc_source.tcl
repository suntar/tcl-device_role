######################################################################
# A simple dc_source role

package require Itcl
package require Device

namespace eval device_role::dc_source {

######################################################################
## Interface class. All power_supply driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc id_regexp {} {}

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
# Use HP/Agilent/Keysight 2-channel generators
# as a DC source.
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
    set max_v 10
    set min_v 0
    set min_v_step 0.001
  }

  method set_volt {val} {
    $dev cmd SOUR${chan}:FUNC DC
    $dev cmd OUTP${chan}:LOAD INF
    $dev cmd SOUR${chan}:VOLT:UNIT VPP
    $dev cmd SOUR${chan}:VOLT:OFFS $val
    $dev cmd OUTP${chan} ON
  }
  method set_volt_fast {val} {
    $dev cmd SOUR${chan}:VOLT:OFFS $val
  }
  method off {} {
    $dev cmd SOUR${chan}:VOLT:OFFS 0
    $dev cmd OUTP${chan} OFF
  }
  method get_volt {} { return [$dev cmd "SOUR${chan}:VOLT:OFFS? "] }
}

######################################################################
# Use generator Keysight 33511B (1 channel) as a voltage_suply.
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
    set max_v 10
    set min_v 0
    set min_v_step 0.001
  }

  method set_volt {val} {
    $dev cmd SOUR:FUNC DC
    $dev cmd OUTP:LOAD INF
    $dev cmd SOUR:VOLT:UNIT VPP
    $dev cmd SOUR:VOLT:OFFS $val
    $dev cmd OUTP ON
  }
  method set_volt_fast {val} {
    $dev cmd SOUR:VOLT:OFFS $val
  }
  method off {} {
    $dev cmd SOUR:VOLT:OFFS 0
    $dev cmd OUTP${chan} OFF
  }
  method get_volt {} { return [$dev cmd "SOUR:VOLT:OFFS? "] }
}
# Use Lockin SR844 auxilary outputs as a voltage_suply.
#
# ID string:
#   Stanford_Research_Systems,SR844,s/n50066,ver1.006
#
# Use channels 1 or 2 to set auxilary output

package require Itcl

itcl::class sr844 {
  inherit interface

  variable chan;  # channel to use (1..2)

  proc id_regexp {} {return {,SR844,}}

  constructor {d ch} {
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
  proc id_regexp {} {}

  constructor {d ch} {
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
  proc id_regexp {} {return {^KORADKA6003PV2.0}}

  constructor {d ch} {
    tenma_base::constructor $d $ch
  } {
    set max_i 3.09
    set max_v 60.0
  }
}

##################################################
itcl::class tenma_72-2540_v20 {
  inherit tenma_base
  proc id_regexp {} {return {^(TENMA72-2540V2.0)}}

  constructor {d ch} {
    tenma_base::constructor $d $ch
  } {
    set max_i 5.09
    set max_v 31.0
  }
}

##################################################

itcl::class tenma_72-2540_v21 {
  inherit tenma_base
  proc id_regexp {} {return {^TENMA 72-2540 V2.1}}

  constructor {d ch} {
    tenma_base::constructor $d $ch
  } {
    set max_i 5.09
    set max_v 31.0
  }
}

######################################################################
} namespace
