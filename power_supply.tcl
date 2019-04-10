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
  public variable i_prec; # current precision
                          # (how measured value can deviate from set value)

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

  constructor {d ch} {
    set dev {}
    set max_i 3.09
    set min_i 0.0
    set max_v 60.0
    set min_v 0.0
    set min_i_step 0.001
    set min_v_step 0.01
    set i_prec 0.01
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
#  * N6761A
#  * N6762A
# Use channels 1..4
# For module N6762A use specify also range, L or H
# For polarity switch (see elsewhere) add :P<N><M> suffix
#  (pin N should switch to positive polarity, M to negative)
#
# Example:
#  ps0:1H -- use device ps0, 1st channel (N6762A module in high range)
#  ps0:2L -- use device ps0, 2nd channel (N6762A module in low range)
#  ps0:3  -- use device ps0, 3rd channel (N6731B module)
#  ps0:4:P67 -- use device ps0, 3rd channel with polarity switch (N6731B module)

itcl::class keysight_n6700b {
  inherit interface
  proc id_regexp {} {return {,N6700B,}}

  variable chan;  # channel to use (1..4)
  variable range; # range to use (H/L)
  variable sw_pos; # positive and negative pins of the polarity
  variable sw_neg; #   switch: 2..7 or 0 if no polarity switch used
                   #   pin 1 used for voltage check

  constructor {d ch} {
    set dev $d
    # parse channel name, range (H/L) and polarity pins (:P45):
    set sw_pos 0
    set sw_neg 0
    if {![regexp {([0-4])([HL]?)(:P([2-7])([2-7]))?} $ch x chan range p0 sw_pos sw_neg]} {
      error "$this: bad channel setting: $ch"}

    if {$sw_pos == $sw_neg} {error "same setting for positive and negative pin of polarity switch"}

    # detect module type:
    set mod [$dev cmd "syst:chan:mod? (@$chan)"]
    switch -glob -- $mod {
      N6731B {
        set min_i 0.06
        set min_i_step 1e-2
        set i_prec 0.7; # we can set 0 and be at 0.06
      }
      N676[12]A {
        # modules has two current ranges: 0.1 and 1.5 or 3A
        switch -- $range {
          H {
            $dev cmd "curr:rang 1,(@$chan)"
            set min_i 1e-3;
            set min_i_step 1e-4
            set i_prec 1.2e-3; # we can set 0 and be at 0.001
          }
          L {
            $dev cmd "curr:rang 0.09,(@$chan)"
            set min_i 1e-4;
            set min_i_step 2e-6
            set i_prec 1.2e-4
          }
          default { error "$this: unknown range for $mod: $range" }
        }
      }
      default { error "$this: unknown module: $mod"}
    }
    set max_i [$dev cmd "curr:rang? (@$chan)"]
    set max_v [$dev cmd "volt:rang? (@$chan)"]
    set min_v 0
    # if polarity switch is used, we can go to -max_i, -max_v
    if {$sw_pos!=0 && $sw_neg!=0} {
      set min_i [expr {-$max_i}]
      set min_v [expr {-$max_v}]
    }
  }

  #################
  ## methods for polarity switch

  # check relay power
  method check_power {} {
    # pin1 should be 1 with NEG or POS polarity
    # depending on the pin state (which we do not know)
    set data [$dev cmd "dig:inp:data?"]
    if { [get_pin $data 1] } { return }
    # revert polarity and try again:
    set pol [string equal [$dev cmd "dig:pin1:pol?"] "NEG"]
    $dev cmd "dig:pin1:pol [expr $pol?{POS}:{NEG}]"
    set data [$dev cmd "dig:inp:data?"]
    if { [get_pin $data 1] } { return }
    # fail:
    error "Failed to operate polarity switch. Check relay power."
  }

  # Get digital port pin state (n=1..7).
  # Value should be inverted if polarity is negative.
  method get_pin {data n} {
    set pol [string equal [$dev cmd "dig:pin$n:pol?"] "NEG"]
    return [ expr {(($data >> ($n-1)) + $pol)%2} ]
  }
  # Set pin in the data.
  # Value should be inverted if polarity is negative.
  method set_pin {data n v} {
    set pol [string equal [$dev cmd "dig:pin$n:pol?"] "NEG"]
    set v [expr {($v+$pol)%2}]
    set data [expr {1 << ($n-1) | $data}]
    if {$v==0} { set data [expr {$data ^ 1 << ($n-1)}] }
    return $data
  }
  # Get output polarity
  method get_pol {chan sw_pos sw_neg} {
    check_power
    # Read current pin settings (this works only of power is on)
    set data [expr int([$dev cmd "dig:inp:data?"])]
    set d1 [get_pin $data $sw_pos]
    set d2 [get_pin $data $sw_neg]
    if {$d1 == 0 && $d2 == 1} { return +1 }
    if {$d1 == 1 && $d2 == 0} { return -1 }
  }
  # Set output polarity
  method set_pol {pol chan sw_pos sw_neg} {
    check_power
    # Set pins if needed
    set data [expr int([$dev cmd "dig:inp:data?"])]
    set data1 $data
    set data1 [set_pin $data1 $sw_pos [expr {$pol<=0}]]
    set data1 [set_pin $data1 $sw_neg [expr {$pol>0}]]
    if {$data1 != $data } {$dev cmd "DIG:OUTP:DATA $data1"}
    # Check new state:
    if { $data1 != [$dev cmd "DIG:INP:DATA?"] } {
      error "Failed to operate polarity switch. Wrong pin setting."}
  }

  #################
  method set_volt {val} {
    # No polarity switch or zero current:
    if {($sw_pos==0 || $sw_neg==0) || $val == 0} {
      $dev cmd "volt $val,(@$chan)"
      return
    }
    # set channel polarity, set current
    set_pol $val $chan $sw_pos $sw_neg
    $dev cmd "volt [expr abs($val)],(@$chan)"
  }

  method set_curr {val} {
    # No polarity switch or zero current:
    if {($sw_pos==0 || $sw_neg==0) || $val == 0} {
      $dev cmd "curr $val,(@$chan)"
      return
    }
    # set channel polarity, set current
    set_pol $val $chan $sw_pos $sw_neg
    $dev cmd "curr [expr abs($val)],(@$chan)"
  }

  method get_volt {} {
    set val [$dev cmd "meas:volt? (@$chan)"]
    if {$sw_pos!=0 && $sw_neg!=0} {
      set val [expr {$val*[get_pol $chan $sw_pos $sw_neg]}] }
    return $val
  }
  method get_curr {} {
    set val [$dev cmd "meas:curr? (@$chan)"]
    if {$sw_pos!=0 && $sw_neg!=0} {
      set val [expr {$val*[get_pol $chan $sw_pos $sw_neg]}] }
    return $val
  }

  method set_ovp  {val} {
    $dev cmd "volt $val,(@$chan)"
    $dev cmd "volt:prot $val,(@$chan)"
  }
  method set_ocp  {val} {
    $dev cmd "curr $val,(@$chan)"
    $dev cmd "curr:prot $val,(@$chan)"
  }

  method cc_reset {} {
    set oc [$dev cmd "stat:oper:cond? (@$chan)"]
    set qc [$dev cmd "stat:ques:cond? (@$chan)"]

    # if device is in CC mode and no error conditions - do nothing
    if {$oc&2 && $qc==0} {return}


    # if OVP is triggered set zero current and clear the OVP
    if {$oc&4 && $qc&1} {
      $dev cmd "curr 0,(@$chan)"
      after 100
      $dev cmd "outp:prot:cle (@$chan)"
      after 100
      return
    }

    # if output is off, set zero current and turn on the output
    if {$oc&4} {
      $dev cmd "curr 0,(@$chan)"
      after 100
      $dev cmd "outp on,(@$chan)"
      after 100
      return
    }

    error "device is in strange state: [get_stat] ($oc:$qc)"
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
    set i_prec 0.01
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