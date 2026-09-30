#!/bin/bash
# Replays the LSTAR (and SYS) fixtures and checks whether the "successful" init is usable.
cd /root/kdbg-study/v2; R=res
vm(){ echo win11-$1-test; }; img(){ echo /var/lib/xen/images/$(vm $1).qcow2; }; prof(){ echo /root/profile/w11/$(vm $1).json; }
killvms(){ for o in $(xl list | awk "NR>2{print \$1}"); do xl destroy $o; done; sleep 2; }
for b in 25h2 26h1; do for T in LSTAR SYS; do F=/root/fixtures/$b-$T.sav; [ -f $F ] || { echo "R-$b-$T: no fixture"; continue; }
  for rep in 1 2; do killvms; qemu-img snapshot -a fx-$b-$T $(img $b) || { echo "R-$b-$T: disk snapshot missing"; continue; }
    xl restore -p $F > /dev/null 2>&1 || { echo "R-$b-$T: restore failed"; continue; }
    timeout 300 ./initprobe2-F $(vm $b) $(prof $b) 2>&1 | tee >(gzip -1 > $R/replay-$b-$T-r$rep.raw.gz) | grep -a -E "^RESULT|^CHECK|^PROC|^USABLE|Found PsInitialSystemProcess|kpgd from JSON|kpgd method|Failed to find kernel" | awk "{c[\$0]++; if(c[\$0]<=1) print}" > $R/replay-$b-$T-r$rep.log
    echo "R-$b-$T rep=$rep: $(grep -a -o "Found PsInitialSystemProcess at 0x[0-9a-f]*" $R/replay-$b-$T-r$rep.log | head -1) | $(grep -a -E "^RESULT" $R/replay-$b-$T-r$rep.log) | $(grep -a -E "^CHECK" $R/replay-$b-$T-r$rep.log | cut -c1-200) | $(grep -a -E "^USABLE" $R/replay-$b-$T-r$rep.log)"
  done; done; done
killvms; for b in 25h2 26h1; do qemu-img snapshot -a after-install-cold $(img $b); done; echo REPLAY-DONE
