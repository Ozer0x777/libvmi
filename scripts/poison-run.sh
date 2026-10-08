#!/bin/bash
cd /root/kdbg-study; R=/root/kdbg-study/poison-run; mkdir -p $R; S=$R/summary.txt; : > $S
log(){ echo "$(date +%T) $*" | tee -a $S; }
VM=win11-21h2-test; IMG=/var/lib/xen/images/$VM.qcow2; J=/root/profile/w11/win11-21h2-test.json
OFF=$(python3 - $J <<'PY'
import json,sys
ut=json.load(open(sys.argv[1]))["user_types"]
f=lambda t,n: ut[t]["fields"][n]["offset"]
print("%x %x %x %x"%(f("_EPROCESS","ActiveProcessLinks"),f("_EPROCESS","UniqueProcessId"),f("_EPROCESS","ImageFileName"),f("_KPROCESS","DirectoryTableBase")))
PY
)
[ -n "$(xl list | awk 'NR>2')" ] && { log "another guest running"; exit 1; }
qemu-img snapshot -a after-install-cold $IMG; xl create cfg/$VM.cfg >/dev/null 2>&1; sleep 90
for P in 3000 1000000; do
 for t in PK-ci PCR3; do
  S0=$(date +%s); KPGD_POISON=$P timeout 400 ./nojson-$t $VM $OFF > $R/$t-$P.full 2>&1; rc=$?
  log "poison=0x$P $t rc=$rc t=$(( $(date +%s)-S0 ))s procs=$(grep -a -c ' pid=' $R/$t-$P.full) $(grep -a -o 'INITFAIL\|INIT OK' $R/$t-$P.full | head -1) stale_msg=$(grep -a -c 'is stale' $R/$t-$P.full)"
 done
done
timeout 150 xl shutdown -F -w $VM >/dev/null 2>&1; for i in $(seq 1 30); do xl list $VM >/dev/null 2>&1 || break; sleep 2; done; xl list $VM >/dev/null 2>&1 && xl destroy $VM
sleep 2; qemu-img snapshot -a after-install-cold $IMG; log ALLDONE
