# Use Korad/Velleman/Tenma device in a voltage_suply.
# See https://sigrok.org/wiki/Korad_KAxxxxP_series
#
# There are many devices with different id strings and limits
#   KORADKA6003PV2.0    tenma 2550 60V 3A
#   TENMA72-2540V2.0    tenma 2540 30V 5A
#   TENMA 72-2540 V2.1  tenma 2540 30V 5A
# No channels are supported

package require Itcl

# Base class
itcl::class device_role::dc_source::tenma_base {
  inherit device_role::dc_source::interface

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
itcl::class device_role::dc_source::tenma_72-2550 {
  inherit device_role::dc_source::tenma_base

  proc id_regexp {} {return {^KORADKA6003PV2.0}}

  constructor {d ch} {
    device_role::dc_source::tenma_base::constructor $d $ch
  } {
    set max_i 3.09
    set max_v 60.0
  }
}

##################################################
itcl::class device_role::dc_source::tenma_72-2540_v20 {
  inherit device_role::dc_source::tenma_base

  proc id_regexp {} {return {^(TENMA72-2540V2.0)}}

  constructor {d ch} {
    device_role::dc_source::tenma_base::constructor $d $ch
  } {
    set max_i 5.09
    set max_v 31.0
  }
}

##################################################

itcl::class device_role::dc_source::tenma_72-2540_v21 {
  inherit device_role::dc_source::tenma_base

  proc id_regexp {} {return {^TENMA 72-2540 V2.1}}

  constructor {d ch} {
    device_role::dc_source::tenma_base::constructor $d $ch
  } {
    set max_i 5.09
    set max_v 31.0
  }
}

##################################################
