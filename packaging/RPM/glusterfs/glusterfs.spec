%global _hardened_build 1

%global _for_fedora_koji_builds 0

%define _unpackaged_files_terminate_build 0

# uncomment and add '%' to use the prereltag for pre-releases
# %%global prereltag qa3

##-----------------------------------------------------------------------------
## All argument definitions should be placed here and keep them sorted
##

# asan
# if you wish to compile an rpm with address sanitizer...
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --with asan
%{?_with_asan:%global _with_asan --enable-asan}

%if ( 0%{?rhel} && 0%{?rhel} < 7 )
%global _with_asan %{nil}
%endif

# cmocka
# if you wish to compile an rpm with cmocka unit testing...
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --with cmocka
%{?_with_cmocka:%global _with_cmocka --enable-cmocka}

# debug
# if you wish to compile an rpm with debugging...
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --with debug
%{?_with_debug:%global _with_debug --enable-debug}

# epoll
# if you wish to compile an rpm without epoll...
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --without epoll
%{?_without_epoll:%global _without_epoll --disable-epoll}

# fusermount
# if you wish to compile an rpm without fusermount...
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --without fusermount
%{?_without_fusermount:%global _without_fusermount --disable-fusermount}

# geo-rep
# if you wish to compile an rpm without geo-replication support, compile like this...
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --without georeplication
%{?_without_georeplication:%global _without_georeplication --disable-georeplication}

# gnfs
# if you wish to compile an rpm with the legacy gNFS server xlator
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --with gnfs
%{?_with_gnfs:%global _with_gnfs --enable-gnfs}

# ipv6default
# if you wish to compile an rpm with IPv6 default...
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --with ipv6default
%{?_with_ipv6default:%global _with_ipv6default --with-ipv6-default}

# linux-io_uring
# If you wish to compile an rpm without linux-io_uring support...
# rpmbuild -ta  glusterfs-2022.08.01.tar.gz --without linux-io_uring
%{?_without_linux_io_uring:%global _without_linux_io_uring --disable-linux-io_uring}

# Disable linux-io_uring on unsupported distros.
%if ( 0%{?fedora} && 0%{?fedora} <= 32 ) || ( 0%{?rhel} && 0%{?rhel} <= 7 )
%global _without_linux_io_uring --disable-linux-io_uring
%endif

# libtirpc
# if you wish to compile an rpm without TIRPC (i.e. use legacy glibc rpc)
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --without libtirpc
%{?_without_libtirpc:%global _without_libtirpc --without-libtirpc}

# libtcmalloc
# if you wish to compile an rpm without tcmalloc (i.e. use gluster mempool)
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --without tcmalloc
%{?_without_tcmalloc:%global _without_tcmalloc --without-tcmalloc}

%ifnarch x86_64
%global _without_tcmalloc --without-tcmalloc
%endif

# Do not use libtirpc on EL6, it does not have xdr_uint64_t() and xdr_uint32_t
# Do not use libtirpc on EL7, it does not have xdr_sizeof()
%if ( 0%{?rhel} && 0%{?rhel} <= 7 )
%global _without_libtirpc --without-libtirpc
%endif


# ocf
# if you wish to compile an rpm without the OCF resource agents...
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --without ocf
%{?_without_ocf:%global _without_ocf --without-ocf}

# server
# if you wish to build rpms without server components, compile like this
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --without server
%{?_without_server:%global _without_server --without-server}

# disable server components forcefully as rhel <= 6
%if ( 0%{?rhel} && 0%{?rhel} <= 6 )
%global _without_server --without-server
%endif

# syslog
# if you wish to build rpms without syslog logging, compile like this
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --without syslog
%{?_without_syslog:%global _without_syslog --disable-syslog}

# disable syslog forcefully as rhel <= 6 doesn't have rsyslog or rsyslog-mmcount
# Fedora deprecated syslog, see
#  https://fedoraproject.org/wiki/Changes/NoDefaultSyslog
# (And what about RHEL7?)
%if ( 0%{?fedora} && 0%{?fedora} >= 20 ) || ( 0%{?rhel} && 0%{?rhel} <= 6 )
%global _without_syslog --disable-syslog
%endif

