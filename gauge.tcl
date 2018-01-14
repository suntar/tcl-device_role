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
  method get {} {
    if {$chan==1 || $chan==2} {
      return [$dev cmd "AUXO?${chan}"]
    }
    if {$chan=="XY"} { return [string map {"," " "} [$dev cmd SNAP?1,2]] }
    if {$chan=="RT"} { return [string map {"," " "} [$dev cmd SNAP?3,5]] }
    if {$chan=="FXY"} { return [string map {"," " "} [$dev cmd SNAP?8,1,2]] }
    if {$chan=="FRT"} { return [string map {"," " "} [$dev cmd SNAP?8,3,5]] }

  }
  method get_auto {} {
    if {$chan==1 || $chan==2} {
      return [$dev cmd "AUXO?${chan}"]
    }
    #get range
    set n [$dev cmd "SENS?"]

    #get tconst
    set t [get_tconst]

    while {1} {
      #wait
      after [expr {int(5*$t*1000)}]

      # measure X,Y,R,T,F
      set out [string map {"," " "} [$dev cmd SNAP?1,2,3,5,8]]
      set X [lindex $out 0]
      set Y [lindex $out 1]
      set R [lindex $out 2]
      set T [lindex $out 3]
      set F [lindex $out 4]

      # increase sensitivity if needed
      if {$n>0 && $R <= [lindex $ranges [expr {$n-1}]]*0.95 } {
        set n [expr {$n-1}]
        $dev cmd "SENS $n"
        continue
      }
      # decrease sensitivity if needed
      if {$n<[llength $ranges] && $R > [lindex $ranges $n]*0.95 } {
        set n [expr {$n+1}]
        $dev cmd "SENS $n"
        continue
      }
      # return values
      if {$chan=="XY"} { return "$X $Y" }
      if {$chan=="RT"} { return "$R $T" }
      if {$chan=="FXY"} { return "$F $X $Y" }
      if {$chan=="FRT"} { return "$F $R $T" }
    }
  }

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
}

######################################################################
} # namespace
