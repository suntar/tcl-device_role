# Use Lockin SR844 as a gauge.
#
# ID string:
#   Stanford_Research_Systems,SR844,s/n50066,ver1.006
#
# Use channels 1 or 2 to measure voltage from auxilary inputs,
# channels XY RT FXY FRT to measure lockin X Y R Theta values

package require Itcl

itcl::class device_role::gauge::sr844 {
  inherit device_role::gauge::interface

  variable chan;  # channel to use (1..2)

  # lock-in ranges and time constants
  common ranges  {1e-7 3e-7 1e-6 3e-6 1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 1e-2 3e-1 1.0}
  common tconsts {1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}

  common aux_range 10;     # auxilary input range: +/- 10V
  common aux_tconst 3e-4; # auxilary input bandwidth: 3kHz

  common id_regexp {,SR844,}

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

    while {1} {
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
    set n [lsearch -real $ranges $val]
    if {$n<0} {error "unknown range setting: $val"}
    $dev cmd "SENS $n"
  }
  method set_tconst {val} {
    if {$chan==1 || $chan==2} { error "can't set time constant for auxilar input $chan" }
    set n [lsearch -real $tconsts $val]
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
