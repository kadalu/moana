FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -yq &&                                                 \
    apt-get install -y --no-install-recommends python3 libtirpc3 init     \
    vim python3-pip ssh rsync lvm2 less emacs software-properties-common  \
    sudo curl wget git build-essential automake autoconf automake libtool \
    flex bison libssl-dev pkg-config uuid-dev acl-dev zlib1g-dev          \
    libxml2-dev libxml2-utils liburcu-dev xfsprogs gdb attr               \
    libgoogle-perftools-dev zfsutils-linux screen libsqlite3-dev sqlite3

RUN echo "root:kadalu" | chpasswd

RUN sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config \
  && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/'       \
    /etc/ssh/sshd_config &&                                                   \
  sed -i.save -e "s#udev_sync = 1#udev_sync = 0#"                             \
    -e "s#udev_rules = 1#udev_rules = 0#"                                     \
    -e "s#use_lvmetad = 1#use_lvmetad = 0#"                                   \
    -e "s#obtain_device_list_from_udev = 1#obtain_device_list_from_udev = 0#" \
    /etc/lvm/lvm.conf &&                                                      \
  systemctl mask getty.target

RUN git clone https://github.com/gluster/glusterfs && \
    cd glusterfs && \
    ./autogen.sh && ./configure --disable-linux-io_uring && make && make install && ldconfig

RUN curl -fsSL https://github.com/kadalu/moana/releases/latest/download/kadalu-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o /tmp/kadalu
RUN curl -fsSL https://github.com/kadalu/moana/releases/latest/download/kadalu-mgr.service -o /tmp/kadalu-mgr.service
RUN curl -fsSL https://github.com/kadalu/moana/releases/latest/download/mount.kadalu -o /tmp/mount.kadalu

RUN install -m 600 /tmp/kadalu-mgr.service /lib/systemd/system/
RUN install /tmp/kadalu /usr/sbin/kadalu
RUN install /tmp/mount.kadalu /sbin/mount.kadalu

RUN systemctl enable kadalu-mgr

cmd ["/usr/sbin/init"]