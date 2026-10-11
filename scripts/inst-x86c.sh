#!/bin/bash
# unattended install of the Win10 x86 test VMs (14 builds), one at a time, + snapshot + boot check + no-JSON attach log
W=/root/w10builds/x86; mkdir -p $W; ST=$W/STATUS.txt; : >> $ST
cd /root/kdbg-study
say(){ echo "$(date +%F\ %T) $*" | tee -a $ST; }
BUILDS="${BUILDS:-1507 1511 1607 1703 1709 1803 1809 1903 1909 2004 20H2 21H1 21H2 22H2}"
ALL="1507 1511 1607 1703 1709 1803 1809 1903 1909 2004 20H2 21H1 21H2 22H2"
for b in $BUILDS; do
 VM=win10-$b-x86-test; IMG=/var/lib/xen/images/$VM.qcow2; CFG=/root/w10builds/$VM.cfg
 n=1; for x in $ALL; do [ $x = $b ] && break; n=$((n+1)); done; MAC=$(printf "00:14:22:6f:72:%02x" $((0x10+n)))
 mount -o loop,ro /root/iso/win10-x86/Win10_${b}_x86.iso /mnt/x86chk 2>/dev/null; w=$(ls /mnt/x86chk/sources/install.* 2>/dev/null | head -1)
 LANGID=$(wiminfo $w 1 2>/dev/null | grep -a -i -m1 "Default Language" | awk '{print $NF}'); umount /mnt/x86chk 2>/dev/null
 case "$LANGID" in en-US) AU=/root/iso/autounattend-w10-x86.iso;; en-GB) AU=/root/iso/autounattend-w10-x86-gb.iso;; da-DK) AU=/root/iso/autounattend-w10-x86-da.iso;; *) say "$VM unknown language '$LANGID', SKIP"; continue;; esac
 say "$VM media language $LANGID"
 say "=== $VM mac=$MAC unattend=$(basename $AU)"
 [ -e "$IMG" ] && { say "$VM image already exists, SKIP"; continue; }
 [ -e /root/iso/win10-x86/Win10_${b}_x86.iso ] || { say "$VM ISO missing, SKIP"; continue; }
 for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
 qemu-img create -f qcow2 "$IMG" 80G >/dev/null || { say "$VM create failed"; continue; }
 sed -e "s/win10-1909-test/$VM/g" -e "s#/root/iso/win10-builds/Win10_1909.iso#/root/iso/win10-x86/Win10_${b}_x86.iso#" \
     -e "s#/root/iso/autounattend-w10.iso#$AU#" -e "s/mac=00:14:22:6f:71:94/mac=$MAC/" /root/w10builds/win10-1909-test.cfg > "$CFG"
 xl create "$CFG" >/dev/null 2>&1 || { say "$VM xl create failed"; continue; }
 say "$VM install started"
 prev=0; idle=0; el=0
 while true; do
  sleep 60; el=$((el+60))
  # the domain disappears for a few seconds during an installer reboot: retry before declaring it gone
  gone=1; for t in 1 2 3 4 5 6; do xl list $VM >/dev/null 2>&1 && { gone=0; break; }; sleep 5; done
  [ $gone = 1 ] && { say "$VM domain gone at ${el}s (installer powered off?)"; break; }
  cur=$(xl list $VM | awk 'NR==2{print $6}'); ci=${cur%.*}; d=$((ci-prev)); prev=$ci
  if [ $((el % 300)) -eq 0 ]; then say "$VM t=${el}s cpu=${cur}s delta=${d}s img=$(du -m "$IMG" | cut -f1)MB"; xl qemu-monitor-command $VM "screendump $W/$VM-progress.ppm" >/dev/null 2>&1; fi
  if [ $el -ge 900 ] && [ $d -le 6 ]; then idle=$((idle+1)); else idle=0; fi
  [ $el -ge 1200 ] && [ $(du -m "$IMG" | cut -f1) -lt 2500 ] && { say "$VM STUCK (img only $(du -m "$IMG" | cut -f1)MB after ${el}s)"; break; }
  [ $idle -ge 4 ] && { say "$VM idle after ${el}s (img $(du -m "$IMG" | cut -f1)MB)"; break; }
  [ $el -ge 4200 ] && { say "$VM TIMEOUT 70 min"; break; }
 done
 xl qemu-monitor-command $VM "screendump $W/$VM-final.ppm" >/dev/null 2>&1
 xl destroy $VM 2>/dev/null; sleep 3
 qemu-img snapshot -c after-install-cold "$IMG" && say "$VM snapshot after-install-cold created" || say "$VM SNAPSHOT FAILED"
 # boot check from the snapshot + no-JSON attach (offsets are x64 ones: only the init outcome matters here)
 cp "$CFG" cfg/ ; qemu-img snapshot -a after-install-cold "$IMG"
 xl create cfg/$VM.cfg >/dev/null 2>&1; sleep 90
 timeout 250 ./nojson-K-dbg $VM 2f0 2e8 450 28 > $W/$VM-attach-full.txt 2>&1
 head -c 3000000 $W/$VM-attach-full.txt | grep -a -E "encoded|INITFAIL|INIT OK|PsActiveProcessHead=|PROCS|pid=|KdDebuggerDataBlock|MachineType|Failed" | head -60 > $W/$VM-attach.txt
 xl qemu-monitor-command $VM "screendump $W/$VM-verify.ppm" >/dev/null 2>&1
 xl destroy $VM 2>/dev/null; sleep 3
 qemu-img snapshot -a after-install-cold "$IMG"
 say "$VM ATTACH: procs=$(grep -a -c 'pid=' $W/$VM-attach.txt) $(grep -a -q INITFAIL $W/$VM-attach.txt && echo INITFAIL)"
done
say "ALLDONE"
