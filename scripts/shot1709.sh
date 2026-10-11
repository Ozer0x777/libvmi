#!/bin/bash
W=/root/w10builds/x86/x64-regression/rerun1709/shots; mkdir -p $W; ST=$W/STATUS.txt; : > $ST
cd /root/kdbg-study; VM=win10-1709-test; IMG=/var/lib/xen/images/$VM.qcow2; J=/root/profile/w10/win10-1709-test.json
say(){ echo "$(date +%T) $*" | tee -a $ST; }
for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
qemu-img snapshot -a after-install-cold "$IMG"; xl create cfg/$VM.cfg >/dev/null 2>&1 || { say "xl create failed"; exit 1; }
t0=$(date +%s)
for t in 20 40 60 75 90 100 110 120 150; do
 while [ $(( $(date +%s) - t0 )) -lt $t ]; do sleep 1; done
 xl qemu-monitor-command $VM "screendump $W/t$t.ppm" >/dev/null 2>&1; say "shot t=$t cpu=$(xl list $VM | awk 'NR==2{print $6}')"
done
timeout 250 ./jsonsym2-CR3-dbg $VM $J > $W/json-150.txt 2>&1; say "json at 150s: $(grep -a -E 'JSON INIT OK|JSONINITFAIL' $W/json-150.txt | head -1)"
xl destroy $VM 2>/dev/null; sleep 3; qemu-img snapshot -a after-install-cold "$IMG"
which virt-ls guestfish 2>/dev/null | head -2 >> $ST
say ALLDONE
