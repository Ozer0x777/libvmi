#!/bin/bash
# throw-away build (NOT part of the PR): find_kernel_vcpu treats the first $KDBG_FORCE_USER_SAMPLES samples as "all vCPUs in user mode"
set -e; L=/root/w10builds/wsrv/force-build.log; : > $L
rm -rf /root/libvmi-force && cp -a /root/libvmi-CR3 /root/libvmi-force && cd /root/libvmi-force
python3 - <<'P'
p="libvmi/os/windows/kdbg.c"; s=open(p).read()
old="""        for (unsigned int v = 0; v < n; v++) {
            reg_t rip = 0;
            if (VMI_FAILURE == driver_get_vcpureg(vmi, &rip, RIP, v))
                continue;"""
new="""        const char *force = getenv("KDBG_FORCE_USER_SAMPLES");
        if (force && sample < (unsigned int)atoi(force)) {
            dbprint(VMI_DEBUG_MISC, "**FORCED: sample %u treated as all vCPUs in user mode\\n", sample);
            continue;
        }
        for (unsigned int v = 0; v < n; v++) {
            reg_t rip = 0;
            if (VMI_FAILURE == driver_get_vcpureg(vmi, &rip, RIP, v))
                continue;"""
assert s.count(old)==1; s=s.replace(old,new); s=s.replace("#include <unistd.h>\n","#include <unistd.h>\n#include <stdlib.h>\n",1); open(p,"w").write(s); print("hack applied")
P
rm -rf build && mkdir build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/opt/libvmi-CR3-force -DVMI_DEBUG=__VMI_DEBUG_ALL -DENABLE_KVM=OFF -DENABLE_KVM_LEGACY=OFF -DENABLE_TESTING=OFF -DENABLE_VMIFS=OFF > /dev/null 2>&1 && cmake --build . -j8 > /root/w10builds/wsrv/force-build-make.log 2>&1 && cmake --install . > /dev/null 2>&1 && echo "force lib built" | tee -a $L
cd /root/kdbg-study && gcc -O1 -g -o nojson2-CR3-force nojson2.c $(pkg-config --cflags --libs glib-2.0) -I/opt/libvmi-CR3-force/include -L/opt/libvmi-CR3-force/lib -Wl,-rpath,/opt/libvmi-CR3-force/lib -lvmi && echo "nojson2-CR3-force built" | tee -a $L
