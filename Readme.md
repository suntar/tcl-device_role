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
```

This device roles are not universal. All real devices have different
capabilities. But in many cases some simple operations are needed, then
DeviceRole library can be useful. For example, a program for NMR
measurements can use a device with a "sweeper" role to sweep field (or
frequency), and a device with "gauge" role to perform some measurements
and get values. Various devices can be used as these "sweeper" and
"gauge" devices. One device can have many roles.

#### Channels

Sometimes it is useful to specify which "channel" of the device used
for the role. It can be done in this way. Consider a lock-in amplifier, which
has 4 auxilary outputs for setting DC voltage. Consider a device role
"voltage_supply" which can set voltage on any device. Then you can write
```tcl
set dev [DeviceRole lockin0:2 voltage_supply]
```
This means, that channel 2 of device lockin0 should be used as a
"voltage_supply". Note that this channel specification depend on a device
models and can contain any device-specific parameter. For example, one
can write a "gauge" role driver for a multimeter which can understand
channels R,V,I for resistance, voltage or current measurements.

#### Locks and logging

Library provides access to locks and logging implemented in Device library.
Every driver has following commands (see Device library documentation):
```tcl
* lock   -- lock the device
* unlock -- unlock the device
* set_logfile <f> -- set file for logging
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

* Keysight N6700B frame with N6762A and N6762A modules. Channel (1-4) and range
(<channel>H or <channel>L) for N6762A can be selected: ps:1L

* Korad/Velleman/Tenma 72-2550 power supply.

#### voltage_supply -- a simple voltage supply device

Parameters and commands (see `voltage_supply/Base.tcl`):
```tcl
variable max_v; # max voltage
variable min_v; # min voltage
variable min_v_step; # min step in voltage

set_volt {val}; # set voltage
get_volt {};    # get voltage value
```

Supported devices:

* Korad/Velleman/Tenma 72-2550 power supply.

* SR844 lock-in (auxilary outputs). Use channels 1 or 2 to select the output.

* Keysight 33511B generator (1 channel).

* Keysight 33510B generator (2 channels). Use channels 1 or 2 to select the output.

