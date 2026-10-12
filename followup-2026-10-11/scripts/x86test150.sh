#!/bin/bash
# Win10 x86 VMs: boot from the clean snapshot, attach with the JSON profile and without (x86 EPROCESS offsets), dump the KDBG header
W=/root/w10builds/x86/attach; mkdir -p $W; ST=$W/STATUS.txt; P=/root/profile/w10x86
cd /root/kdbg-study
say(){ echo "$(date +%F\ %T) $*" | tee -a $ST; }
for b in ${BUILDS:-1507 1511 1607 1703 1709 1803 1809 1903 1909 2004 20H2 21H1 21H2 22H2}; do
 VM=win10-$b-x86-test; IMG=/var/lib/xen/images/$VM.qcow2; J=$P/win10-$b-x86-test.json
 for i in $(seq 1 90); do [ -s $J ] && break; sleep 20; done
 [ -s $J ] || { say "$VM no JSON profile, SKIP"; continue; }
 for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
 OFF=$(python3 -c "
import json;d=json.load(open('$J'));e=d['user_types']['_EPROCESS']['fields'];k=d['user_types']['_KPROCESS']['fields']
print('%x %x %x %x'%(e['ActiveProcessLinks']['offset'],e['UniqueProcessId']['offset'],e['ImageFileName']['offset'],k['DirectoryTableBase']['offset']))")
 say "=== $VM offsets(tasks pid pname pdbase)=$OFF"
 qemu-img snapshot -a after-install-cold "$IMG" || { say "$VM snapshot restore failed"; continue; }
 xl create cfg/$VM.cfg >/dev/null 2>&1 || { say "$VM xl create failed"; continue; }
 sleep 150
 timeout 250 ./jsonsym2-CR3-dbg $VM $J > $W/$VM-json-full.txt 2>&1
 say "$VM JSON: $(grep -a -E 'JSON INIT OK|JSONINITFAIL' $W/$VM-json-full.txt | head -1)"
 timeout 250 ./nojson2-CR3-dbg $VM $OFF > $W/$VM-nojson-full.txt 2>&1
 grep -a -E "encoded|INITFAIL|INIT OK|PsActiveProcessHead=|PROCS|pid=|Found KdDebuggerDataBlock|KernBase|VMI_ERROR|Unsupported|kpgd method|trying VMI_PM|CR3" $W/$VM-nojson-full.txt | head -80 > $W/$VM-nojson.txt
 kpa=$(grep -a -o "Found KdDebuggerDataBlock at PA [0-9a-f]*" $W/$VM-nojson-full.txt | head -1 | awk '{print $NF}')
 [ -n "$kpa" ] && ./rdpa-CR3-dbg $VM 0x$kpa 0x40 > $W/$VM-kdbg-header.txt 2>&1
 xl qemu-monitor-command $VM "screendump $W/$VM.ppm" >/dev/null 2>&1
 xl destroy $VM 2>/dev/null; sleep 3
 qemu-img snapshot -a after-install-cold "$IMG"
 say "$VM NOJSON: $(grep -a -m1 -E 'INIT OK|INITFAIL' $W/$VM-nojson.txt) procs=$(grep -a -c 'pid=' $W/$VM-nojson.txt) system=$(grep -a -c 'pid=4 .*System' $W/$VM-nojson.txt) kdbg_pa=$kpa $(grep -a -m1 -o 'Unsupported Windows version' $W/$VM-nojson.txt)"
done
say "ALLDONE"
