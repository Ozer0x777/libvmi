#!/bin/bash
# usage: matrixK.sh <libvmi-tag> ; for each guest: nojson attach (offsets from its JSON) + compare head with JSON
cd /root/kdbg-study; mkdir -p k; OUT=k/matrix-$1.txt; : > $OUT
for spec in win10-1809-test:w10; do
 VM=${spec%%:*}; D=${spec##*:}; J=/root/profile/$D/$VM.json
 OFF=$(python3 - $J <<PY
import json,sys
ut=json.load(open(sys.argv[1]))["user_types"]
f=lambda t,n: ut[t]["fields"][n]["offset"]
print("%x %x %x %x"%(f("_EPROCESS","ActiveProcessLinks"),f("_EPROCESS","UniqueProcessId"),f("_EPROCESS","ImageFileName"),f("_KPROCESS","DirectoryTableBase")))
PY
)
 xl list | awk "NR>2{print \$1}" | xargs -r -n1 xl destroy; qemu-img snapshot -a after-install-cold /var/lib/xen/images/$VM.qcow2 2>/dev/null || { echo "$VM SNAPFAIL" >> $OUT; continue; }
 xl create cfg/$VM.cfg >/dev/null 2>&1; sleep 75
 S=$(date +%s)
 timeout 250 ./nojson-$1 $VM $OFF 2>&1 | grep -a -E "encoded|Found Kd|INITFAIL|INIT OK|PsActiveProcessHead=|PROCS|VMI_ERROR" > k/$VM-nj.txt
 T=$(( $(date +%s)-S ))
 H=$(grep -a "PsActiveProcessHead=" k/$VM-nj.txt | head -1 | sed 's/.*=//')
 JH=$(timeout 100 ./jsonsym $VM $J 2>&1 | grep -a "JSON PsActive" | sed 's/.*=//')
 echo "$VM t=${T}s head=$H json=$JH $( [ -n "$H" ] && [ "$H" = "$JH" ] && echo MATCH || echo MISMATCH ) $(grep -a -E 'PROCS|encoded|INITFAIL' k/$VM-nj.txt | tr '\n' ' ')" >> $OUT
 xl destroy $VM 2>/dev/null; sleep 3
done
echo MATRIXDONE >> $OUT
