#!/bin/bash
# is the zero DTB read time-dependent or instance-dependent? read the slot every 5 s with fresh raw instances, before and after a no-JSON init
W=/root/w10builds/x86/x64-regression/rerun1709; ST=$W/STATUS-exp.txt; : > $ST
cd /root/kdbg-study; VM=win10-1709-test; IMG=/var/lib/xen/images/$VM.qcow2; J=/root/profile/w10/win10-1709-test.json
say(){ echo "$(date +%T) $*" | tee -a $ST; }
for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
OFF=$(python3 -c "
import json;d=json.load(open('$J'));e=d['user_types']['_EPROCESS']['fields'];k=d['user_types']['_KPROCESS']['fields']
print('%x %x %x %x'%(e['ActiveProcessLinks']['offset'],e['UniqueProcessId']['offset'],e['ImageFileName']['offset'],k['DirectoryTableBase']['offset']))")
qemu-img snapshot -a after-install-cold "$IMG"; xl create cfg/$VM.cfg >/dev/null 2>&1 || { say "xl create failed"; exit 1; }
say "created"; sleep 90
timeout 250 ./jsonsym2-CR3-dbg $VM $J > $W/exp-json.txt 2>&1
n=$(grep -a -n "failed to resolve PsActiveProcessHead" $W/exp-json.txt | head -1 | cut -d: -f1)
pa=$(sed -n "1,${n}p" $W/exp-json.txt | grep -a "PTLookup: paddr =" | tail -1 | awk '{print $NF}')
say "json: $(grep -a -E 'JSON INIT OK|JSONINITFAIL' $W/exp-json.txt | head -1) slot pa=$pa"
rd(){ ./rdpa-CR3-dbg $VM $1 0x10 2>/dev/null | grep -a "^  0000:" | cut -c1-60; }
for i in $(seq 1 12); do say "t+$((i*5))s raw read: $(rd $pa)"; sleep 5; done
timeout 250 ./nojson2-CR3-dbg $VM $OFF > $W/exp-nojson.txt 2>&1
say "nojson: $(grep -a -m1 -E 'INIT OK|INITFAIL' $W/exp-nojson.txt) procs=$(grep -a -c 'pid=' $W/exp-nojson.txt)"
for i in 1 2 3; do say "after nojson raw read: $(rd $pa)"; sleep 3; done
timeout 250 ./jsonsym2-CR3-dbg $VM $J > $W/exp-json2.txt 2>&1
say "json again: $(grep -a -E 'JSON INIT OK|JSONINITFAIL' $W/exp-json2.txt | head -1)"
xl destroy $VM 2>/dev/null; sleep 3; qemu-img snapshot -a after-install-cold "$IMG"; say ALLDONE