# tsan
# if you wish to compile an rpm with thread sanitizer...
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --with tsan
%{?_with_tsan:%global _with_tsan --enable-tsan}

%if ( 0%{?rhel} && 0%{?rhel} < 7 )
%global _with_tsan %{nil}
%endif

# valgrind
# if you wish to compile an rpm to run all processes under valgrind...
# rpmbuild -ta glusterfs-2022.08.01.tar.gz --with valgrind
%{?_with_valgrind:%global _with_valgrind --enable-valgrind}

##-----------------------------------------------------------------------------
## All %%global definitions should be placed here and keep them sorted
##

# selinux booleans whose defalut value needs modification
# these booleans will be consumed by "%%selinux_set_booleans" macro.
%if ( 0%{?rhel} && 0%{?rhel} >= 8 )
%global selinuxbooleans rsync_full_access=1 rsync_client=1
%endif

%if ( 0%{?fedora} ) || ( 0%{?rhel} && 0%{?rhel} > 6 )
%global _with_systemd true
%endif

%if ( 0%{?fedora} ) || ( 0%{?rhel} && 0%{?rhel} >= 7 )
%global _with_firewalld --enable-firewalld
%endif

%if 0%{?_tmpfilesdir:1}
%global _with_tmpfilesdir --with-tmpfilesdir=%{_tmpfilesdir}
%else
%global _with_tmpfilesdir --without-tmpfilesdir
%endif

# without server should also disable some server-only components
%if 0%{?_without_server:1}
%global _without_events --disable-events
%global _without_georeplication --disable-georeplication
%global _without_linux_io_uring --disable-linux-io_uring
%global _with_gnfs %{nil}
%global _without_ocf --without-ocf
%endif

%if ( 0%{?fedora} ) || ( 0%{?rhel} && 0%{?rhel} > 7 )
%global _usepython3 1
%global _pythonver 3
%else
%global _usepython3 0
%global _pythonver 2
%endif

