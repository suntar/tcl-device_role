######################################################################
# A power_supply role

package require Itcl
package require Device

namespace eval device_role::power_supply {

######################################################################
## Interface class. All power_supply driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc id_regexp {} {}

  # variables which should be filled by driver:
  public variable max_i; # max current
  public variable min_i; # min current
  public variable max_v; # max voltage
  public variable min_v; # min voltage
  public variable min_i_step; # min step in current
  public variable min_v_step; # min step in voltage

  # methods which should be defined by driver:
  method set_volt {val} {}; # set maximum voltage
  method set_curr {val} {}; # set current
  method set_ovp  {val} {}; # set/unset overvoltage protaction
  method set_ocp  {val} {}; # set/unset overcurrent protection
  method get_curr {} {};    # measure actual value of voltage
  method get_volt {} {};    # measure actual value of current

  ## cc_reset -- bring the device into a controlled state in a constant current mode.
  # If device in constant current mode it should do nothing.
  # If OVP is triggered, then set current to actial current value,
  # reset the OVP condition and and turn the output on.
  # This function should not do any current jumps.
  method cc_reset {} {}

  # get_stat -- get device status (short string to be shown in the interface).
  # Can have different values, depending on the device:
  #  CV  - constant voltage mode
  #  CC  - constant current mode
  #  OFF - turned off
  #  OV  - overvoltage protection triggered
  #  OC  - overcurent protection triggered
  # ...
  method get_stat {} {};
}

######################################################################
# Test power supply
# No channels are supported

itcl::class TEST {
  inherit interface
  proc id_regexp {} {}

  variable R 0.1
  variable I 0
  variable V 0
  variable OVP 0
  variable OCP 0
  variable mode OFF

  constructor {} {
    set dev {}
    set max_i 3.09
    set min_i 0.0
    set max_v 60.0
    set min_v 0.0
    set min_i_step 0.001
    set min_v_step 0.01
  }
  destructor {}
  method lock {} {}
  method unlock {} {}

  method set_volt {val} {
    set V $val
    if {$I*$R < $V} { set mode "CC" }
    if {$OCP>0 && $V/$R>$OCP} {
      set I 0
      set V 0
      set mode OCP
    }
  }
  method set_curr {val} {
    set I $val
    if {$V/$R < $I} { set mode "CV" }
    if {$OVP>0 && $I*$R>$OVP} {
      set I 0
      set V 0
      set mode OVP
    }
  }
  method set_ovp  {val} {
    set V $val
    set OVP $val
  }
  method set_ocp  {val} {
    set I $val
    set OCP $val
  }
  method get_curr {} {
    if {$mode == "CC"} {set ret $I }\
    else {set ret [expr $V/$R]}
    return $ret
  }
  method get_volt {} {
    if {$mode == "CV"} {set ret $V }\
    else {set ret [expr $I*$R]}
    return $ret
  }

  method cc_reset {} {
    set mode CC
  }

  method get_stat {} {
    return $mode
  }
}

######################################################################
# Use Keysight N6700B device in a power_suply role.
# ID string:
#  Agilent Technologies,N6700B,MY54010313,D.04.07
#
# Supported modules:
#  * N6731B
#  * N6762A
# Use channels 1..4
# For module N6762A use specify also range, L or H
#
# Example:
#  ps0:1H -- use device ps0, 1st channel (N6762A module in high range)
#  ps0:2L -- use device ps0, 2nd channel (N6762A module in low range)
#  ps0:3  -- use device ps0, 3rd channel (N6731B module)

