%define teaname DeviceRole
%define major 1.0

Name: tcl-device_role
Version: %major
Release: alt1
BuildArch: noarch

Summary: DeviceRole library, standardized drivers for devices
Group: System/Libraries
Source: %name-%version.tar
License: Unknown

Requires: tcl

%description
tcl-device_role -- DeviceRole library, standardized drivers for devices
%prep
%setup -q

%install
mkdir -p %buildroot/%_tcldatadir/%teaname
install -m644 *.tcl %buildroot/%_tcldatadir/%teaname

%files
%dir %_tcldatadir/%teaname
%_tcldatadir/%teaname/*

%changelog
