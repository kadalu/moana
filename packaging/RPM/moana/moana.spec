Name:     moana
Version:  1.0.0
Release:  1%{?dist}
Summary:  Moana CLI, Manager
License:  GPLv3+
URL:      https://www.github.com/kadalu/moana
Source0:  moana-1.0.0.tar.gz

BuildRequires: libsqlite3x-devel openssl-devel

%description
Kadalu Storage Manager is a frontend for the Kadalu Storage.
    Moana provides tools for setting up and managing the Kadalu cluster.

%global debug_package %{nil}

%prep
mkdir -p %{buildroot}/usr/sbin/
mkdir -p %{buildroot}/lib/systemd/system/
%autosetup

%build
make build

%install
mkdir -p %{buildroot}/usr/sbin/
mkdir -p %{buildroot}/lib/systemd/system/
mkdir -p %{buildroot}/sbin/
mkdir -p %{buildroot}/usr/lib/python3/dist-packages/kadalu_storage

install -D mgr/bin/kadalu \
            %{buildroot}/usr/sbin/kadalu
install -D extra/mount.kadalu \
            %{buildroot}/sbin/mount.kadalu
install -m 700 -D  extra/kadalu-mgr.service \
           %{buildroot}/lib/systemd/system/kadalu-mgr.service

install -d sdk/python/kadalu_storage \
           %{buildroot}/usr/lib/python3/dist-packages/kadalu_storage

%files
%doc README.md
/usr/sbin/kadalu
/sbin/mount.kadalu
/lib/systemd/system/kadalu-mgr.service

%package -n python3-kadalu-storage
Summary:  Python4 Kadalu Storage
Requires: python3-urllib3
%description -n python3-kadalu-storage
Kadalu Storage Client is a SDK in Python for developers to
build tools atop Kadalu.
%files -n python3-kadalu-storage
/usr/lib/python3/dist-packages/kadalu_storage
