######################################################################
# A gauge role

package require Itcl
package require Device

namespace eval device_role::gauge {

######################################################################
## Interface class. All power_supply driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc id_regexp {} {}

  # methods which should be defined by driver:
  method get {} {}; # do the measurement, return one or more numbers

  method get_auto {} {}; # set the range automatically, do the measurement

  method list_ranges  {} {}; # get list of possible range settings
  method list_tconsts {} {}; # get list of possible time constant settings

  method set_range  {val} {}; # set the range
  method set_tconst {val} {}; # set the time constant
  method get_range  {} {}; # get current range setting
  method get_tconst {} {}; # get current time constant setting

  method get_status {} {return ""}; # get current time constant setting
  method get_status_raw {} {return 0};
}


######################################################################
# Use Keysight 34461A as a gauge device.
#
# ID string:
#   Keysight Technologies,34461A,MY53220594,A.02.14-02.40-02.14-00.49-01-01
#
# Use channels ACI, DCI, ACV, DCV, R2, R4

itcl::class keysight_34461A {
  inherit interface
  proc id_regexp {} {return {,34461A,}}

  variable chan;  # channel to use (1..2)

  constructor {d ch} {
    if {$ch!="ACI" && $ch!="DCI"\
     && $ch!="ACV" && $ch!="DCV"\
     && $ch!="R2" && $ch!="R4"} {
      error "$this: bad channel setting: $ch"}
    set chan $ch
    set dev $d
  }

  ############################
  method get {} {
    if {$chan=="DCV"} { return [$dev cmd meas:volt:dc?] }
    if {$chan=="ACV"} { return [$dev cmd meas:volt:ac?] }
    if {$chan=="DCI"} { return [$dev cmd meas:curr:dc?] }
    if {$chan=="ACI"} { return [$dev cmd meas:curr:ac?] }
    if {$chan=="R2"}  { return [$dev cmd meas:res?] }
    if {$chan=="R4"}  { return [$dev cmd meas:fres?] }
  }
  method get_auto {} {
    return [get]
  }

  ############################
  method list_ranges {} {
  }
  method list_tconsts {} {
  }

  ############################
  method set_range  {val} {
  }
  method set_tconst {val} {
  }

  ############################
  method get_range  {} {
  }
  method get_tconst {} {
  }

}

######################################################################
# Use Lockin SR844 as a gauge.
#
# ID string:
#   Stanford_Research_Systems,SR844,s/n50066,ver1.006
#
# Use channels 1 or 2 to measure voltage from auxilary inputs,
# channels XY RT FXY FRT to measure lockin X Y R Theta values

itcl::class sr844 {
  inherit interface
  proc id_regexp {} {return {,SR844,}}

  variable chan;  # channel to use (1..2)

  # lock-in ranges and time constants
  common ranges  {1e-7 3e-7 1e-6 3e-6 1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0}
  common tconsts {1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}

  common aux_range 10;    # auxilary input range: +/- 10V
  common aux_tconst 3e-4; # auxilary input bandwidth: 3kHz

  constructor {d ch} {
    if {$ch!=1 && $ch!=2 && $ch!="XY" && $ch!="RT" && $ch!="FXY" && $ch!="FRT"} {
      error "$this: bad channel setting: $ch"}
    set chan $ch
    set dev $d
  }

  ############################
  method get {{auto 0}} {
    if {$chan==1 || $chan==2} {
      return [$dev cmd "AUXO?${chan}"]
    }
    if {$auto} {$dev cmd "AGAN"; after 100}
    if {$chan=="XY"} { return [string map {"," " "} [$dev cmd SNAP?1,2]] }
    if {$chan=="RT"} { return [string map {"," " "} [$dev cmd SNAP?3,5]] }
    if {$chan=="FXY"} { return [string map {"," " "} [$dev cmd SNAP?8,1,2]] }
    if {$chan=="FRT"} { return [string map {"," " "} [$dev cmd SNAP?8,3,5]] }
  }
  method get_auto {} { return [get 1] }

  ############################
  method list_ranges {} {
    if {$chan==1 || $chan==2} {return $aux_range}
    return $ranges
  }
  method list_tconsts {} {
    if {$chan==1 || $chan==2} {return $aux_tconst}
    return $tconsts
  }

  ############################
  method set_range  {val} {
    if {$chan==1 || $chan==2} { error "can't set range for auxilar input $chan" }
    set n [lsearch -real -exact $ranges $val]
    if {$n<0} {error "unknown range setting: $val"}
    $dev cmd "SENS $n"
  }
  method set_tconst {val} {
    if {$chan==1 || $chan==2} { error "can't set time constant for auxilar input $chan" }
    set n [lsearch -real -exact $tconsts $val]
    if {$n<0} {error "unknown time constant setting: $val"}
    $dev cmd "OFLT $n"
  }

  ############################
  method get_range  {} {
    if {$chan==1 || $chan==2} { return $aux_range}
    set n [$dev cmd "SENS?"]
    return [lindex $ranges $n]
  }
  method get_tconst {} {
    if {$chan==1 || $chan==2} { return $aux_tconst}
    set n [$dev cmd "OFLT?"]
    return [lindex $tconsts $n]
  }

  method get_status_raw {} {
    return [$dev cmd "LIAS?"]
  }

  method get_status {} {
    set s [$dev cmd "LIAS?"]
    if {$s & (1<<0)} {return "UNLOCK"}
    if {$s & (1<<7)} {return "FRE_CH"}
    if {$s & (1<<1)} {return "FREQ_OVR"}
    if {$s & (1<<4)} {return "INP_OVR"}
    if {$s & (1<<5)} {return "AMP_OVR"}
    if {$s & (1<<6)} {return "FLT_OVR"}
    if {$s & (1<<8)} {return "CH1_OVR"}
    if {$s & (1<<9)} {return "CH2_OVR"}
    return ""
  }

}


