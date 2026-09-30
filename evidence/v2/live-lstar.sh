#!/bin/bash
# Proof of the false-success at the LSTAR instant, live (no fixtures): pause the guest at LSTAR+0,
# run initprobe2 twice on the frozen state, then SYS+500 as control. 6 builds, 16 GB cfg.
cd /root/kdbg-study/v2; R=res; S=$R/live-lstar.txt
declare -A RL=( [21h2]=0xab4180 [22h2]=0xae31c0 [23h2]=0xaf91c0 [24h2]=0xb7a200 [25h2]=0xbac200 [26h1]=0xc57200 )
declare -A RS=( [21h2]=0xd068a0 [22h2]=0xd1da20 [23h2]=0xd1ea20 [24h2]=0xfc4aa8 [25h2]=0xfc5aa8 [26h1]=0xfbfbb0 )
vm(){ echo win11-$1-test; }; img(){ echo /var/lib/xen/images/$(vm $1).qcow2; }; prof(){ echo /root/profile/w11/$(vm $1).json; }
log(){ echo "$(date +%H:%M:%S) $*" | tee -a $S; }
killvms(){ for o in $(xl list | awk "NR>2{print \$1}"); do xl destroy $o; done; sleep 2; }
run2(){ tag=$1 b=$2; timeout 400 ./initprobe2-F $(vm $b) $(prof $b) 2>&1 | tee >(gzip -1 > $R/$tag.raw.gz) | grep -a -E "^RESULT|^CHECK|^PROC|^USABLE|Found PsInitialSystemProcess|kpgd from JSON|kpgd method|Failed to find kernel|Guest paging" | awk "{c[\$0]++; if(c[\$0]<=1) print}" > $R/$tag.log
  echo "$(grep -a -o "Found PsInitialSystemProcess at 0x[0-9a-f]*" $R/$tag.log | head -1 | sed s/Found.PsInitialSystemProcess.at/sysproc=/) $(grep -a -E "^RESULT" $R/$tag.log) $(grep -a -E "^CHECK" $R/$tag.log | sed -E "s/CHECK //" | cut -c1-150) $(grep -a -E "^USABLE" $R/$tag.log)"; }
for b in 21h2 22h2 23h2 24h2 25h2 26h1; do
  killvms; qemu-img snapshot -a after-install-cold $(img $b); xl create /root/kdbg-study/cfg/$(vm $b).cfg >/dev/null 2>&1
  ./bootstate2 $(vm $b) ${RL[$b]} ${RS[$b]} --on LSTAR --offset 0 --max 150 > $R/ll-trig-$b.txt 2>&1
  st=$(grep -E "^PAUSED " $R/ll-trig-$b.txt | sed -E "s/.*(PG=[01]) LMA=[01] IDT=[01] (LSTAR=[01]) (SYS=[01]).*/\1 \2 \3/")
  log "LL $b LSTAR+0 state=[$st] run1: $(run2 ll-$b-lstar-r1 $b)"
  log "LL $b LSTAR+0 state=[$st] run2: $(run2 ll-$b-lstar-r2 $b)"
  xl unpause $(vm $b); killvms; qemu-img snapshot -a after-install-cold $(img $b); xl create /root/kdbg-study/cfg/$(vm $b).cfg >/dev/null 2>&1
  ./bootstate2 $(vm $b) ${RL[$b]} ${RS[$b]} --on SYS --offset 500 --max 150 > $R/ll-trig-$b-sys.txt 2>&1
  st=$(grep -E "^PAUSED " $R/ll-trig-$b-sys.txt | sed -E "s/.*(PG=[01]) LMA=[01] IDT=[01] (LSTAR=[01]) (SYS=[01]).*/\1 \2 \3/")
  log "LL $b SYS+500 state=[$st] ctrl: $(run2 ll-$b-sys $b)"; xl unpause $(vm $b)
done
killvms; for b in 21h2 22h2 23h2 24h2 25h2 26h1; do qemu-img snapshot -a after-install-cold $(img $b); done; log "LIVE-LSTAR-DONE"; touch $R/LLDONE
