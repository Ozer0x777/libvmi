set -e
export DEBIAN_FRONTEND=noninteractive VERSION=15
apt-get update -q
apt-get install -y git autoconf automake libtool pkg-config make
apt-get install -y clang-$VERSION clang-tools-$VERSION clang-tidy-$VERSION autoconf-archive flex bison libglib2.0-dev libjson-c-dev libxen-dev libvirt-dev libfuse-dev
git clone --depth=2 https://github.com/libvmi/libkvmi
cd libkvmi && ./bootstrap && ./configure && make && make install && cd ..