# From https://fedoraproject.org/wiki/Packaging:Python#Macros
%if ( 0%{?rhel} && 0%{?rhel} <= 6 )
%{!?python2_sitelib: %global python2_sitelib %(python2 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")}
%{!?python2_sitearch: %global python2_sitearch %(python2 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib(1))")}
%global _rundir %{_localstatedir}/run
%endif

%if ( 0%{?_with_systemd:1} )
%global service_start()   /bin/systemctl --quiet start %1.service || : \
%{nil}
%global service_stop()    /bin/systemctl --quiet stop %1.service || :\
%{nil}
%global service_install() install -D -p -m 0644 %1.service %{buildroot}%2 \
%{nil}
# can't seem to make a generic macro that works
%global glusterfsd_svcfile %{_unitdir}/glusterfsd.service
%global glusterta_svcfile %{_unitdir}/gluster-ta-volume.service
%global glustereventsd_svcfile %{_unitdir}/glustereventsd.service
%global glusterfssharedstorage_svcfile %{_unitdir}/glusterfssharedstorage.service
%else
%global systemd_post()  /sbin/chkconfig --add %1 >/dev/null 2>&1 || : \
%{nil}
%global systemd_preun() /sbin/chkconfig --del %1 >/dev/null 2>&1 || : \
%{nil}
%global systemd_postun_with_restart() /sbin/service %1 condrestart >/dev/null 2>&1 || : \
%{nil}
%global service_start()   /sbin/service %1 start >/dev/null 2>&1 || : \
%{nil}
%global service_stop()    /sbin/service %1 stop >/dev/null 2>&1 || : \
%{nil}
%global service_install() install -D -p -m 0755 %1.init %{buildroot}%2 \
%{nil}
# can't seem to make a generic macro that works
%global glusterfsd_svcfile %{_sysconfdir}/init.d/glusterfsd
%global glustereventsd_svcfile %{_sysconfdir}/init.d/glustereventsd
%endif

%{!?_pkgdocdir: %global _pkgdocdir %{_docdir}/%{name}-%{version}}

# We do not want to generate useless provides and requires for xlator
# .so files to be set for glusterfs packages.
# Filter all generated:
#
# TODO: RHEL5 does not have a convenient solution
%if ( 0%{?rhel} == 6 )
# filter_setup exists in RHEL6 only
%filter_provides_in %{_libdir}/glusterfs/%{version}/
%global __filter_from_req %{?__filter_from_req} | grep -v -P '^(?!lib).*\.so.*$'
%filter_setup
%else
# modern rpm and current Fedora do not generate requires when the
# provides are filtered
%global __provides_exclude_from ^%{_libdir}/glusterfs/%{version}/.*$
%endif


##-----------------------------------------------------------------------------
## All package definitions should be placed here in alphabetical order
##
Summary:          Distributed File System
Name:             glusterfs
Version:          2022.08.01
Release:          0.19.4718%{?dist}
License:          GPLv2 or LGPLv3+
URL:              http://github.com/kadalu/glusterfs
Source0:          glusterfs-2022.08.01.tar.gz

BuildRoot:        %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Requires(pre):    shadow-utils
%if ( 0%{?_with_systemd:1} )
BuildRequires:    systemd
%endif

%if ( 0%{!?_without_tcmalloc:1} )
Requires:         gperftools-libs%{?_isa}
%endif

Requires:         libglusterfs0%{?_isa} = %{version}-%{release}
Requires:         libgfrpc0%{?_isa} = %{version}-%{release}
Requires:         libgfxdr0%{?_isa} = %{version}-%{release}
%if ( 0%{?_with_systemd:1} )
%{?systemd_requires}
%endif
%if 0%{?_with_asan:1} && !( 0%{?rhel} && 0%{?rhel} < 7 )
BuildRequires:    libasan
%endif
%if 0%{?_with_tsan:1} && !( 0%{?rhel} && 0%{?rhel} < 7 )
BuildRequires:    libtsan
%endif
BuildRequires:    bison flex
BuildRequires:    gcc make libtool
BuildRequires:    ncurses-devel readline-devel
BuildRequires:    libxml2-devel openssl-devel openssl
BuildRequires:    libaio-devel libacl-devel
BuildRequires:    python%{_pythonver}-devel
%if ( 0%{!?_without_tcmalloc:1} )
BuildRequires:    gperftools-devel
%endif
%if ( 0%{?rhel} && 0%{?rhel} < 8 )
BuildRequires:    python-ctypes
%endif
%if ( 0%{?_with_ipv6default:1} ) || ( 0%{!?_without_libtirpc:1} )
BuildRequires:    libtirpc-devel
%endif
%if ( 0%{?fedora} && 0%{?fedora} > 27 ) || ( 0%{?rhel} && 0%{?rhel} > 7 )
BuildRequires:    rpcgen
%endif
BuildRequires:    userspace-rcu-devel >= 0.7
%if ( 0%{?rhel} && 0%{?rhel} <= 6 )
BuildRequires:    automake
%endif
BuildRequires:    libuuid-devel
%if ( 0%{?_with_cmocka:1} )
BuildRequires:    libcmocka-devel >= 1.0.1
%endif
%if ( 0%{!?_without_georeplication:1} )
BuildRequires:    libattr-devel
%endif

%if (0%{?_with_firewalld:1})
BuildRequires:    firewalld
%endif

%if ( 0%{!?_without_linux_io_uring:1} )
BuildRequires:    liburing-devel
%endif

Obsoletes:        %{name}-common < %{version}-%{release}
Obsoletes:        %{name}-core < %{version}-%{release}
Obsoletes:        %{name}-rdma < %{version}-%{release}
%if ( 0%{!?_with_gnfs:1} )
Obsoletes:        %{name}-gnfs < %{version}-%{release}
%endif
Provides:         %{name}-common = %{version}-%{release}
Provides:         %{name}-core = %{version}-%{release}

%description
GlusterFS is a distributed file-system capable of scaling to several
petabytes. It aggregates various storage bricks over TCP/IP interconnect
into one large parallel network filesystem. GlusterFS is one of the
most sophisticated file systems in terms of features and extensibility.
It borrows a powerful concept called Translators from GNU Hurd kernel.
Much of the code in GlusterFS is in user space and easily manageable.

This package includes the glusterfs binary, the glusterfsd daemon and the
libglusterfs and glusterfs translator modules common to both GlusterFS server
and client framework.

%if ( 0%{?fedora} && 0%{?fedora} > 25  || ( 0%{?rhel} && 0%{?rhel} > 6 ) )
%if ( 0%{?rhel} && 0%{?rhel} < 8 )
Requires: selinux-policy >= 3.13.1-160
Requires(post):   policycoreutils-python
Requires(postun): policycoreutils-python
%else
Requires(post):   policycoreutils-python-utils
Requires(postun): policycoreutils-python-utils
%endif
%endif

%prep
%setup -q -n %{name}-%{version}%{?prereltag}
%if ( ! %{_usepython3} )
echo "fixing python shebangs..."
for f in api events extras geo-replication libglusterfs tools xlators; do
find $f -type f -exec sed -i 's|/usr/bin/python3|/usr/bin/python2|' {} \;
done
%endif

%build

# RHEL6 and earlier need to manually replace config.guess and config.sub
%if ( 0%{?rhel} && 0%{?rhel} <= 6 )
./autogen.sh
%endif

%configure \
        %{?_with_asan} \
        %{?_with_cmocka} \
        %{?_with_debug} \
        %{?_with_firewalld} \
        %{?_with_gnfs} \
        %{?_with_tmpfilesdir} \
        %{?_with_tsan} \
        %{?_with_valgrind} \
        %{?_without_epoll} \
        %{?_without_events} \
        %{?_without_fusermount} \
        %{?_without_georeplication} \
        %{?_without_ocf} \
        %{?_without_server} \
        %{?_without_syslog} \
        %{?_with_ipv6default} \
        %{?_without_linux_io_uring} \
        %{?_without_libtirpc} \
        %{?_without_tcmalloc}

# fix hardening and remove rpath in shlibs
%if ( 0%{?fedora} && 0%{?fedora} > 17 ) || ( 0%{?rhel} && 0%{?rhel} > 6 )
sed -i 's| \\\$compiler_flags |&\\\$LDFLAGS |' libtool
%endif
sed -i 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|' libtool
sed -i 's|^runpath_var=LD_RUN_PATH|runpath_var=DIE_RPATH_DIE|' libtool

make %{?_smp_mflags}

%check
make check

%install
rm -rf %{buildroot}
make install DESTDIR=%{buildroot}

mkdir -p %{buildroot}%{_localstatedir}/log/glusterfs
mkdir -p %{buildroot}%{_localstatedir}/log/glusterfsd
mkdir -p %{buildroot}%{_rundir}/gluster

# Remove unwanted files from all the shared libraries
find %{buildroot}%{_libdir} -name '*.a' -delete
find %{buildroot}%{_libdir} -name '*.la' -delete

# Remove installed docs, the ones we want are included by %%doc, in
# /usr/share/doc/glusterfs or /usr/share/doc/glusterfs-x.y.z depending
# on the distribution
%if ( 0%{?fedora} && 0%{?fedora} > 19 ) || ( 0%{?rhel} && 0%{?rhel} > 6 )
rm -rf %{buildroot}%{_pkgdocdir}/*
%else
rm -rf %{buildroot}%{_defaultdocdir}/%{name}
mkdir -p %{buildroot}%{_pkgdocdir}
%endif
head -50 ChangeLog > ChangeLog.head && mv ChangeLog.head ChangeLog
cat << EOM >> ChangeLog

More commit messages for this ChangeLog can be found at
https://forge.gluster.org/glusterfs-core/glusterfs/commits/v%{version}%{?prereltag}
EOM

# Remove benchmarking and other unpackaged files
# make install always puts these in %%{_defaultdocdir}/%%{name} so don't
# use %%{_pkgdocdir}; that will be wrong on later Fedora distributions
rm -rf %{buildroot}%{_defaultdocdir}/%{name}/benchmarking
rm -f %{buildroot}%{_defaultdocdir}/%{name}/glusterfs-mode.el
rm -f %{buildroot}%{_defaultdocdir}/%{name}/glusterfs.vim

install -D -p -m 0644 extras/glusterfs-logrotate \
    %{buildroot}%{_sysconfdir}/logrotate.d/glusterfs

find ./tests ./run-tests.sh -type f | cpio -pd %{buildroot}%{_prefix}/share/glusterfs

## Install bash completion for cli
install -p -m 0744 -D extras/command-completion/gluster.bash \
    %{buildroot}%{_sysconfdir}/bash_completion.d/gluster

%clean
rm -rf %{buildroot}

##-----------------------------------------------------------------------------
## All %%post should be placed here and keep them sorted
##
%post
/sbin/ldconfig
%if ( 0%{!?_without_syslog:1} )
%if ( 0%{?fedora} ) || ( 0%{?rhel} && 0%{?rhel} >= 6 )
%systemd_postun_with_restart rsyslog
%endif
%endif
exit 0

%systemd_post glustereventsd

/sbin/ldconfig

/sbin/ldconfig

/sbin/ldconfig

/sbin/ldconfig

/sbin/ldconfig


%if ( 0%{_for_fedora_koji_builds} )
%systemd_post glusterfsd
%endif
# ".cmd_log_history" is renamed to "cmd_history.log" in GlusterFS-3.7 .
# While upgrading glusterfs-server package form GlusterFS version <= 3.6 to
# GlusterFS version 3.7, ".cmd_log_history" should be renamed to
# "cmd_history.log" to retain cli command history contents.
if [ -f %{_localstatedir}/log/glusterfs/.cmd_log_history ]; then
    mv %{_localstatedir}/log/glusterfs/.cmd_log_history \
       %{_localstatedir}/log/glusterfs/cmd_history.log
fi

# add marker translator
# but first make certain that there are no old libs around to bite us
# BZ 834847
if [ -e /etc/ld.so.conf.d/glusterfs.conf ]; then
    rm -f /etc/ld.so.conf.d/glusterfs.conf
    /sbin/ldconfig
fi

%if (0%{?_with_firewalld:1})
    %firewalld_reload
%endif

exit 0

##-----------------------------------------------------------------------------
## All %%pre should be placed here and keep them sorted
##
%pre
getent group gluster > /dev/null || groupadd -r gluster
getent passwd gluster > /dev/null || useradd -r -g gluster -d %{_rundir}/gluster -s /sbin/nologin -c "GlusterFS daemons" gluster
exit 0

##-----------------------------------------------------------------------------
## All %%preun should be placed here and keep them sorted
##

##-----------------------------------------------------------------------------
## All %%postun should be placed here and keep them sorted
##






##-----------------------------------------------------------------------------
## All %%trigger should be placed here and keep them sorted
##

##-----------------------------------------------------------------------------
## All %%files should be placed here and keep them grouped
##
%files
%doc ChangeLog COPYING-GPLV2 COPYING-LGPLV3 INSTALL README.md THANKS COMMITMENT
%{_mandir}/man8/*gluster*.8*
%if ( 0%{!?_without_server:1} )
%exclude %{_mandir}/man8/gluster.8*
%endif
%dir %{_localstatedir}/log/glusterfs
%if 0%{?!_without_server:1}
%dir %{_datadir}/glusterfs
%dir %{_datadir}/glusterfs/scripts
     %{_datadir}/glusterfs/scripts/post-upgrade-script-for-quota.sh
     %{_datadir}/glusterfs/scripts/pre-upgrade-script-for-quota.sh
%endif
# xlators that are needed on the client- and on the server-side
%dir %{_libdir}/glusterfs
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/auth
     %{_libdir}/glusterfs/%{version}%{?prereltag}/auth/addr.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/auth/login.so
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/rpc-transport
     %{_libdir}/glusterfs/%{version}%{?prereltag}/rpc-transport/socket.so
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/debug
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/debug/error-gen.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/debug/delay-gen.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/debug/io-stats.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/debug/sink.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/debug/trace.so
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/access-control.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/barrier.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/cdc.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/changelog.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/utime.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/gfid-access.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/namespace.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/read-only.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/shard.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/snapview-client.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/worm.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/cloudsync.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/meta.so
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/performance
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/performance/io-cache.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/performance/io-threads.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/performance/md-cache.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/performance/open-behind.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/performance/quick-read.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/performance/read-ahead.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/performance/readdir-ahead.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/performance/stat-prefetch.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/performance/write-behind.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/performance/nl-cache.so
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/system
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/system/posix-acl.so
%dir %attr(0775,gluster,gluster) %{_rundir}/gluster
%if 0%{?_tmpfilesdir:1}
%{_tmpfilesdir}/gluster.conf
%endif

%{_sbindir}/gluster
%{_mandir}/man8/gluster.8*
%{_sysconfdir}/bash_completion.d/gluster

%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/cloudsync-plugins
     %{_libdir}/glusterfs/%{version}%{?prereltag}/cloudsync-plugins/cloudsyncs3.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/cloudsync-plugins/cloudsynccvlt.so

%dir %{_includedir}/glusterfs
     %{_includedir}/glusterfs/*.h
     %{_includedir}/glusterfs/server/*.h
%{_libdir}/libglusterfs.so

%dir %{_includedir}/glusterfs/api
     %{_includedir}/glusterfs/api/*.h
%{_libdir}/libgfapi.so
%{_libdir}/pkgconfig/glusterfs-api.pc

%dir %{_includedir}/glusterfs/gfchangelog
     %{_includedir}/glusterfs/gfchangelog/*.h
%{_libdir}/libgfchangelog.so
%{_libdir}/pkgconfig/libgfchangelog.pc

%dir %{_includedir}/glusterfs/rpc
     %{_includedir}/glusterfs/rpc/*.h
%{_libdir}/libgfrpc.so

%{_libdir}/libgfxdr.so

%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/cluster
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/cluster/*.so
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/protocol
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/protocol/client.so

%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/quiesce.so
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/playground
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/playground/template.so

# glusterfs is a symlink to glusterfsd, -server depends on -fuse.
%{_sbindir}/glusterfs
%{_sbindir}/glusterfsd
%config(noreplace) %{_sysconfdir}/logrotate.d/glusterfs
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/mount
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/mount/fuse.so
/sbin/mount.glusterfs
%if ( 0%{!?_without_fusermount:1} )
%{_bindir}/fusermount-glusterfs
%endif

%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/thin-arbiter.so
%dir %{_datadir}/glusterfs/scripts
     %{_datadir}/glusterfs/scripts/setup-thin-arbiter.sh
%config %{_sysconfdir}/glusterfs/thin-arbiter.vol

%if ( 0%{?_with_systemd:1} )
%{_unitdir}/gluster-ta-volume.service
%endif




%{_sbindir}/gfind_missing_files
%{_sbindir}/gluster-mountbroker
%dir %{_libexecdir}/glusterfs
%dir %{_libexecdir}/glusterfs/python
%dir %{_libexecdir}/glusterfs/python/syncdaemon
     %{_libexecdir}/glusterfs/gsyncd
     %{_libexecdir}/glusterfs/python/syncdaemon/*
%dir %{_libexecdir}/glusterfs/scripts
     %{_libexecdir}/glusterfs/scripts/get-gfid.sh
     %{_libexecdir}/glusterfs/scripts/secondary-upgrade.sh
     %{_libexecdir}/glusterfs/scripts/gsync-upgrade.sh
     %{_libexecdir}/glusterfs/scripts/generate-gfid-file.sh
     %{_libexecdir}/glusterfs/scripts/gsync-sync-gfid
     %{_libexecdir}/glusterfs/scripts/schedule_georep.py*
     %{_libexecdir}/glusterfs/gverify.sh
     %{_libexecdir}/glusterfs/set_geo_rep_pem_keys.sh
     %{_libexecdir}/glusterfs/peer_gsec_create
     %{_libexecdir}/glusterfs/peer_mountbroker
     %{_libexecdir}/glusterfs/peer_mountbroker.py*
     %{_libexecdir}/glusterfs/gfind_missing_files
     %{_libexecdir}/glusterfs/peer_georep-sshkey.py*
%{_sbindir}/gluster-georep-sshkey

%{_libdir}/libglusterfs.so.*

%{_libdir}/libgfapi.so.*
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/mount
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/mount/api.so

%{_libdir}/libgfchangelog.so.*

%{_libdir}/libgfrpc.so.*

%{_libdir}/libgfxdr.so.*

# introducing glusterfs module in site packages.
# so that all other gluster submodules can reside in the same namespace.
%if ( %{_usepython3} )
%dir %{python3_sitelib}/gluster
     %{python3_sitelib}/gluster/__init__.*
     %{python3_sitelib}/gluster/__pycache__
     %{python3_sitelib}/gluster/cliutils
%else
%dir %{python2_sitelib}/gluster
     %{python2_sitelib}/gluster/__init__.*
     %{python2_sitelib}/gluster/cliutils
%endif

%if ( 0%{!?_without_ocf:1} )
# /usr/lib is the standard for OCF, also on x86_64
%{_prefix}/lib/ocf/resource.d/glusterfs
%endif

%if ( 0%{!?_without_server:1} )
%doc extras/clear_xattrs.sh
# sysconf
%config(noreplace) %{_sysconfdir}/glusterfs
%exclude %{_sysconfdir}/glusterfs/thin-arbiter.vol
%exclude %{_sysconfdir}/glusterfs/eventsconfig.json
%if ( 0%{?_with_gnfs:1} )
%exclude %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/nfs/*
%endif
%if ( 0%{_for_fedora_koji_builds} )
%config(noreplace) %{_sysconfdir}/sysconfig/glusterfsd
%endif

# init files

%if ( 0%{_for_fedora_koji_builds} )
%glusterfsd_svcfile
%endif
%if ( 0%{?_with_systemd:1} )
%glusterfssharedstorage_svcfile
%endif

# binaries
%{_libexecdir}/glusterfs/glfsheal
%{_sbindir}/gf_attach
%{_sbindir}/gluster-setgfid2path
# {_sbindir}/glusterfsd is the actual binary, but glusterfs (client) is a
# symlink. The binary itself (and symlink) are part of the glusterfs-fuse
# package, because glusterfs-server depends on that anyway.

# Manpages
%{_mandir}/man8/gluster-setgfid2path.8*

# xlators
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/arbiter.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/bit-rot.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/bitrot-stub.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/sdfs.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/index.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/locks.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/posix*
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/snapview-server.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/marker.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/simple-quota.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/quota*
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/selinux.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/trash.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/upcall.so
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/features/leases.so
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/mgmt
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/protocol
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/protocol/server.so
%dir %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/storage
     %{_libdir}/glusterfs/%{version}%{?prereltag}/xlator/storage/posix.so

# snap_scheduler
%{_sbindir}/snap_scheduler.py
%{_sbindir}/gcron.py
%{_sbindir}/conf.py
# Extra utility script
%dir %{_libexecdir}/glusterfs
%dir %{_datadir}/glusterfs/scripts
     %{_datadir}/glusterfs/scripts/stop-all-gluster-processes.sh
%if ( 0%{?_with_systemd:1} )
     %{_libexecdir}/glusterfs/mount-shared-storage.sh
     %{_datadir}/glusterfs/scripts/control-cpu-load.sh
     %{_datadir}/glusterfs/scripts/control-mem.sh
%endif

# Incrementalapi
     %{_libexecdir}/glusterfs/glusterfind
%{_bindir}/glusterfind
     %{_libexecdir}/glusterfs/peer_add_secret_pub

%if ( 0%{?_with_firewalld:1} )
%{_prefix}/lib/firewalld/services/glusterfs.xml
%endif
# end of server files
%endif

# Events
%if ( 0%{!?_without_events:1} )

%config(noreplace) %{_sysconfdir}/glusterfs/eventsconfig.json
%dir %{_libexecdir}/glusterfs
     %{_libexecdir}/glusterfs/gfevents
     %{_libexecdir}/glusterfs/peer_eventsapi.py*
%{_sbindir}/glustereventsd
%{_sbindir}/gluster-eventsapi
%{_datadir}/glusterfs/scripts/eventsdash.py*
%if ( 0%{?_with_systemd:1} )
%{_unitdir}/glustereventsd.service
%else
%{_sysconfdir}/init.d/glustereventsd
%endif
%endif

%changelog

* Mon Sep 19 2022 Kadalu Technologies Pvt Limited <packaging@kadalu.tech>
- Initial spec file

