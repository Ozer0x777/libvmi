#!/bin/bash
# same as x86test.sh but with upstream master (82bbee6) binaries, for comparison
W=/root/w10builds/x86/attach-stock; mkdir -p $W; ST=$W/STATUS.txt; P=/root/profile/w10x86
cd /root/kdbg-study
say(){ echo "$(date +%F\ %T) $*" | tee -a $ST; }
for b in ${BUILDS:-1507 21H2}; do
 VM=win10-$b-x86-test; IMG=/var/lib/xen/images/$VM.qcow2; J=$P/win10-$b-x86-test.json
 for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
 OFF=$(python3 -c "
import json;d=json.load(open('$J'));e=d['user_types']['_EPROCESS']['fields'];k=d['user_types']['_KPROCESS']['fields']
print('%x %x %x %x'%(e['ActiveProcessLinks']['offset'],e['UniqueProcessId']['offset'],e['ImageFileName']['offset'],k['DirectoryTableBase']['offset']))")
 say "=== $VM stock offsets=$OFF"
 qemu-img snapshot -a after-install-cold "$IMG" || { say "$VM snapshot restore failed"; continue; }
 xl create cfg/$VM.cfg >/dev/null 2>&1 || { say "$VM xl create failed"; continue; }
 sleep 90
 timeout 300 ./jsonsym2-master-stock $VM $J > $W/$VM-json-full.txt 2>&1
 say "$VM STOCK JSON: $(grep -a -E 'JSON INIT OK|JSONINITFAIL' $W/$VM-json-full.txt | head -1) $(grep -a -m1 -o 'conflicts with provided value' $W/$VM-json-full.txt)"
 timeout 300 ./nojson2-master-stock $VM $OFF > $W/$VM-nojson-full.txt 2>&1
 grep -a -E "encoded|INITFAIL|INIT OK|PsActiveProcessHead=|no PsActive|PROCS|pid=|Found KdDebuggerDataBlock|KernBase|VMI_ERROR|Unsupported|kpgd method|Trying" $W/$VM-nojson-full.txt | head -60 > $W/$VM-nojson.txt
 xl destroy $VM 2>/dev/null; sleep 3
 qemu-img snapshot -a after-install-cold "$IMG"
 say "$VM STOCK NOJSON: $(grep -a -m1 -E 'INIT OK|INITFAIL' $W/$VM-nojson.txt) procs=$(grep -a -c 'pid=' $W/$VM-nojson.txt) system=$(grep -a -c 'pid=4 .*System' $W/$VM-nojson.txt) $(grep -a -m1 -o 'no PsActiveProcessHead' $W/$VM-nojson.txt)"
done
say "ALLDONE"
