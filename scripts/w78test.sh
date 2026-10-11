#!/bin/bash
# Win7/8 VMs: boot from the clean snapshot, wait 150 s, attach with JSON and without (offsets from the JSON) with upstream master (6898847) and the 32-bit branch build
W=/root/w10builds/w78/attach; mkdir -p $W; ST=$W/STATUS.txt; P=/root/profile/w78
cd /root/kdbg-study
say(){ echo "$(date +%F\ %T) $*" | tee -a $ST; }
while ! grep -q PROFILESDONE $P/profiles.log 2>/dev/null; do sleep 20; done
for VM in ${VMS:-win7-7600-x86-test win7-7600-x64-test win7-7601-x86-test win7-7601-x64-test win8-9200-x86-test win8-9200-x64-test win81-9600-x86-test win81-9600-x64-test}; do
 IMG=/var/lib/xen/images/$VM.qcow2
 JS="$P/$VM.json"; [ -s $P/$VM-ntkrnlpa.json ] && JS="$P/$VM-ntkrnlpa.json $P/$VM.json"
 for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
 say "=== $VM"
 qemu-img snapshot -a after-install-cold "$IMG" || { say "$VM snapshot restore failed"; continue; }
 xl create cfg/$VM.cfg >/dev/null 2>&1 || { say "$VM xl create failed"; continue; }
 sleep 150
 for L in master-now CR3-dbg; do
  JOK=""; for J in $JS; do
   timeout 250 ./jsonsym2-$L $VM $J > $W/$VM-$L-json-$(basename $J .json).txt 2>&1
   r=$(grep -a -E 'JSON INIT OK|JSONINITFAIL' $W/$VM-$L-json-$(basename $J .json).txt | head -1); say "$VM [$L] JSON($(basename $J .json)): $r"
   case "$r" in *"INIT OK"*) JOK=$J; break;; esac
  done
  J=${JOK:-$(echo $JS | cut -d" " -f1)}
  OFF=$(python3 -c "
import json;d=json.load(open('$J'));e=d['user_types']['_EPROCESS']['fields'];k=d['user_types']['_KPROCESS']['fields']
print('%x %x %x %x'%(e['ActiveProcessLinks']['offset'],e['UniqueProcessId']['offset'],e['ImageFileName']['offset'],k['DirectoryTableBase']['offset']))")
  timeout 250 ./nojson2-$L $VM $OFF > $W/$VM-$L-nojson-full.txt 2>&1
  grep -a -E "encoded|INITFAIL|INIT OK|PsActiveProcessHead=|no PsActive|PROCS|pid=|Found KdDebuggerDataBlock|Found encoded|KernBase|VMI_ERROR|Unsupported|kpgd method|Trying find|using vCPU|stale" $W/$VM-$L-nojson-full.txt | head -80 > $W/$VM-$L-nojson.txt
  say "$VM [$L] NOJSON(off=$OFF): $(grep -a -m1 -E 'INIT OK|INITFAIL' $W/$VM-$L-nojson.txt) head=$(grep -a -m1 -o 'PsActiveProcessHead=0x[0-9a-f]*' $W/$VM-$L-nojson.txt | cut -d= -f2) procs=$(grep -a -c 'pid=' $W/$VM-$L-nojson.txt) system=$(grep -a -c 'pid=4 .*System' $W/$VM-$L-nojson.txt) $(grep -a -m1 -o 'encoded (rot=[0-9]*)' $W/$VM-$L-nojson.txt) $(grep -a -m1 -o 'Unsupported Windows version' $W/$VM-$L-nojson.txt) finder=$(grep -a -o 'Trying find_kdbg_address_[a-z]*' $W/$VM-$L-nojson.txt | tail -1 | awk '{print $2}')"
 done
 xl qemu-monitor-command $VM "screendump $W/$VM.ppm" >/dev/null 2>&1
 xl destroy $VM 2>/dev/null; sleep 3
 qemu-img snapshot -a after-install-cold "$IMG"
done
say "ALLDONE"
