#!/bin/bash
W=/root/w10builds/x86/x64-regression/rerun1709; ST=$W/STATUS-late.txt; : > $ST
cd /root/kdbg-study; VM=win10-1709-test; IMG=/var/lib/xen/images/$VM.qcow2; J=/root/profile/w10/win10-1709-test.json
say(){ echo "$(date +%T) $*" | tee -a $ST; }
for i in 1 2; do
 for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
 qemu-img snapshot -a after-install-cold "$IMG"; xl create cfg/$VM.cfg >/dev/null 2>&1 || { say "xl create failed"; exit 1; }
 sleep 150
 timeout 250 ./jsonsym2-CR3-dbg $VM $J > $W/late$i.txt 2>&1
 say "boot$i json at 150s: $(grep -a -E 'JSON INIT OK|JSONINITFAIL' $W/late$i.txt | head -1)"
 xl destroy $VM 2>/dev/null; sleep 3
done
qemu-img snapshot -a after-install-cold "$IMG"; say ALLDONE
