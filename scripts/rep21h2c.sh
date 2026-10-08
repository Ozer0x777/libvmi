#!/bin/bash
# Final validation of libvmi 3a74d10 (decoder + non-contiguous kernel), one VM at a time.
# usage: all-nc.sh   -> /root/kdbg-study/nc-all/summary.txt  (ends with ALLDONE)
cd /root/kdbg-study; R=/root/kdbg-study/rep21h2-cr3; mkdir -p $R; S=$R/summary.txt; : > $S
log(){ echo "$(date +%T) $*" | tee -a $S; }
stopvm(){ local i; xl list "$1" >/dev/null 2>&1 || return 0; timeout 150 xl shutdown -F -w "$1" >/dev/null 2>&1
  for i in $(seq 1 30); do xl list "$1" >/dev/null 2>&1 || { echo clean; return 0; }; sleep 2; done; xl destroy "$1"; echo destroyed; }

# build the ASan variant and the JSON probe against the same tree as nojson-CR3-dbg
if [ ! -x nojson-NC-asan ]; then
  cd /root/libvmi-NC && rm -rf build-asan && mkdir build-asan && cd build-asan
  cmake .. -DCMAKE_BUILD_TYPE=Debug -DVMI_DEBUG=__VMI_DEBUG_ALL -DCMAKE_INSTALL_PREFIX=/opt/libvmi-NC-asan \
    -DCMAKE_C_FLAGS="-fsanitize=address -fno-omit-frame-pointer" -DCMAKE_SHARED_LINKER_FLAGS="-fsanitize=address" >/dev/null 2>&1 || { log CMAKE_ASAN_FAIL; exit 1; }
  make -j8 >/dev/null 2>&1; make install >/dev/null 2>&1
  cd /root/kdbg-study
  gcc -O1 -g -fsanitize=address -o nojson-NC-asan nojson.c $(pkg-config --cflags --libs glib-2.0) -I/opt/libvmi-NC-asan/include -L/opt/libvmi-NC-asan/lib -Wl,-rpath,/opt/libvmi-NC-asan/lib -lvmi || { log ASAN_BUILD_FAIL; exit 1; }
fi
gcc -O1 -o jsonsym-NC jsonsym.c $(pkg-config --cflags --libs glib-2.0) -I/opt/libvmi-NC-dbg/include -L/opt/libvmi-NC-dbg/lib -Wl,-rpath,/opt/libvmi-NC-dbg/lib -lvmi || { log JSON_BUILD_FAIL; exit 1; }
log "tools built; libvmi tree: $(cd /root/libvmi-K-ci && git log --oneline -1)"

offs(){ python3 - "$1" <<'PY'
import json,sys
ut=json.load(open(sys.argv[1]))["user_types"]
f=lambda t,n: ut[t]["fields"][n]["offset"]
print("%x %x %x %x"%(f("_EPROCESS","ActiveProcessLinks"),f("_EPROCESS","UniqueProcessId"),f("_EPROCESS","ImageFileName"),f("_KPROCESS","DirectoryTableBase")))
PY
}

# boot_run <vm> <tag> <cfg> <json> <tools: dbg json asan>
boot_run(){
  local VM=$1 TAG=$2 CFG=$3 J=$4 TOOLS=$5 IMG=/var/lib/xen/images/$1.qcow2 OFF HEAD JH t S0
  [ -n "$(xl list | awk 'NR>2')" ] && { log "another guest running -> abort"; exit 1; }
  OFF=$(offs $J)
  qemu-img snapshot -a after-install-cold $IMG; xl create $CFG >/dev/null 2>&1 || { log "$TAG xl create failed"; return; }
  sleep 90
  for t in $TOOLS; do
    S0=$(date +%s)
    case $t in
      dbg)  timeout 300 ./nojson-CR3-dbg $VM $OFF > $R/$TAG-dbg.full 2>&1; rc=$?; T=$(( $(date +%s)-S0 ))
            HEAD=$(grep -a "PsActiveProcessHead=" $R/$TAG-dbg.full | head -1 | sed 's/.*=//')
            log "$TAG nojson-CR3 stale=$(grep -a -c "is stale" $R/$TAG-dbg.full) rc=$rc t=${T}s procs=$(grep -a -c ' pid=' $R/$TAG-dbg.full) head=$HEAD $(grep -a -o 'INITFAIL\|INIT OK' $R/$TAG-dbg.full | head -1) $(grep -a -o 'encoded (rot=[0-9]*)' $R/$TAG-dbg.full | head -1) $(grep -a -o 'Found KdDebuggerDataBlock at RVA\|Found encoded KdDebuggerDataBlock at PA\|Found KdDebuggerDataBlock at PA' $R/$TAG-dbg.full | head -1)" ;;
      stock) timeout 300 ./nojson-master-stock $VM $OFF > $R/$TAG-stock.full 2>&1; rc=$?; T=$(( $(date +%s)-S0 ))
            log "$TAG nojson-MAIN rc=$rc t=${T}s procs=$(grep -a -c ' pid=' $R/$TAG-stock.full) $(grep -a -o 'INITFAIL\|INIT OK' $R/$TAG-stock.full | head -1)" ;;
      json) timeout 200 ./jsonsym-NC $VM $J > $R/$TAG-json.full 2>&1; rc=$?; T=$(( $(date +%s)-S0 ))
            JH=$(grep -a "JSON PsActiveProcessHead=" $R/$TAG-json.full | sed 's/.*=//')
            log "$TAG json rc=$rc t=${T}s head=$JH $( [ -n "$JH" ] && [ "$JH" = "$HEAD" ] && echo MATCH-nojson || echo NOMATCH) $(grep -a -o 'JSONINITFAIL' $R/$TAG-json.full | head -1)" ;;
      asan) ASAN_OPTIONS=detect_leaks=1:exitcode=0 timeout 600 ./nojson-NC-asan $VM $OFF > $R/$TAG-asan.full 2>&1; rc=$?; T=$(( $(date +%s)-S0 ))
            log "$TAG nojson-asan rc=$rc t=${T}s procs=$(grep -a -c ' pid=' $R/$TAG-asan.full) $(grep -a -o 'INITFAIL\|INIT OK' $R/$TAG-asan.full | head -1) asan_errors=$(grep -a -c 'ERROR: AddressSanitizer' $R/$TAG-asan.full) leak_reports=$(grep -a -c 'LeakSanitizer' $R/$TAG-asan.full)" ;;
    esac
  done
  xl qemu-monitor-command $VM "screendump $R/$TAG-end.ppm" >/dev/null 2>&1
  log "$TAG stop=$(stopvm $VM)"; sleep 2; qemu-img snapshot -a after-install-cold $IMG
}

for n in $(seq 1 15); do boot_run win11-21h2-test w11-21h2-c$n cfg/win11-21h2-test.cfg /root/profile/w11/win11-21h2-test.json "dbg"; done
log ALLDONE