itcl::class keysight_n6700b {
  inherit interface
  proc id_regexp {} {return {,N6700B,}}

  variable chan;  # channel to use (1..4)
  variable range; # range to use (H/L)

  constructor {d ch} {
    set dev $d
    # parse channel name and range:
    if {![regexp {([0-4])([HL]?)} $ch x chan range]} {
      error "$this: bad channel setting: $ch"}

    # detect module type:
    set mod [$dev cmd "syst:chan:mod? (@$chan)"]
    set max_i [$dev cmd "curr:rang? (@$chan)"]
    set max_v [$dev cmd "volt:rang? (@$chan)"]
    switch -- $mod {
      N6731B {
        set min_i 0.06
        set min_i_step 1e-2
        set min_v 0
      }
      N6762A {
        # module has two current ranges: 0.1 and 3A
        switch -- $range {
          H {
            set R 3
            set min_i 1e-3;
            set min_i_step 1e-4
          }
          L {
            set R 0.09
            set min_i 1e-4;
            set min_i_step 2e-6
          }
          default { error "$this: unknown range for $mod: $range" }
        }
        $dev cmd "curr:rang $R,(@$chan)"
        set min_v 0
      }
      default { error "$this: unknown module: $mod"}
    }
  }

  method set_volt {val} { $dev cmd "volt $val,(@$chan)" }
  method set_curr {val} { $dev cmd "curr $val,(@$chan)" }
  method set_ovp  {val} {
    $dev cmd "volt $val,(@$chan)"
    $dev cmd "volt:prot $val,(@$chan)"
  }
  method set_ocp  {val} {
    $dev cmd "curr $val,(@$chan)"
    $dev cmd "curr:prot $val,(@$chan)"
  }
  method get_curr {} {return [$dev cmd "meas:curr? (@$chan)"]}
  method get_volt {} {return [$dev cmd "meas:volt? (@$chan)"]}

  method cc_reset {} {
    ## set current to actual current, turn output on
    set c [$dev cmd "meas:curr? (@$chan)"]
    $dev cmd "curr $c,(@$chan)"
    $dev cmd "outp:prot:cle (@$chan)"
    $dev cmd "outp on,(@$chan)"
  }

  method get_stat {} {
    # error states
    set n [$dev cmd "stat:ques:cond? (@$chan)"]
    if {! [string is integer $n] } {return BadQCond}
    if {$n & 1} {return OV}
    if {$n & 2} {return OC}
    if {$n & 4} {return PF}
    if {$n & 8} {return CP+}
    if {$n & 16} {return OT}
    if {$n & 32} {return CP-}
    if {$n & 64} {return OV-}
    if {$n & 128} {return LIM+}
    if {$n & 256} {return LIM-}
    if {$n & 512} {return INH}
    if {$n & 1024} {return UNR}
    if {$n & 2048} {return PROT}
    if {$n & 4096} {return OSC}
    set n [$dev cmd "stat:oper:cond? (@$chan)"]
    if {! [string is integer $n] } {return BadOCond}
    if {$n & 1} {return CV}
    if {$n & 2} {return CC}
    if {$n & 4} {return OFF}
    return Unknown
  }

}

######################################################################
# Use Korad/Velleman/Tenma device in a power_suply role.
# See https://sigrok.org/wiki/Korad_KAxxxxP_series
#
# There are many devices with different id strings and limits
#   KORADKA6003PV2.0  tenma 2550 60V 3A
#   TENMA72-2540V2.0  tenma 2540 30V 5A
#   TENMA 72-2540 V2.1  tenma 2540 30V 5A
#
# No channels are supported

# Base class
itcl::class tenma_base {
  inherit interface
  proc id_regexp {} {}

  constructor {d ch} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set dev $d
    set max_i 3.09
    set min_i 0.0
    set max_v 60.0
    set min_v 0.0
    set min_i_step 0.001
    set min_v_step 0.01
  }

  method set_volt {val} {
    set val [expr {round($val*100)/100.0}]
    $dev cmd "VSET1:$val"
  }
  method set_curr {val} {
    set val [expr {round($val*1000)/1000.0}]
    $dev cmd "ISET1:$val"
  }
  method set_ovp  {val} {
    set_volt $val
    $dev cmd "OVP1"
  }
  method set_ocp  {val} {
    set_curr $val
    $dev cmd "OCP1"
  }
  method get_curr {} { return [$dev cmd "IOUT1?"] }
  method get_volt {} { return [$dev cmd "VOUT1?"] }

  method cc_reset {} {
    ## set current to actual current, turn output on
    set status [$dev cmd "STATUS?"]
    set c [$dev cmd "IOUT1?"]
    $dev cmd "ISET1:$c"
    $dev cmd "OUT1"
  }

  method get_stat {} {
    # error states
    set n 0
    binary scan [$dev cmd "STATUS?"] cu n
    if {$n==80 || $n==63}  {return CC}
    if {$n==79 || $n==81}  {return CV}
    return "OFF"
  }
}

##################################################
itcl::class tenma_72-2550 {
  inherit tenma_base
  proc id_regexp {} {return {KORADKA6003PV2.0}}

  constructor {d ch} {
    tenma_base::constructor $d $ch
  } {
    set max_i 3.09
    set max_v 60.0
  }
}

##################################################
itcl::class tenma_72-2550_v20 {
  inherit tenma_base
  proc id_regexp {} {return {TENMA72-2550V2.0}}

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
  proc id_regexp {} {return {TENMA72-2540V2.0}}

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
  proc id_regexp {} {return {TENMA 72-2540 V2.1}}

  constructor {d ch} {
    tenma_base::constructor $d $ch
  } {
    set max_i 5.09
    set max_v 31.0
  }
}

##################################################

itcl::class tenma_72-2535_v21 {
  inherit tenma_base
  proc id_regexp {} {return {TENMA 72-2535 V2.1}}

  constructor {d ch} {
    tenma_base::constructor $d $ch
  } {
    set max_i 3.09
    set max_v 31.0
  }
}

######################################################################
} # namespace