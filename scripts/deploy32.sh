#!/bin/bash
# rebuild /opt/libvmi-CR3-dbg from /root/libvmi-CR3 after the 32-bit patch, astyle check, then run the x86 matrix
L=/root/w10builds/x86/deploy32.log; : > $L
say(){ echo "$(date +%F\ %T) $*" | tee -a $L; }
cd /root/libvmi-CR3 || exit 1
P=$(grep -m1 CMAKE_INSTALL_PREFIX build/CMakeCache.txt | cut -d= -f2); say "prefix=$P"
[ "$P" = /opt/libvmi-CR3-dbg ] || { say "unexpected prefix, abort"; exit 1; }
cp -a /opt/libvmi-CR3-dbg/lib/libvmi.so.0.0.15 /opt/libvmi-CR3-dbg/lib/libvmi.so.0.0.15.before-32bit
# astyle check, same options as the repo workflow, on copies
rm -rf /tmp/astyle32 && mkdir -p /tmp/astyle32 && cp libvmi/os/windows/{core.c,kdbg.c,windows.h} /tmp/astyle32/
(cd /tmp/astyle32 && astyle --options=/root/libvmi-CR3/.astylerc -n core.c kdbg.c windows.h >/dev/null 2>&1)
for f in core.c kdbg.c windows.h; do cmp -s libvmi/os/windows/$f /tmp/astyle32/$f && say "astyle $f OK" || { say "astyle $f DIFF"; diff libvmi/os/windows/$f /tmp/astyle32/$f | head -20 >> $L; }; done
cmake --build build -j8 > /root/w10builds/x86/build32.log 2>&1 && say "build OK" || { say "BUILD FAILED"; tail -30 /root/w10builds/x86/build32.log >> $L; exit 1; }
grep -i "warning" /root/w10builds/x86/build32.log | grep -i "windows/" | head -5 >> $L
cmake --install build > /root/w10builds/x86/install32.log 2>&1 && say "install OK" || { say "INSTALL FAILED"; exit 1; }
ls -la /opt/libvmi-CR3-dbg/lib/libvmi.so.0.0.15 >> $L
mv /root/w10builds/x86/attach /root/w10builds/x86/attach-before-32bit-fix 2>/dev/null
cd /root/kdbg-study && ./x86test.sh > x86test3.nohup 2>&1
say "x86test done"
