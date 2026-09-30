#!/bin/bash
# Regenerate fx-26h1-PG1 with the paused-save method (deterministic state), verify after restore, retry up to 6 times.
cd /root/kdbg-study/v2; R=res; S=$R/fix26h1pg1.txt; b=26h1; VM=win11-26h1-test; IMG=/var/lib/xen/images/$VM.qcow2; F=/root/fixtures/26h1-PG1.sav
log(){ echo "$(date +%H:%M:%S) $*" | tee -a $S; }
killvms(){ for o in $(xl list | awk "NR>2{print \$1}"); do xl destroy $o; done; sleep 2; }
rm -f $F; qemu-img snapshot -d fx-26h1-PG1 $IMG 2>/dev/null
for att in 1 2 3 4 5 6; do
  killvms; qemu-img snapshot -a after-install-cold $IMG; xl create /root/w11builds/$VM.cfg >/dev/null 2>&1
  ./bootstate2 $VM 0xc57200 0xfbfbb0 --on PG1 --offset 0 --max 150 > $R/fixpg1-trig-$att.txt 2>&1
  s=$(date +%s); xl save $VM $F > $R/fixpg1-save-$att.log 2>&1; rc=$?; sv=$(( $(date +%s)-s ))
  if [ $rc -ne 0 ]; then log "FIXPG1 att=$att save FAILED rc=$rc ${sv}s"; rm -f $F; continue; fi
  qemu-img snapshot -c fx-26h1-PG1 $IMG || { log "FIXPG1 att=$att disk snapshot FAILED"; continue; }
  qemu-img snapshot -a fx-26h1-PG1 $IMG; xl restore -p $F > $R/fixpg1-restore-$att.log 2>&1 || { log "FIXPG1 att=$att restore FAILED"; continue; }
  st=$(./bootstate2 $VM 0xc57200 0xfbfbb0 --max 1 2>/dev/null | grep -m1 "^STATE" | sed -E "s/.*(PG=[01]) LMA=[01] IDT=[01] (LSTAR=[01]) (SYS=[01]) cr0=[0-9a-fx]+ (cr3=[0-9a-fx]+).*/\1 \2 \3 \4/"); killvms
  log "FIXPG1 att=$att save ${sv}s size=$(stat -c %s $F) restored_state=[$st]"
  case "$st" in "PG=1 LSTAR=0 SYS=0 cr3=0x1aa000") log "FIXPG1 OK"; break;; *) qemu-img snapshot -d fx-26h1-PG1 $IMG; rm -f $F;; esac
done
killvms; qemu-img snapshot -a after-install-cold $IMG; log "FIXPG1-DONE"; touch $R/FIXPG1DONE
