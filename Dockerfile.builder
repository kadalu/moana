FROM ubuntu:20.04

ARG branch="series_0"

ENV DEBIAN_FRONTEND=noninteractive
ENV VIRTUAL_ENV=/kadalu
ENV PATH="$VIRTUAL_ENV/bin:/opt/sbin:/opt/bin:$PATH"
RUN apt-get update -yq && \
    apt-get install -y --no-install-recommends python3 curl xfsprogs net-tools telnet wget e2fsprogs init \
    python3-pip sqlite build-essential g++ python3-dev flex bison openssl libssl-dev libtirpc-dev liburcu-dev \
    libfuse-dev libuuid1 python3-distutils uuid-dev acl-dev libtool automake autoconf git pkg-config \
    python3-venv libffi-dev && \
    git clone --depth 1 https://github.com/kadalu/glusterfs --branch ${branch} --single-branch glusterfs && \
    (cd glusterfs && ./autogen.sh && ./configure --prefix=/opt && make install && cd ..)

# Debugging, Comment the above line and
# uncomment below line
ENTRYPOINT ["tail", "-f", "/dev/null"]