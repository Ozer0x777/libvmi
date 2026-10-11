#!/bin/bash
# unattended install of the Windows 7 / 8 / 8.1 test VMs (x86 + x64), one at a time, + snapshot + boot screenshots
W=/root/w10builds/w78; mkdir -p $W; ST=$W/STATUS.txt; : >> $ST
cd /root/kdbg-study
say(){ echo "$(date +%F\ %T) $*" | tee -a $ST; }
# vm iso unattend mac-suffix
LIST="win7-7600-x86-test:win7/Win7_7600_RTM_x86.iso:win7-x86:11
win7-7600-x64-test:win7/Win7_7600_RTM_x64.iso:win7-x64:12
win7-7601-x86-test:win7/Win7_7601_SP1_x86.iso:win7-x86:13
win7-7601-x64-test:win7/Win7_7601_SP1_x64.iso:win7-x64:14
win8-9200-x86-test:win8/Win8_9200_RTM_x86.iso:win8-x86:15
win8-9200-x64-test:win8/Win8_9200_RTM_x64.iso:win8-x64:16
win81-9600-x86-test:win8/Win81_9600_Update1_x86.iso:win81-x86:17
win81-9600-x64-test:win8/Win81_9600_Update1_x64.iso:win81-x64:18"
for e in ${ONLY:-$LIST}; do
 IFS=: read VM ISO AU M <<< "$e"
 IMG=/var/lib/xen/images/$VM.qcow2; CFG=/root/w10builds/$VM.cfg; MAC="00:14:22:6f:73:$M"
 say "=== $VM iso=$ISO unattend=$AU mac=$MAC"
 [ -e "$IMG" ] && { say "$VM image already exists, SKIP"; continue; }
 [ -e /root/iso/$ISO ] || { say "$VM ISO missing, SKIP"; continue; }
 for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
 qemu-img create -f qcow2 "$IMG" 80G >/dev/null || { say "$VM create failed"; continue; }
 sed -e "s/win10-1909-test/$VM/g" -e "s#/root/iso/win10-builds/Win10_1909.iso#/root/iso/$ISO#" \
     -e "s#/root/iso/autounattend-w10.iso#/root/iso/autounattend-$AU.iso#" -e "s/mac=00:14:22:6f:71:94/mac=$MAC/" /root/w10builds/win10-1909-test.cfg > "$CFG"
 xl create "$CFG" >/dev/null 2>&1 || { say "$VM xl create failed"; continue; }
 say "$VM install started"
 prev=0; idle=0; el=0; switched=0; domid=$(xl domid $VM)
 while true; do
  sleep 60; el=$((el+60))
  gone=1; for t in 1 2 3 4 5 6; do xl list $VM >/dev/null 2>&1 && { gone=0; break; }; sleep 5; done
  [ $gone = 1 ] && { say "$VM domain gone at ${el}s"; break; }
  # first reboot of the installer: the Windows 7/8 DVD boot prompt does not fall through to the disk
  # under SeaBIOS, so from here on boot from the disk only (the answer file is already cached on it)
  nd=$(xl domid $VM); if [ "$nd" != "$domid" ] && [ $switched = 0 ]; then
   say "$VM rebooted at ${el}s (domid $domid -> $nd): switching to disk-only boot"
   xl destroy $VM 2>/dev/null; sleep 3; sed -i 's/^boot = "dc"/boot = "c"/' "$CFG"
   xl create "$CFG" >/dev/null 2>&1 || { say "$VM xl create (disk only) failed"; break; }
   switched=1; domid=$(xl domid $VM); prev=0; idle=0; continue
  fi
  cur=$(xl list $VM | awk 'NR==2{print $6}'); ci=${cur%.*}; d=$((ci-prev)); prev=$ci
  if [ $((el % 300)) -eq 0 ]; then say "$VM t=${el}s cpu=${cur}s delta=${d}s img=$(du -m "$IMG" | cut -f1)MB"; xl qemu-monitor-command $VM "screendump $W/$VM-progress.ppm" >/dev/null 2>&1; fi
  if [ $el -ge 900 ] && [ $switched = 1 ] && [ $d -le 6 ]; then idle=$((idle+1)); else idle=0; fi
  [ $el -ge 1200 ] && [ $(du -m "$IMG" | cut -f1) -lt 2000 ] && { say "$VM STUCK (img only $(du -m "$IMG" | cut -f1)MB after ${el}s)"; break; }
  [ $idle -ge 4 ] && { say "$VM idle after ${el}s (img $(du -m "$IMG" | cut -f1)MB)"; break; }
  [ $el -ge 4200 ] && { say "$VM TIMEOUT 70 min"; break; }
 done
 xl qemu-monitor-command $VM "screendump $W/$VM-final.ppm" >/dev/null 2>&1
 xl destroy $VM 2>/dev/null; sleep 3
 qemu-img snapshot -c after-install-cold "$IMG" && say "$VM snapshot after-install-cold created" || say "$VM SNAPSHOT FAILED"
 cp "$CFG" cfg/; qemu-img snapshot -a after-install-cold "$IMG"
 xl create cfg/$VM.cfg >/dev/null 2>&1; sleep 90; xl qemu-monitor-command $VM "screendump $W/$VM-boot90.ppm" >/dev/null 2>&1
 sleep 60; xl qemu-monitor-command $VM "screendump $W/$VM-boot150.ppm" >/dev/null 2>&1
 xl destroy $VM 2>/dev/null; sleep 3; qemu-img snapshot -a after-install-cold "$IMG"
 say "$VM BOOT screenshots taken"
done
say "ALLDONE"
