# DeviceRole library -- standardized drivers for devices
---

## Ideology

This is a tcl library for implementing some special roles of devices used
in the Device library. For example you have a multimeter. Device library
only knows a name of this device (say mult0) and how it is connected. It
can transfer commands to the device, but it knows nothing about its model
and capabilities.

DeviceRole library can autodetect device model and use a driver with some
standard commands. Client only knows, that the role of device "mult0" is
a "voltmeter", and thus it has a get_volt command.

Usage:
```tcl
Package require DeviceRole
set dev [DeviceRole mult0 voltmeter]
set v [dev get_volt]
itcl::delete object $dev
```

This device roles are not universal. All real devices have different
capabilities, but in many cases some simple operations are needed, then
DeviceRole library can be useful. For example, a program for NMR
measurements can use a device with a "sweeper" role to sweep field (or
frequency), and a device with "gauge" role to perform some measurements
and get values. Various devices can be used as these "sweeper" and
"gauge" devices. One device can have many roles.

#### Channels

Sometimes it is useful to specify which "channel" of the device used for
the role: ```tcl set dev [DeviceRole lockin0:2 dc_source] ``` This
means, that channel 2 of device lockin0 should be used as a
"dc_source". Driver of the lock-in knows that the lock-in has
two auxilary outputs and can use them as controlled voltage sources. Note
that this channel specification depend on a device models and can contain
any device-specific parameter. For example, one can write a "gauge" role
driver for a multimeter which can understand channels R,V,I for
resistance, voltage or current measurements.

#### Locks

Library provides access to locks implemented in Device library.
Every driver has following commands (see Device library documentation for
more infomation):
```tcl
* lock   -- lock the device
* unlock -- unlock the device
```

TODO: channel-specific locks.


#### Test devices

Some roles have a TEST device which is not connected to any phisycal
device and produce some fake data. You can use it for testing:

```tcl
set dev [DeviceRole TEST power_supply]
```

---
## Existing roles:

#### power_supply -- a power supply with constant current and constant voltage modes

Parameters and commands (see `power_supply/Base.tcl`):

```tcl
variable max_i; # max current
variable min_i; # min current
variable max_v; # max voltage
variable min_v; # min voltage
variable min_i_step; # min step in current
variable min_v_step; # min step in voltage

set_volt {val}; # set maximum voltage
set_curr {val}; # set current
set_ovp  {val}; # set/unset overvoltage protaction
set_ocp  {val}; # set/unset overcurrent protection
get_curr {};    # measure actual value of voltage
get_volt {};    # measure actual value of current
cc_reset {};    # bring the device into a controlled state in a constant current mode
get_stat {};    # get device status (short string to be shown in the user)
```

Supported devices:

* Keysight N6700B frame with N6762A or N6762A modules. Channel (1-4) and range
(<channel>H or <channel>L) for N6762A can be selected: ps:1L

* Korad/Velleman/Tenma 72-2550 power supply.

* Korad/Velleman/Tenma 72-2540 power supply.

* TEST

---
#### dc_source -- a simple DC voltage source

Parameters and commands (see `dc_source/Base.tcl`):
```tcl
variable max_v; # max voltage
variable min_v; # min voltage
variable min_v_step; # min step in voltage

set_volt {val}; # set voltage
get_volt {};    # get voltage value
off {};         # turn the output off
```

Supported devices:

* Korad/Velleman/Tenma 72-2540 power supply.

* Korad/Velleman/Tenma 72-2550 power supply.

* SR844 lock-in (auxilary outputs). Use channels 1 or 2 to select the output.

* Keysight 33511B generator (1 channel).

* Keysight/Agilent/HP 2-channel generators 33510B and 33522A. Use channels 1 or 2 to select the output.

---
#### ac_source -- AC voltage source

Parameters and commands (see `voltage_supply/Base.tcl`):
```tcl
variable max_v; # max voltage
variable min_v; # min voltage

set_ac {freq volt {offs 0}};      # reconfigure the output and set frequency, voltage, offset
set_ac_fast {freq volt {offs 0}}; # set frequency, voltage, offset
get_volt  {};     # get voltage value (Vpp)
get_freq  {};     # get frequency value (Hz)
get_offs  {};     # get offset value (V)
get_phase {};     # get phase value (degrees)

set_volt  {v};    # set voltage value (Vpp)
set_freq  {v};    # set frequency value (Hz)
set_offs  {v};    # set offset value (V)
set_phase {v};    # set phase value (degrees)

set_sync {state}; # set state of front-panel sync connector (0 or 1)
off {};           # turn the output off
```

Supported devices:

* Keysight 33511B generator (1 channel).

* Keysight/Agilent/HP 2-channel generators 33510B and 33522A. Use channels 1 or 2 to select the output.
set_ac command sets sync signal to follow the current channel.

---
#### noise_source -- noise source

Parameters and commands (see `voltage_supply/Base.tcl`):
```tcl
variable max_v; # max voltage
variable min_v; # min voltage

set_noise      {bw volt {offs 0}}; # reconfigure the output, set bandwidth, voltage and offset
set_noise_fast {bw volt {offs 0}}; # set bandwidth, voltage and offset
get_volt  {};    # get voltage value
get_bw    {};    # get bandwidth value
get_offs  {};    # get offset value
off {};          # turn the output off
```

Supported devices:

* Keysight 33511B generator (1 channel).

* Keysight/Agilent/HP 2-channel generators 33510B and 33522A. Use channels 1 or 2 to select the output.



---
#### gauge -- a gauge device

Parameters and commands (see `gauge/Base.tcl`):
```tcl
get {} {}; # do the measurement, return one or more numbers

get_auto {} {}; # set the range automatically, do the measurement

list_ranges  {} {}; # get list of possible range settings
list_tconsts {} {}; # get list of possible time constant settings

set_range  {val} {}; # set the range
set_tconst {val} {}; # set the time constant
get_range  {} {}; # get current range setting
get_tconst {} {}; # get current time constant setting
```

Supported devices:

* SR844 lock-in. Use channels 1 or 2 to select auxilary input,
use channels XY, RT, FXY, FRT to get X, Y, R, Theta, Frequency
combinations. Full range/tconst/autorange support.

* Keysight 34461A. Use channels ACI, DCI, ACV, DCV, R2, R4.
Only autorange measurements are supported

* PicoScope, lockin measurements with pico_rec+pico_filter program.
Channels: lockin, lockin:XY
