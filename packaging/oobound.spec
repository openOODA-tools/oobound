Name:           oobound
Version:        0.1.0
Release:        1%{?dist}
Summary:        Dynamic memory, CPU cycle, and file descriptor clamp for unvetted subprocesses.
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/oobound
Source0:        oobound-linux-x86_64
Source1:        uninstall.sh
BuildArch:      x86_64
Requires:       glibc

%description
oobound is a sovereign, capability-bounded RUNTIME BOUNDS written
in pure openOODA, featuring zero ambient authority, oote color themes,
and an MCP stdio server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/oobound
install -m 0755 %{SOURCE1} %{buildroot}/usr/bin/oobound-uninstall

%files
/usr/bin/oobound
/usr/bin/oobound-uninstall

%changelog
* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.1.0-1
- Initial sovereign blueprint scaffolding