######################################################################
# Use Picoscope as a gauge.
#
# Use channels 1 or 2 to measure voltage from auxilary inputs,
# channels XY RT FXY FRT to measure lockin X Y R Theta values

itcl::class picoscope {
  inherit interface
  proc id_regexp {} {return {pico_rec}}

  variable chan;  # channel to use

  # lock-in ranges and time constants
  common ranges
  common tconsts {1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0}
  common tconst
  common range_a
  common range_b
  common npt 1e6; # point number
  common sigfile

  constructor {d ch} {
    if {$ch!="lockin" && $ch!="lockin:XY"} {
      error "$this: bad channel setting: $ch"}
    set chan $ch
    set dev $d

    # oscilloscope ranges
    set ranges [lindex [$dev cmd ranges A] 0]
    set tconst  1.0
    set range_a 1.0
    set range_b 10.0
    set sigfile "/tmp/$dev:lockin.sig"
  }

  ############################
  method get {{auto 0}} {
    # oscilloscope setup
    $dev cmd chan_set A 1 AC $range_a
    $dev cmd chan_set B 1 AC $range_b
    $dev cmd trig_set NONE 0.1 FALLING 0

    set dt [expr $tconst/$npt]
    # record signal
    $dev cmd block AB 0 $npt $dt $sigfile
    set ret [$dev cmd filter $sigfile -f lockin -F1000]
    set ret [lindex $ret 0]
    if {$ret == {}} {set ret [list 0 0 0]}
    if {$chan == "lockin"} {return $ret}

    set f [lindex $ret 0]
    set x [lindex $ret 1]
    set y [lindex $ret 2]
    if {$chan == "lockin:XY"} { return [list $x $y] }
  }
  method get_auto {} { return [get 1] }

  ############################
  method list_ranges {} { return $ranges }
  method list_tconsts {} { return $tconsts }

  ############################
  method set_range  {val} {
    set n [lsearch -real -exact $ranges $val]
    if {$n<0} {error "unknown range setting: $val"}
    set range_a $val
  }
  method set_tconst {val} {
    # can work with any tconst!
    set tconst $val
  }

  ############################
  method get_range  {} { return $range_a }
  method get_tconst {} { return $tconst }
  method get_status_raw {} { return "" }
  method get_status {} { return "" }

}


######################################################################
# Use Agilent VS leak detector as a gauge.
#
# Use channels 1 or 2 to measure voltage from auxilary inputs,
# channels XY RT FXY FRT to measure lockin X Y R Theta values

itcl::class leak_ag_vs {
  inherit interface
  proc id_regexp {} {return {Agilent VS leak detector}}

  variable chan;  # channel to use

  constructor {d ch} {
    # channels are not supported now
    set dev $d
  }

  ############################
  method get {} {
    set ret [leak_ag_vs cmd "?LP"]

    set leak [lindex $ret 0]
    set pout [lindex $ret 1]
    set pin  [lindex $ret 2]
    # Values can have leading zeros.
    if {[string first "." $leak] == -1} {set leak "$leak.0"}
    if {[string first "." $pout] == -1} {set pout "$pout.0"}
    if {[string first "." $pin]  == -1} {set pin  "$pin.0"}

    set pout [format %.4e [expr $pout/760000.0]]; # mtor->bar
    set pin  [format %.4e [expr $pout/760000000.0]]; # utor->bar

    return [list $leak $pout $pin]
  }
  method get_auto {} { return [get] }
}

######################################################################
} # namespace
