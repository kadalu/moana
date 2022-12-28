FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -yq &&                                                     \
    apt-get install -y --no-install-recommends lvm2 curl attr sqlite3 ca-certificates gnupg2 supervisor

RUN sed -i.save -e "s#udev_sync = 1#udev_sync = 0#"                           \
    -e "s#udev_rules = 1#udev_rules = 0#"                                     \
    -e "s#use_lvmetad = 1#use_lvmetad = 0#"                                   \
    -e "s#obtain_device_list_from_udev = 1#obtain_device_list_from_udev = 0#" \
    /etc/lvm/lvm.conf

RUN echo 'deb https://kadalu.tech/pkgs/1.0.x/ubuntu/22.04 /' | tee /etc/apt/sources.list.d/kadalu.list
RUN curl -fsSL https://kadalu.tech/pkgs/1.0.x/ubuntu/22.04/KEY.gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/kadalu.gpg > /dev/null
RUN apt-get update -yq && apt-get install -y kadalu-storage

COPY container/supervisord.conf /etc/supervisor/conf.d/

ENTRYPOINT ["/usr/bin/supervisord"]
EXPOSE 3000