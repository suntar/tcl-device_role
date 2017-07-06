# Use Keysight 34461A as a gauge device.
#
# ID string:
#   Keysight Technologies,34461A,MY53220594,A.02.14-02.40-02.14-00.49-01-01
#
# Use channels ACI, DCI, ACV, DCV, R2, R4

package require Itcl

itcl::class device_role::gauge::keysight_34461A {
  inherit device_role::gauge::interface
  variable chan;  # channel to use (1..2)

  common id_regexp {,34461A,}

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
