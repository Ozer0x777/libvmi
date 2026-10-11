set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
# tools preinstalled on GitHub ubuntu runners (not in the workflow list): git autoconf automake libtool pkg-config
apt-get install -y git autoconf automake libtool pkg-config
# exact list from .github/workflows/compile.yml
apt-get install -y autoconf-archive flex bison libglib2.0-dev libjson-c-dev libxen-dev libvirt-dev libfuse-dev clang build-essential cmake
git clone --depth=2 https://github.com/libvmi/libkvmi
cd libkvmi && ./bootstrap && ./configure && make && make install && cd ..
