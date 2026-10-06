#!/bin/bash
# unattended install of the old Win10 test VMs (1507/1511/1607/1703), one at a time, + snapshot + boot verification
# same procedure as inst10.sh; EPROCESS offsets for the verification are per build (links pid name dtb)
W=/root/w10builds/old; mkdir -p $W; ST=$W/STATUS.txt; : > $ST
cd /root/kdbg-study
say(){ echo "$(date +%F\ %T) $*" | tee -a $ST; }
declare -A MACS=( [1507]=8c [1511]=8d [1607]=8e [1703]=8f )
declare -A OFFS=( [1507]="2f0 2e8 448 28" [1511]="2f0 2e8 450 28" [1607]="2f0 2e8 450 28" [1703]="2e8 2e0 450 28" )
for b in 1507 1511 1607 1703; do
 VM=win10-$b-test; IMG=/var/lib/xen/images/$VM.qcow2; CFG=/root/w10builds/$VM.cfg
 MAC="00:14:22:6f:71:${MACS[$b]}"
 say "=== $VM mac=$MAC"
 [ -e "$IMG" ] && { say "$VM image already exists, SKIP"; continue; }
 [ -e /root/iso/win10-builds/Win10_$b.iso ] || { say "$VM ISO missing, SKIP"; continue; }
 for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
 qemu-img create -f qcow2 "$IMG" 80G >/dev/null || { say "$VM create failed"; continue; }
 sed -e "s/win10-1909-test/$VM/g" -e "s#Win10_1909.iso#Win10_$b.iso#" -e "s/mac=00:14:22:6f:71:94/mac=$MAC/" /root/w10builds/win10-1909-test.cfg > "$CFG"
 xl create "$CFG" >/dev/null 2>&1 || { say "$VM xl create failed"; continue; }
 say "$VM install started"
 prev=0; idle=0; el=0
 while true; do
  sleep 60; el=$((el+60))
  xl list $VM >/dev/null 2>&1 || { say "$VM domain gone at ${el}s (installer powered off?)"; break; }
  cur=$(xl list $VM | awk 'NR==2{print $6}'); ci=${cur%.*}; d=$((ci-prev)); prev=$ci
  if [ $((el % 300)) -eq 0 ]; then say "$VM t=${el}s cpu=${cur}s delta=${d}s img=$(du -m "$IMG" | cut -f1)MB"; xl qemu-monitor-command $VM "screendump $W/$VM-progress.ppm" >/dev/null 2>&1; fi
  if [ $el -ge 900 ] && [ $d -le 6 ]; then idle=$((idle+1)); else idle=0; fi
  [ $idle -ge 4 ] && { say "$VM idle after ${el}s (img $(du -m "$IMG" | cut -f1)MB)"; break; }
  [ $el -ge 4200 ] && { say "$VM TIMEOUT 70 min"; break; }
 done
 xl qemu-monitor-command $VM "screendump $W/$VM-final.ppm" >/dev/null 2>&1
 xl destroy $VM 2>/dev/null; sleep 3
 qemu-img snapshot -c after-install-cold "$IMG" && say "$VM snapshot after-install-cold created" || say "$VM SNAPSHOT FAILED"
 # verification: restore, boot, attach without JSON, list processes
 cp "$CFG" cfg/ ; qemu-img snapshot -a after-install-cold "$IMG"
 xl create cfg/$VM.cfg >/dev/null 2>&1; sleep 90
 timeout 200 ./nojson-K-dbg $VM ${OFFS[$b]} 2>&1 | grep -a -E "encoded|INITFAIL|INIT OK|PsActiveProcessHead=|PROCS|pid=" > $W/$VM-verify.txt
 xl qemu-monitor-command $VM "screendump $W/$VM-verify.ppm" >/dev/null 2>&1
 xl destroy $VM 2>/dev/null; sleep 3
 qemu-img snapshot -a after-install-cold "$IMG"
 say "$VM VERIFY: procs=$(grep -a -c 'pid=' $W/$VM-verify.txt) explorer=$(grep -a -c explorer.exe $W/$VM-verify.txt) system=$(grep -a -c 'pid=4 .*System' $W/$VM-verify.txt) $(grep -a -o 'encoded (rot=[0-9]*)' $W/$VM-verify.txt | head -1) $(grep -a -q INITFAIL $W/$VM-verify.txt && echo INITFAIL)"
done
say "ALLDONE"
