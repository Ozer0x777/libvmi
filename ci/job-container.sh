#!/bin/bash -e
# $1=compiler -- mirrors .github/workflows/container-compile.yml (debian:bookworm-slim)
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y autoconf-archive flex bison libjson-c-dev libxen-dev libvirt-dev libfuse-dev clang build-essential cmake git libtool autotools-dev libglib2.0-dev
apt-get clean
cd /w && git clone --depth=2 https://github.com/libvmi/libkvmi && cd libkvmi && ./bootstrap && ./configure && make && make install && cd .. && rm -rf libkvmi
git clone -q /src /w/libvmi && cd /w/libvmi
export CC=$1 CONTAINER=debian:bookworm-slim
while IFS= read -r options; do
  echo "Building with '$options'"
  autoreconf -vif; ./configure $options; make; make clean
  echo "Done building with '$options'"
done < .github/configure_options.txt
echo JOB_OK
