#!/bin/bash -e
# mirrors scan-build job of .github/workflows/scan-build-complexity.yml
export CC=clang-15 CXX=clang++-15 VERSION=15
cd /w && bash -e deps-clang15.sh
git clone -q /src /w/libvmi && cd /w/libvmi
autoreconf -vif
scan-build-$VERSION --status-bugs -disable-checker deadcode.DeadStores ./configure CFLAGS=-DVMI_DEBUG=__VMI_DEBUG_ALL --enable-debug --disable-config-file
intercept-build-$VERSION make
analyze-build-$VERSION -v --cdb compile_commands.json --status-bugs --force-analyze-debug-code \
    --disable-checker deadcode.DeadStores \
    --enable-checker security.FloatLoopCounter \
    --enable-checker security.insecureAPI.strcpy
echo JOB_OK
