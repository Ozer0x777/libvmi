#!/bin/bash
# Windows Server VMs: clean snapshot, wait 150 s, attach with JSON and without, upstream master (6898847) vs the PR #1128 build
W=/root/w10builds/wsrv/attach; mkdir -p $W; ST=$W/STATUS.txt; P=/root/profile/wsrv
cd /root/kdbg-study
say(){ echo "$(date +%F\ %T) $*" | tee -a $ST; }
# wait for the installs (inst-srv.sh + retry2012.sh) to be over
while pgrep -f "inst-srv.s[h]|retry2012.s[h]" >/dev/null; do sleep 30; done; sleep 5
for VM in ${VMS:-winsrv-2012r2-test winsrv-2016-test winsrv-2019-test winsrv-2022-test winsrv-2025-test winsrv-2008r2-test winsrv-2012-test winsrv-2008-test}; do
 IMG=/var/lib/xen/images/$VM.qcow2; J=$P/$VM.json
 [ -s "$IMG" ] || { say "$VM no image, SKIP"; continue; }
 qemu-img snapshot -l "$IMG" | grep -q after-install-cold || { say "$VM no snapshot, SKIP"; continue; }
 [ -s "$J" ] || { say "$VM no JSON profile, SKIP"; continue; }
 for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
 OFF=$(python3 -c "
import json;d=json.load(open('$J'));e=d['user_types']['_EPROCESS']['fields'];k=d['user_types']['_KPROCESS']['fields']
print('%x %x %x %x'%(e['ActiveProcessLinks']['offset'],e['UniqueProcessId']['offset'],e['ImageFileName']['offset'],k['DirectoryTableBase']['offset']))")
 say "=== $VM offsets=$OFF"
 qemu-img snapshot -a after-install-cold "$IMG" || { say "$VM snapshot restore failed"; continue; }
 xl create cfg/$VM.cfg >/dev/null 2>&1 || { say "$VM xl create failed"; continue; }
 sleep 150
 for L in master-now CR3-dbg; do
  timeout 250 ./jsonsym2-$L $VM $J > $W/$VM-$L-json-full.txt 2>&1
  say "$VM [$L] JSON: $(grep -a -E 'JSON INIT OK|JSONINITFAIL' $W/$VM-$L-json-full.txt | head -1) $(grep -a -m1 -o 'conflicts with provided value' $W/$VM-$L-json-full.txt)"
  timeout 250 ./nojson2-$L $VM $OFF > $W/$VM-$L-nojson-full.txt 2>&1
  grep -a -E "encoded|INITFAIL|INIT OK|PsActiveProcessHead=|no PsActive|PROCS|pid=|Found KdDebuggerDataBlock|Found encoded|KernBase|VMI_ERROR|Unsupported|kpgd method|Trying find|using vCPU|stale" $W/$VM-$L-nojson-full.txt | head -80 > $W/$VM-$L-nojson.txt
  say "$VM [$L] NOJSON: $(grep -a -m1 -E 'INIT OK|INITFAIL' $W/$VM-$L-nojson.txt) head=$(grep -a -m1 -o 'PsActiveProcessHead=0x[0-9a-f]*' $W/$VM-$L-nojson.txt | cut -d= -f2) procs=$(grep -a -c 'pid=' $W/$VM-$L-nojson.txt) system=$(grep -a -c 'pid=4 .*System' $W/$VM-$L-nojson.txt) $(grep -a -m1 -o 'encoded (rot=[0-9]*)' $W/$VM-$L-nojson.txt) $(grep -a -m1 -o 'Unsupported Windows version' $W/$VM-$L-nojson.txt) finder=$(grep -a -o 'Trying find_kdbg_address_[a-z]*' $W/$VM-$L-nojson.txt | tail -1 | awk '{print $2}')"
 done
 xl qemu-monitor-command $VM "screendump $W/$VM.ppm" >/dev/null 2>&1
 xl destroy $VM 2>/dev/null; sleep 3
 qemu-img snapshot -a after-install-cold "$IMG"
done
say "ALLDONE"
