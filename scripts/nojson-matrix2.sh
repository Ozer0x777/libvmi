#!/bin/bash
# usage: nojson-matrix2.sh <tag> <build>...  ; no-JSON (config hashtable, offsets only) attach on each Win10 VM, stock libvmi variant <tag>
# 90 s after xl create like inst-old.sh; full libvmi debug log kept per build; clean stop + snapshot revert
TAG=$1; shift; R=/root/kdbg-study/nojson-w10-$TAG; mkdir -p $R; S=$R/summary.txt; cd /root/kdbg-study
log(){ echo "$(date +%T) $*" | tee -a $S; }
stopvm(){ local i; xl list "$1" >/dev/null 2>&1 || return 0; timeout 150 xl shutdown -F -w "$1" >/dev/null 2>&1
  for i in $(seq 1 30); do xl list "$1" >/dev/null 2>&1 || { echo clean; return 0; }; sleep 2; done; xl destroy "$1"; echo destroyed; }
log "===== nojson attach, libvmi=$TAG ($(readlink -f nojson-$TAG)) builds: $*"
for b in "$@"; do
 D=win10-$b-test; IMG=/var/lib/xen/images/$D.qcow2; J=/root/profile/w10/$D.json
 [ -n "$(xl list | awk "NR>2")" ] && { log "another guest running -> abort"; exit 1; }
 OFF=$(python3 - $J <<PY
import json,sys
ut=json.load(open(sys.argv[1]))["user_types"]
f=lambda t,n: ut[t]["fields"][n]["offset"]
print("%x %x %x %x"%(f("_EPROCESS","ActiveProcessLinks"),f("_EPROCESS","UniqueProcessId"),f("_EPROCESS","ImageFileName"),f("_KPROCESS","DirectoryTableBase")))
PY
)
 qemu-img snapshot -a after-install-cold $IMG; xl create cfg/$D.cfg >/dev/null 2>&1 || { log "$b xl create failed"; continue; }
 sleep 90; S0=$(date +%s)
 timeout 250 ./nojson-$TAG $D $OFF > $R/$b.full 2>&1; rc=$?; T=$(( $(date +%s)-S0 ))
 log "$b offs=[$OFF] rc=$rc t=${T}s procs=$(grep -a -c "pid=" $R/$b.full) $(grep -a -o "INITFAIL\|INIT OK" $R/$b.full | head -1) $(grep -a -o "encoded (rot=[0-9]*)" $R/$b.full | head -1)"
 xl qemu-monitor-command $D "screendump $R/$b-end.ppm" >/dev/null 2>&1
 log "$b stop=$(stopvm $D)"; sleep 2; qemu-img snapshot -a after-install-cold $IMG
done
log "===== done"; touch $R/DONE
