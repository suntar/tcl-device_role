## Common functions for all keysight generators
## In inherit statement this class should go before interface class
## to override dev variable
itcl::class keysight_gen {

  protected variable chan;      # Channel to use (1,2 or empty).
  protected variable sour_pref; # 2-channel generators need SOUR1 or SOUR2
                                # prefix for some commends, for 1-ch generators
                                # it is better to have it empty instead of SOUR
                                # to support old models.
  protected variable dev;

  # Check channel setting and set "chan" and "sour_pref" variables
  constructor {d ch id} {
    # Get the model name from id (using test_id function).
    # Set number of channels for this model.
    set model [test_id $id]
    switch -exact -- $model {
      33509B -
      33511B -
      33520A -
      33220A { set nch 1 }
      33510B -
      33522A { set nch 2 }
      default { error "keysight_gen::get_nch: unknown model: $model" }
    }
    # check channel setting and set "chan" and "sour_pref" variables
    if {$nch == 1} {
      if {$ch!={}} {error "channels are not supported for the device $d"}
      set sour_pref {}
      set chan {}
    }\
    else {
      if {$ch!=1 && $ch!=2} {
        error "$this: bad channel setting: $ch"}
      set sour_pref "SOUR${ch}:"
      set chan $ch
    }
    set dev $d
  }

  # return model name for known generator id
  proc test_id {id} {
    # 1-channel
    if {[regexp {,33509B,} $id]} {return {33509B}}
    if {[regexp {,33511B,} $id]} {return {33511B}}
    if {[regexp {,33520A,} $id]} {return {33520A}}
    if {[regexp {,33520A,} $id]} {return {33220A}}
    # 2-channel
    if {[regexp {,33510B,} $id]} {return {33510B}}
    if {[regexp {,33522A,} $id]} {return {33522A}}
  }

  # set generator parameter if it is not set
  proc set_par {dev cmd val} {
    #set verb 1
    set old [$dev cmd "$cmd?"]
    #if {$verb} {puts "get $cmd: $old"}

    # on some generators LOAD? command shows a
    # large number 9.9E37 instead of INF
    if {$val == "INF" && $old > 1e30} {set old "INF"}

    if {$old != $val} {
      #if {$verb} {puts "set $cmd: $val"}
      err_clear $dev
      $dev cmd "$cmd $val"
      err_check $dev "can't set $cmd $val:"
    }
  }

  # clear generator error
  proc err_clear {dev} {
    while {1} {
      set stb [$dev cmd *STB?]
      if {($stb&4) == 0} {break}
      $dev cmd SYST:ERR?
    }
  }

  # throw generator error if any:
  proc err_check {dev {msg {}}} {
    set stb [$dev cmd *STB?]
    if {($stb&4) != 0} {
      set err [$dev cmd SYST:ERR?]
      error "Generator error: $msg $err"
    }
  }

}
