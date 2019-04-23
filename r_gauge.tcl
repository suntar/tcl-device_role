######################################################################
# gauge role

package require Itcl
package require Device

namespace eval device_role::gauge {

######################################################################
## Interface class. All power_supply driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}

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
# Virtual multimeter
itcl::class TEST {
  inherit interface
  proc test_id {id} {}

  variable chan;  # channel to use (R1, R2,... T1, T2,...)
  variable type;  # R - random, T - 10s time sweep
  variable n;     # number of values 0..maxn
  variable maxn 10;
  variable tsweep 10;

  constructor {d ch id} {
    set chan $ch
    set type R
    set n    1
    if {$ch == {}} {
    }
    if {$ch!={} && ![regexp {^(T|R)([0-9]+$)} $chan v type n]} {
      error "Unknown channel setting: $ch"
    }
    if {$n<1 || $n>$maxn} {
      error "Bad number in the cannel setting: $ch"
    }
  }
  destructor {}

  ############################
  method get {} {
    set data {}
    for {set i 0} {$i<$n} {incr i} {
      set v 0
      if {$type=={R}} { set v [expr rand()] }
      if {$type=={T}} { set v [expr {[clock milliseconds]%($tsweep*1000)}] }
      lappend data $v
    }
    return $data
  }
  method get_auto {} {
    return [get]
  }
}

######################################################################
# Use Keysight/Agilent/HP multimeters 34401A, 34461A as a gauge device.
#
# ID strings:
#   Keysight Technologies,34461A,MY53220594,A.02.14-02.40-02.14-00.49-01-01
#   Agilent Technologies,34461A,MY53200874,A.01.08-02.22-00.08-00.35-01-01
#   HEWLETT-PACKARD,34401A,0,6-4-2
#
# Use channels ACI, DCI, ACV, DCV, R2, R4

itcl::class keysight {
  inherit interface
  proc test_id {id} {
    if {[regexp {,34461A,} $id]} {return {34461A}}
    if {[regexp {,34401A,} $id]} {return {34401A}}
    return {}
  }

  variable chan;  # channel to use (1..2)

  constructor {d ch id} {
    switch -exact -- $ch {
      DCV {  set cmd meas:volt:dc? }
      ACV {  set cmd meas:volt:ac? }
      DCI {  set cmd meas:curr:dc? }
      ACI {  set cmd meas:curr:ac? }
      R2  {  set cmd meas:res?     }
      R4  {  set cmd meas:fres?    }
      default {
        error "$this: bad channel setting: $ch"
        return
      }
    }
    set dev $d
    set chan $ch
    $dev cmd $cmd
  }

  ############################
  method get {} {
    return [$dev cmd "read?"]
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
  proc test_id {id} {
    if {[regexp {,SR844,} $id]} {return 1}
  }

  variable chan;  # channel to use (1..2)

  # lock-in ranges and time constants
  common ranges  {1e-7 3e-7 1e-6 3e-6 1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0}
  common tconsts {1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}

  common aux_range 10;    # auxilary input range: +/- 10V
  common aux_tconst 3e-4; # auxilary input bandwidth: 3kHz

  constructor {d ch id} {
    if {$ch!=1 && $ch!=2 && $ch!="XY" && $ch!="RT" && $ch!="FXY" && $ch!="FRT"} {
      error "$this: bad channel setting: $ch"}
    set chan $ch
    set dev $d
  }

  ############################
  method get {{auto 0}} {
    # If channel is 1 or 2 read auxilary input:
    if {$chan==1 || $chan==2} { return [$dev cmd "AUXO?${chan}"] }

    # If autorange is needed, use AGAN command:
    if {$auto} {$dev cmd "AGAN"; after 100}

    # Return space-separated values depending on channel setting
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
# Channels:

# * `DC(<channels>)` -- measure DC signal on all oscilloscope channels
#   (`A`, `B`, etc) channels, return multiple values, one for each channel.
#   Any number of channels with any order and repeats can be used. For example
#   `DC(ABA)` returns three values: DC components on A, B, and A channels.
#
# * `DC` -- same as DC(A).
#
# * `lockin(<channels>):FXY` -- do a lock-in measurement. Channel list should
#   contain even number of oscilloscope channels (`A`, `B`, etc.) to be used
#   as signal+reference pairs. Three numbers per each channel pair are returned:
#   frequency (Hz) and two signal components (V). Any number of channels with
#   any order and repeats can be used. For reference channels 10V range is
#   used unless signal and reference channel are same.
#   Examples: `lockin(AB):FXY`, `lockin(AA):FXY`, `lockin(ABCD):FXY`,
#   `lockin(ADBDCD):FXY`.
#
# * `lockin(<channels>):XY` -- same, but returns two numbers per channel,
#   X and Y components.
#
# * If `(<channels>)` is skipped then `(AB)` is used. If `:FXY` or `:XY`
#   suffix is skipped then `:FXY` is used. Thus using just `lockin` is same as
#   `lockin(AB):FXY`.

itcl::class picoscope {
  inherit interface
  proc test_id {id} {
    if {[regexp {pico_rec} $id]} {return 1}
  }

  variable osc_meas;  # measurement type: DC, lockin
  variable osc_ch;    # list of oscilloscope channels (A B)
  variable osc_out;   # output format for lockin measurement (XY, FXY)
  variable osc_ach;   # unique channel sequence: ABCD
  variable osc_nch;   # number of each channel in osc_ach: osc_nch(A)=0, osc_nch(B)=1

  # lock-in ranges and time constants
  common ranges
  common tconsts {1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0}
  common tconst
  common range
  common range_ref
  common npt 1e6; # point number
  common sigfile
  common status

  constructor {d ch id} {

    set osc_meas {}
    if {[regexp {^DC(\(([A-D]+)\))?$} $ch v0 v1 v2]} {
      set osc_meas DC
      set osc_ch [split $v2 {}]
      # defaults
      if {$osc_ch == {}} {set osc_ch A}
    }
    if {[regexp {^lockin(\(([A-D]+)\))?(:([FRXY]+))?$} $ch v0 v1 v2 v3 v4]} {
      set osc_meas lockin
      set osc_ch [split $v2 {}]
      set osc_out $v4
      # defaults
      if {$osc_ch  == {}} {set osc_ch [list A B]}
      if {$osc_out == {}} {set osc_out FXY}

      # we want 2,4,6... channels
      if {[llength $osc_ch] %2 != 0} {
        error "$this: bad channel setting: 2,4... oscilloscope channels expected: $ch"}

      # output format
      if {$osc_out != {XY} && $osc_out != {FXY}} {
        error "$this: bad channel setting: only XY or FXY output is supported: $ch"}


    }
    if {$osc_meas == {}} {
      error "$this: bad channel setting: $ch"}

    # fill osc_ach and osc_nch
    set i 0
    set osc_ach {}
    array unset osc_nch
    foreach ch $osc_ch {
      if {[array names osc_nch $ch] == {}} {
        set osc_ach "$osc_ach$ch"
        set osc_nch($ch) $i
        incr i
      }
    }

    set dev $d

    # oscilloscope ranges
    set ranges [lindex [$dev cmd ranges A] 0]
    set tconst  1.0
    set range   1.0
    set range_ref 10.0
    set sigfile "/tmp/$dev:gauge.sig"
    set status "OK"
  }

  ############################
  method get {{auto 0}} {

    if {$osc_meas=="lockin"} {

      set dt [expr $tconst/$npt]
      set justinc 0; # avoid inc->dec loops
      while {1} {
        # oscilloscope setup (pairs of channels: signal+reference)
        foreach {c1 c2} $osc_ch {
          $dev cmd chan_set $c1 1 AC $range
          if {$c1 != $c2} {
            $dev cmd chan_set $c2 1 AC $range_ref
          }
        }
        $dev cmd trig_set NONE 0.1 FALLING 0
        # record signal
        $dev cmd block $osc_ach 0 $npt $dt $sigfile

        # check for overload (any signal channel)
        set ovl 0
        foreach {c1 c2} $osc_ch {
          if {[$dev cmd filter -c $osc_nch($c1) -f overload $sigfile]} {set ovl 1}
        }

        # try to increase the range and repeat
        if {$auto == 1 && $ovl == 1} {
          set justinc 1
          if {![catch {inc_range}]} continue
        }

        set status "OK"

        # measure the value
        set max_amp 0
        set ret {}
        foreach {c1 c2} $osc_ch {
          set v [$dev cmd filter -f lockin -c $osc_nch($c1),$osc_nch($c2) $sigfile]
          set v [lindex $v 0]
          if {$v == {}} {
            set f 0
            set x 0
            set y 0
            set status "ERR"
          } else {
            set f [lindex $v 0]
            set x [lindex $v 1]
            set y [lindex $v 2]
          }
          set amp [expr sqrt($x**2+$y**2)]
          set max_amp [expr max($amp,$max_amp)]

          if {$osc_out == "XY"} {
            lappend ret $x $y
          } else {
            lappend ret $f $x $y
          }

          # if it is still overloaded
          if {$ovl == 1} { set status "OVL" }
        }

        # if amplitude is too small, try to decrease the range and repeat
        if {$auto == 1 && $justinc == 0 && $status == {OK} && $max_amp < [expr 0.5*$range]} {
          if {![catch {dec_range}]} continue
        }
        break
      }
      return $ret
    }
    if {$osc_meas=="DC"} {
      set dt [expr $tconst/$npt]
      set justinc 0; # avoid inc->dec loops

      while {1} {
        # oscilloscope setup
        foreach ch $osc_ch {
          $dev cmd chan_set $ch 1 DC $range
        }
        $dev cmd trig_set NONE 0.1 FALLING 0
        # record signal
        $dev cmd block $osc_ach 0 $npt $dt $sigfile

        # check for overload
        set ovl 0
        foreach ch $osc_ch {
          if {[$dev cmd filter -c $osc_nch($ch) -f overload $sigfile]} {set ovl 1}
        }

        # try to increase the range and repeat
        if {$auto == 1 && $ovl == 1} {
          set justinc 1;
          if {![catch {inc_range}]} continue
        }

        set status "OK"

        # measure the value
        set nch {}
        foreach ch $osc_ch {
          lappend nch $osc_nch($ch)
        }
        set nch [join $nch {,}]
        set ret [$dev cmd filter -c $nch -f dc $sigfile]

        # if it is still overloaded
        if {$ovl == 1} {
          set status "OVL"
          break
        }

        # if amplitude is too small, try to decrease the range and repeat
        set max [expr max([join $ret ,])]
        if {$auto == 1 && $justinc==0 && $max < [expr 0.5*$range]} {
          if {![catch {dec_range}]} continue
        }
        break
      }
      return $ret
    }
  }
  method get_auto {} { return [get 1] }

  ############################
  method list_ranges {} { return $ranges }
  method list_tconsts {} { return $tconsts }

  ############################
  method set_range  {val} {
    set n [lsearch -real -exact $ranges $val]
    if {$n<0} {error "unknown range setting: $val"}
    set range $val
  }

  method dec_range {} {
    set n [lsearch -real -exact $ranges $range]
    if {$n<0} {error "unknown range setting: $range"}
    if {$n==0} {error "range already at minimum: $range"}
    set range [lindex $ranges [expr $n-1]]
  }

  method inc_range {} {
    set n [lsearch -real -exact $ranges $range]
    set nmax [expr {[llength $ranges] - 1}]
    if {$n<0} {error "unknown range setting: $range"}
    if {$n>=$nmax} {error "range already at maximum: $range"}
    set range [lindex $ranges [expr $n+1]]
  }

  method set_tconst {val} {
    # can work with any tconst!
    set tconst $val
  }

  ############################
  method get_range  {} { return $range }
  method get_tconst {} { return $tconst }
  method get_status_raw {} { return $status }
  method get_status {} { return $status }

}


######################################################################
# Use Agilent VS leak detector as a gauge.
#

itcl::class leak_ag_vs {
  inherit interface
  proc test_id {id} {
    if {$id == {Agilent VS leak detector}} {return 1}
  }

  variable chan;  # channel to use

  constructor {d ch id} {
    # channels are not supported now
    set dev $d
  }

  ############################
  method get {} {
    set ret [$dev cmd "?LP"]

    set leak [lindex $ret 0]
    set pout [lindex $ret 1]
    set pin  [lindex $ret 2]
    # Values can have leading zeros.
    if {[string first "." $leak] == -1} {set leak "$leak.0"}
    if {[string first "." $pout] == -1} {set pout "$pout.0"}
    if {[string first "." $pin]  == -1} {set pin  "$pin.0"}

    set pout [format %.4e [expr $pout/760000.0]]; # mtor->bar
    set pin  [format %.4e [expr $pin/760000000.0]]; # utor->bar

    return [list $leak $pout $pin]
  }
  method get_auto {} { return [get] }
}

######################################################################
} # namespace
