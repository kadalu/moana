FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -yq && \
    apt-get install -y software-properties-common

RUN add-apt-repository -y ppa:gluster/glusterfs-8 && \
    apt-get update -yq && \
    apt-get install -y --no-install-recommends python3 libtirpc3 init vim python3-pip ssh rsync lvm2 less emacs sudo curl wget glusterfs-server nfs-ganesha-gluster glusterfs-client nfs-common git libsqlite3-dev sqlite3

RUN echo "root:kadalu" | chpasswd

RUN sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i.save -e "s#udev_sync = 1#udev_sync = 0#" -e "s#udev_rules = 1#udev_rules = 0#" -e "s#use_lvmetad = 1#use_lvmetad = 0#" -e "s#obtain_device_list_from_udev = 1#obtain_device_list_from_udev = 0#" /etc/lvm/lvm.conf && \
    systemctl mask getty.target

RUN curl -fsSL https://crystal-lang.org/install.sh | bash

CMD ["/usr/sbin/init"]