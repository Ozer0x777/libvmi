#!/bin/bash
# quick check of the reported Windows version without a profile, PR build (/opt/libvmi-CR3-dbg)
W=/root/w10builds/wsrv/winver; mkdir -p $W; ST=$W/STATUS.txt; : > $ST
cd /root/kdbg-study; say(){ echo "$(date +%F\ %T) $*" | tee -a $ST; }
for e in "win10-1507-test:/root/profile/w10/win10-1507-test.json" "win10-22H2-test:/root/profile/w10/win10-22H2-test.json" "win10-1607-x86-test:/root/profile/w10x86/win10-1607-x86-test.json" "win11-24h2-test:/root/profile/w11/win11-24h2-test.json" "win81-9600-x64-test:/root/profile/w78/win81-9600-x64-test.json" "win8-9200-x86-test:/root/profile/w78/win8-9200-x86-test.json" "win7-7601-x64-test:/root/profile/w78/win7-7601-x64-test.json" "winsrv-2016-test:/root/profile/wsrv/winsrv-2016-test.json" "winsrv-2008-test:/root/profile/wsrv/winsrv-2008-test.json"; do
 IFS=: read VM J <<< "$e"; IMG=/var/lib/xen/images/$VM.qcow2
 for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
 OFF=$(python3 -c "
import json;d=json.load(open('$J'));e=d['user_types']['_EPROCESS']['fields'];k=d['user_types']['_KPROCESS']['fields']
print('%x %x %x %x'%(e['ActiveProcessLinks']['offset'],e['UniqueProcessId']['offset'],e['ImageFileName']['offset'],k['DirectoryTableBase']['offset']))")
 qemu-img snapshot -a after-install-cold "$IMG"; xl create cfg/$VM.cfg >/dev/null 2>&1 || { say "$VM xl create failed"; continue; }
 sleep 150
 timeout 250 ./nojson2-CR3-dbg $VM $OFF > $W/$VM.txt 2>&1
 timeout 250 ./jsonsym2-CR3-dbg $VM $J > $W/$VM-json.txt 2>&1
 say "$VM: nojson $(grep -a -m1 -E 'INIT OK|INITFAIL' $W/$VM.txt | cut -d' ' -f1-3) procs=$(grep -a -c 'pid=' $W/$VM.txt) $(grep -a -m1 -o 'KdDebuggerDataBlock size 0x[0-9a-f]*, kernel PE version [0-9.]*' $W/$VM.txt) $(grep -a -m1 -o 'Unsupported Windows version' $W/$VM.txt) | json $(grep -a -m1 -o 'winver=[0-9]*' $W/$VM-json.txt)"
 xl destroy $VM 2>/dev/null; sleep 3; qemu-img snapshot -a after-install-cold "$IMG"
done
say ALLDONE
