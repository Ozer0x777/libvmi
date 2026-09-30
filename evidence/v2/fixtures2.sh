#!/bin/bash
# Fixtures v2: trigger (paused) -> unpause -> xl save immediately -> disk snapshot -> restore -> verify state -> retry if wrong.
cd /root/kdbg-study/v2; R=res; S=$R/fixtures2.txt
declare -A RL=( [25h2]=0xbac200 [26h1]=0xc57200 ); declare -A RS=( [25h2]=0xfc5aa8 [26h1]=0xfbfbb0 )
vm(){ echo win11-$1-test; }; img(){ echo /var/lib/xen/images/$(vm $1).qcow2; }; cfg8(){ echo /root/w11builds/win11-$1-test.cfg; }
log(){ echo "$(date +%H:%M:%S) $*" | tee -a $S; }
killvms(){ for o in $(xl list | awk "NR>2{print \$1}"); do xl destroy $o; done; sleep 2; }
state(){ ./bootstate2 $(vm $1) ${RL[$1]} ${RS[$1]} --max 1 2>/dev/null | grep -m1 "^STATE" | sed -E "s/.*(PG=[01]) LMA=[01] IDT=[01] (LSTAR=[01]) (SYS=[01]) cr0=[0-9a-fx]+ (cr3=[0-9a-fx]+).*/\1 \2 \3 \4/"; }
want(){ case $1 in BOOTMGR) echo "PG=0 LSTAR=0 SYS=0 cr3=0";; PG0W) echo "PG=0 LSTAR=0 SYS=0 cr3=0x1aa000";; PG1) echo "PG=1 LSTAR=0 SYS=0 cr3=0x1aa000";; LSTAR) echo "PG=1 LSTAR=1 SYS=0";; SYS) echo "PG=1 LSTAR=1 SYS=1";; esac; }
for bs in "25h2 BOOTMGR CTX 3000" "25h2 PG0W PG0W 0" "25h2 PG1 PG1 0" "25h2 LSTAR LSTAR 0" "26h1 BOOTMGR CTX 3000" "26h1 PG0W PG0W 0" "26h1 PG1 PG1 0"; do set -- $bs; b=$1; T=$2; ON=$3; OFF=$4; F=/root/fixtures/$b-$T.sav
  ok=0; for att in 1 2 3 4 5; do
    killvms; qemu-img snapshot -a after-install-cold $(img $b); xl create $(cfg8 $b) >/dev/null 2>&1
    ./bootstate2 $(vm $b) ${RL[$b]} ${RS[$b]} --on $ON --offset $OFF --max 150 > $R/fx2-trig-$b-$T-$att.txt 2>&1
    case $T in LSTAR|SYS) ;; *) xl unpause $(vm $b) 2>/dev/null;; esac; s=$(date +%s); xl save $(vm $b) $F > $R/fx2-save-$b-$T-$att.log 2>&1; rc=$?; sv=$(( $(date +%s)-s ))
    if [ $rc -ne 0 ]; then log "FX $b $T att=$att save FAILED rc=$rc ${sv}s: $(grep -m1 error $R/fx2-save-$b-$T-$att.log | cut -c1-100)"; continue; fi
    qemu-img snapshot -d fx-$b-$T $(img $b) 2>/dev/null; qemu-img snapshot -c fx-$b-$T $(img $b) || { log "FX $b $T att=$att disk snapshot FAILED"; continue; }
    qemu-img snapshot -a fx-$b-$T $(img $b); xl restore -p $F > $R/fx2-restore-$b-$T-$att.log 2>&1 || { log "FX $b $T att=$att restore FAILED"; continue; }
    st=$(state $b); w=$(want $T); killvms
    case "$st" in *"${w%% cr3*}"*) m=1;; *) m=0;; esac
    case "$w" in *cr3=*) c=${w##*cr3=}; case "$st" in *"cr3=$c"*) ;; *) m=0;; esac;; esac
    log "FX $b $T att=$att save ${sv}s size=$(stat -c %s $F) restored_state=[$st] want=[$w] match=$m"
    [ $m = 1 ] && { ok=1; break; }
  done; [ $ok = 1 ] || log "FX $b $T GIVEUP"; done
killvms; for b in 25h2 26h1; do qemu-img snapshot -a after-install-cold $(img $b); done; log "FIXTURES2-DONE"; touch $R/FX2DONE
