%global debug_package %{nil}
%global shortcommit %(c=%{commit}; echo ${c:0:7})
%global kernel_dir %(ls -d /usr/src/kernels/%{kernel_series}.* 2>/dev/null | sort -V | tail -1)

Name:           opensnitch
Version:        %{upstream_version}~%{snapdate}git%{shortcommit}
Release:        %{pkgrel}.k%{kernel_series}%{?dist}
Summary:        Interactive application firewall

License:        GPL-3.0-or-later
URL:            https://github.com/evilsocket/opensnitch
Source0:        opensnitch-%{commit}.tar.gz

ExclusiveArch:  x86_64

BuildRequires:  golang
BuildRequires:  gcc
BuildRequires:  clang
BuildRequires:  llvm
BuildRequires:  make
BuildRequires:  kernel-devel >= %{kernel_series}
BuildRequires:  libnetfilter_queue-devel
BuildRequires:  libpcap-devel
BuildRequires:  systemd-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  python3-setuptools
BuildRequires:  python3-wheel
BuildRequires:  python3-pip
BuildRequires:  pyproject-rpm-macros
BuildRequires:  desktop-file-utils

Requires:       libnetfilter_queue
Requires:       logrotate
%{?systemd_requires}

%description
OpenSnitch intercepts outgoing connections and lets you allow or deny them
per program, user, destination, port or a combination of them. This build
comes from a pinned, signature-checked upstream commit, with the eBPF
modules compiled against Fedora kernel %{kernel_series}.

%package ui
Summary:        Graphical interface and connection prompts for OpenSnitch
BuildArch:      noarch
Requires:       %{name} = %{version}-%{release}
Requires:       python3-pyqt6
Requires:       python3-grpcio
Requires:       python3-protobuf
Requires:       python3-slugify
Requires:       python3-packaging
Requires:       python3-requests
Requires:       hicolor-icon-theme
Recommends:     python3-notify2
Recommends:     python3-pyinotify
Recommends:     python3-pyasn

%description ui
The OpenSnitch user interface: prompts for new connections, rule editor,
live connection list and statistics.

%prep
%autosetup -n opensnitch-%{commit}
sed -i 's|/usr/local/bin/opensnitchd|%{_bindir}/opensnitchd|' daemon/data/init/opensnitchd.service
sed -i '/^      data_files=\[/,/\],$/d' ui/setup.py

%build
test -n "%{kernel_dir}" || { echo "no kernel-devel %{kernel_series}.* installed" >&2; exit 1; }
cd daemon
CGO_ENABLED=1 go build -mod=vendor -trimpath -buildmode=pie \
    -ldflags "-linkmode=external -extldflags '%{build_ldflags}'" -o opensnitchd .
cd ../ebpf_prog
make KERNEL_VER=$(basename %{kernel_dir}) KERNEL_DIR=%{kernel_dir} KERNEL_HEADERS=%{kernel_dir} \
    EXTRA_FLAGS="-DCC_USING_FENTRY -fms-extensions -Wno-microsoft-anon-tag"
llvm-strip -g opensnitch*.o
cd ../ui
%pyproject_wheel

%install
install -Dm755 daemon/opensnitchd %{buildroot}%{_bindir}/opensnitchd
install -Dm644 daemon/data/init/opensnitchd.service %{buildroot}%{_unitdir}/opensnitch.service
install -Dm644 utils/packaging/daemon/deb/debian/opensnitch.logrotate %{buildroot}%{_sysconfdir}/logrotate.d/opensnitch
install -d %{buildroot}%{_prefix}/lib/opensnitchd/ebpf
install -m644 ebpf_prog/opensnitch*.o %{buildroot}%{_prefix}/lib/opensnitchd/ebpf/
install -d %{buildroot}%{_sysconfdir}/opensnitchd/rules %{buildroot}%{_sysconfdir}/opensnitchd/tasks
install -m644 daemon/data/default-config.json daemon/data/system-fw.json daemon/data/network_aliases.json %{buildroot}%{_sysconfdir}/opensnitchd/
install -m600 daemon/data/rules/*.json %{buildroot}%{_sysconfdir}/opensnitchd/rules/
install -m600 daemon/data/tasks/tasks.json %{buildroot}%{_sysconfdir}/opensnitchd/tasks/

cd ui
%pyproject_install
%pyproject_save_files opensnitch
rm -rf %{buildroot}%{python3_sitelib}/tests
desktop-file-install --dir=%{buildroot}%{_datadir}/applications resources/opensnitch_ui.desktop
install -Dm644 resources/icons/opensnitch-ui.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/opensnitch-ui.svg
install -Dm644 resources/icons/48x48/opensnitch-ui.png %{buildroot}%{_datadir}/icons/hicolor/48x48/apps/opensnitch-ui.png
install -Dm644 resources/icons/64x64/opensnitch-ui.png %{buildroot}%{_datadir}/icons/hicolor/64x64/apps/opensnitch-ui.png
install -Dm644 resources/io.github.evilsocket.opensnitch.appdata.xml %{buildroot}%{_metainfodir}/io.github.evilsocket.opensnitch.appdata.xml

%post
%systemd_post opensnitch.service

%preun
%systemd_preun opensnitch.service

%postun
%systemd_postun_with_restart opensnitch.service

%files
%license LICENSE
%{_bindir}/opensnitchd
%{_unitdir}/opensnitch.service
%{_prefix}/lib/opensnitchd/
%dir %{_sysconfdir}/opensnitchd
%dir %attr(0700,root,root) %{_sysconfdir}/opensnitchd/rules
%dir %attr(0700,root,root) %{_sysconfdir}/opensnitchd/tasks
%config(noreplace) %{_sysconfdir}/opensnitchd/default-config.json
%config(noreplace) %{_sysconfdir}/opensnitchd/system-fw.json
%config(noreplace) %{_sysconfdir}/opensnitchd/network_aliases.json
%config(noreplace) %{_sysconfdir}/opensnitchd/rules/*.json
%config(noreplace) %{_sysconfdir}/opensnitchd/tasks/tasks.json
%config(noreplace) %{_sysconfdir}/logrotate.d/opensnitch

%files ui -f %{pyproject_files}
%{_bindir}/opensnitch-ui
%{_datadir}/applications/opensnitch_ui.desktop
%{_datadir}/icons/hicolor/*/apps/opensnitch-ui.*
%{_metainfodir}/io.github.evilsocket.opensnitch.appdata.xml

%changelog
* Thu Nov 12 2026 Celso Alexandre <celso-alexandre@users.noreply.github.com> - 1.9.0~20260727gita135384-1
- Package the signed upstream commit a135384 for Fedora 44
