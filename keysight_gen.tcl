## common functions for all keysight generators
itcl::class keysight_gen {

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

  # return number of channel for any generator
  proc get_nch {id} {
    set model [test_id $id]
    switch -exact -- $model {
      33509B { return 1 }
      33511B { return 1 }
      33520A { return 1 }
      33220A { return 1 }
      33510B { return 2 }
      33522A { return 2 }
      default { error "keysight_gen::get_nch: unknown model: $model" }
    }
  }

  # set generator parameter if it is not set
  proc set_par {dev cmd val} {
    set verb 1
    set old [$dev cmd "$cmd?"]
    if {$verb} {puts "get $cmd: $old"}

    # on some generators LOAD? command shows a
    # large number 9.9E37 instead of INF
    if {$val == "INF" && $old > 1e30} {set old "INF"}

    if {$old != $val} {
      if {$verb} {puts "set $cmd: $val"}
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
