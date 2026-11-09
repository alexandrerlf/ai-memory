Name:           pitstop
# The release workflow replaces this placeholder from Cargo.toml.
Version:        0.3.2
Release:        1
Summary:        Local-first long-term memory MCP server for AI coding agents
License:        MIT
URL:            https://aimemory.sh
Source0:        https://github.com/akitaonrails/ai-memory/releases/download/v%{version}/pitstop-linux-%{_arch}.tar.gz
BuildArch:      %{_arch}
%global debug_package %{nil}
Requires:       systemd
Requires:       ca-certificates
Requires:       glibc
%global _unitdir /usr/lib/systemd/system
%global _userunitdir /usr/lib/systemd/user

%description
Cross-session memory for AI coding agents, with a local MCP server and
systemd service.

%prep
%setup -q -c

%install
install -Dpm0755 pitstop %{buildroot}%{_bindir}/pitstop
install -Dpm0644 README.md %{buildroot}%{_datadir}/doc/pitstop/README.md
install -Dpm0644 docs/install.md %{buildroot}%{_datadir}/doc/pitstop/install.md
install -Dpm0644 LICENSE %{buildroot}%{_licensedir}/pitstop/LICENSE
cp -a hooks %{buildroot}%{_datadir}/pitstop/
install -Dpm0644 packaging/systemd/pitstop.service %{buildroot}%{_unitdir}/pitstop.service
install -Dpm0644 packaging/systemd/pitstop-user.service %{buildroot}%{_userunitdir}/pitstop.service
install -Dpm0644 packaging/sysusers/pitstop.conf %{buildroot}%{_prefix}/lib/sysusers.d/pitstop.conf
install -Dpm0644 packaging/tmpfiles/pitstop.conf %{buildroot}%{_prefix}/lib/tmpfiles.d/pitstop.conf
install -Dpm0644 crates/pitstop-cli/templates/config.default.toml %{buildroot}%{_sysconfdir}/pitstop/config.toml
install -Dpm0640 packaging/env/pitstop.env %{buildroot}%{_sysconfdir}/pitstop/env

%files
%config(noreplace) %{_sysconfdir}/pitstop/config.toml
%config(noreplace) %{_sysconfdir}/pitstop/env
%{_bindir}/pitstop
%{_datadir}/pitstop/
%{_datadir}/doc/pitstop/
%{_licensedir}/pitstop/LICENSE
%{_unitdir}/pitstop.service
%{_userunitdir}/pitstop.service
%{_prefix}/lib/sysusers.d/pitstop.conf
%{_prefix}/lib/tmpfiles.d/pitstop.conf
