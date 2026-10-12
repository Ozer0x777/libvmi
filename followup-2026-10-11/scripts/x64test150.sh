#!/bin/bash
# x64 regression after the 32-bit patch: Win10 (14) + Win11 (6) VMs, clean snapshot, JSON attach + no-JSON attach (offsets from the JSON), PR build
W=/root/w10builds/x86/x64-regression; mkdir -p $W; ST=$W/STATUS.txt
cd /root/kdbg-study
say(){ echo "$(date +%F\ %T) $*" | tee -a $ST; }
run(){ VM=$1; J=$2
 IMG=/var/lib/xen/images/$VM.qcow2
 [ -s "$J" ] || { say "$VM no JSON profile $J, SKIP"; return; }
 for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
 OFF=$(python3 -c "
import json;d=json.load(open('$J'));e=d['user_types']['_EPROCESS']['fields'];k=d['user_types']['_KPROCESS']['fields']
print('%x %x %x %x'%(e['ActiveProcessLinks']['offset'],e['UniqueProcessId']['offset'],e['ImageFileName']['offset'],k['DirectoryTableBase']['offset']))")
 say "=== $VM offsets=$OFF"
 qemu-img snapshot -a after-install-cold "$IMG" || { say "$VM snapshot restore failed"; return; }
 xl create cfg/$VM.cfg >/dev/null 2>&1 || { say "$VM xl create failed"; return; }
 sleep 150
 timeout 250 ./jsonsym2-CR3-dbg $VM $J > $W/$VM-json-full.txt 2>&1
 say "$VM JSON: $(grep -a -E 'JSON INIT OK|JSONINITFAIL' $W/$VM-json-full.txt | head -1) $(grep -a -m1 -o 'conflicts with provided value' $W/$VM-json-full.txt)"
 timeout 250 ./nojson2-CR3-dbg $VM $OFF > $W/$VM-nojson-full.txt 2>&1
 grep -a -E "encoded|INITFAIL|INIT OK|PsActiveProcessHead=|no PsActive|PROCS|pid=|Found KdDebuggerDataBlock|Found encoded|KernBase|VMI_ERROR|kpgd method|using vCPU|stale" $W/$VM-nojson-full.txt | head -80 > $W/$VM-nojson.txt
 xl destroy $VM 2>/dev/null; sleep 3
 qemu-img snapshot -a after-install-cold "$IMG"
 say "$VM NOJSON: $(grep -a -m1 -E 'INIT OK|INITFAIL' $W/$VM-nojson.txt) head=$(grep -a -m1 -o 'PsActiveProcessHead=0x[0-9a-f]*' $W/$VM-nojson.txt | cut -d= -f2) procs=$(grep -a -c 'pid=' $W/$VM-nojson.txt) system=$(grep -a -c 'pid=4 .*System' $W/$VM-nojson.txt) $(grep -a -m1 -o 'encoded (rot=[0-9]*)' $W/$VM-nojson.txt)"
}
for b in ${W10:-1507 1511 1607 1703 1709 1803 1809 1903 1909 2004 20H2 21H1 21H2 22H2}; do run win10-$b-test /root/profile/w10/win10-$b-test.json; done
for b in ${W11:-21h2 22h2 23h2 24h2 25h2 26h1}; do run win11-$b-test /root/profile/w11/win11-$b-test.json; done
say "ALLDONE"
