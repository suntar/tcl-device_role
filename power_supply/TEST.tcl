# Test power supply
# No channels are supported

package require Itcl

itcl::class device_role::power_supply::TEST {
  inherit device_role::power_supply::interface
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
