#!/bin/bash
# Full validation pipeline v2. One VM at a time. Results in res/.
cd /root/kdbg-study/v2; R=/root/kdbg-study/v2/res; S=$R/summary.txt
declare -A RL=( [21h2]=0xab4180 [22h2]=0xae31c0 [23h2]=0xaf91c0 [24h2]=0xb7a200 [25h2]=0xbac200 [26h1]=0xc57200 [w10-1809]=0x330140 )
declare -A RS=( [21h2]=0xd068a0 [22h2]=0xd1da20 [23h2]=0xd1ea20 [24h2]=0xfc4aa8 [25h2]=0xfc5aa8 [26h1]=0xfbfbb0 [w10-1809]=0x4c52e0 )
vm(){ case $1 in w10-1809) echo win10-1809-test;; *) echo win11-$1-test;; esac; }
cfg(){ case $1 in w10-1809) echo /root/w10builds/win10-1809-test.cfg;; *) echo /root/kdbg-study/cfg/win11-$1-test.cfg;; esac; }
cfg8(){ echo /root/w11builds/win11-$1-test.cfg; }
prof(){ case $1 in w10-1809) echo /root/profile/w10/win10-1809-test.json;; *) echo /root/profile/w11/win11-$1-test.json;; esac; }
img(){ echo /var/lib/xen/images/$(vm $1).qcow2; }
log(){ echo "$(date +%H:%M:%S) $*" | tee -a $S; }
killvms(){ for o in $(xl list | awk "NR>2{print \$1}"); do xl destroy $o; done; sleep 2; }
fresh(){ killvms; qemu-img snapshot -a after-install-cold $(img $1) || log "SNAPFAIL $1"; xl create ${2:-$(cfg $1)} >/dev/null 2>&1; }
classify(){ f=$1; c=json
  grep -a -q "Guest paging is disabled" $f && c=FAILFAST
  grep -a -q "Attempting KdDebuggerDataBlock" $f && c=KDBG
  grep -a -q "init from JSON profile success" $f && c=json || { [ $c = json ] && c=NOJSON; }
  grep -a -q "Failed to find kernel page directory" $f && c=$c+NOKPGD
  grep -a -q "failed to find System process" $f && c=$c+SYSSCAN
  echo $c; }
KEYS="Guest paging is disabled|Paging disabled|RESULT|init from JSON profile success|Attempting KdDebuggerDataBlock|Trying find_kdbg|All KdDebuggerDataBlock|kpgd method|kpgd from JSON|Trying kpcr_find|KernBase PA|KernBase VA|Failed|failed to find|Error calculating|searching for process|IA-32e"
probe(){ # $1 tag $2 vm $3 profile $4 timeout $5 probe-binary
  s=$(date +%s%N); timeout $4 $5 $2 $3 2>&1 | tee >(gzip -1 > $R/$1.raw.gz) | grep -a -E "$KEYS" | awk "{c[\$0]++; if(c[\$0]<=3) print}" > $R/$1.log; rc=${PIPESTATUS[0]}
  echo "rc=$rc wall=$(( ($(date +%s%N)-s)/1000000 ))ms class=$(classify $R/$1.log)"; }
trig(){ # $1 build $2 target $3 offset -> leaves domain paused; prints pause state line
  ./bootstate2 $(vm $1) ${RL[$1]} ${RS[$1]} --on $2 --offset $3 --max 150 > $R/trig-$1-$2.txt 2>&1; rc=$?
  ps=$(grep -E "^PAUSED " $R/trig-$1-$2.txt | sed -E "s/.*(PG=[01] LMA=[01] IDT=[01] LSTAR=[01] SYS=[01]).*/\1/"); tt=$(grep -E "^TRIGGER" $R/trig-$1-$2.txt | sed -E "s/.*at t=([0-9.]+).*/\1/")
  st=$(xl list | awk -v v=$(vm $1) "\$1==v{print \$5}")
  echo "trig_rc=$rc t=$tt state=[$ps] xl=$st"; }

log "===== P0 boot-phase map, 6 Win11 builds (16 GB/12 vCPU)"
for b in 21h2 22h2 23h2 24h2 25h2 26h1; do fresh $b; ./bootstate2 $(vm $b) ${RL[$b]} ${RS[$b]} --max 120 > $R/map-$b.txt 2>&1; log "P0 $b $(grep SUMMARY $R/map-$b.txt) flips=$(grep -c "^STATE" $R/map-$b.txt)"; done

log "===== P2 state-targeted attaches, paused guest, fixed libvmi (F-dbg)"
for b in 21h2 22h2 23h2 24h2 25h2 26h1; do
  for tgt in "CTX 3000 60" "PG0W 0 60" "PG1 0 200" "LSTAR 0 600" "SYS 500 60"; do set -- $tgt; T=$1; O=$2; TO=$3
    if [ $T = PG1 ] && { [ $b = 25h2 ] || [ $b = 26h1 ]; }; then TO=1500; fi
    fresh $b; tr=$(trig $b $T $O); r=$(probe p2-$b-$T $(vm $b) $(prof $b) $TO ../initprobe-F); log "P2 $b target=$T+${O}ms $tr | $r"
    xl unpause $(vm $b) 2>/dev/null; done; done

log "===== P2b DRAKVUF main + upstream libvmi (N-rel), attached in winload PG=1, 25H2"
b=25h2; fresh $b; tr=$(trig $b PG1 0); s=$(date +%s%N); LD_LIBRARY_PATH=/opt/libvmi-N-rel/lib timeout 1500 /root/drakvuf/build/drakvuf -r $(prof $b) -d $(vm $b) -a procmon -t 20 > $R/p2b-drakvuf.out 2> $R/p2b-drakvuf.err; rc=$?
log "P2b drakvuf $tr | rc=$rc wall=$(( ($(date +%s%N)-s)/1000000 ))ms events=$(grep -a -c "^\[PROCMON\]" $R/p2b-drakvuf.out) xl_after=$(xl list | awk -v v=$(vm $b) "\$1==v{print \$5}")"; xl unpause $(vm $b) 2>/dev/null

log "===== P4 fixtures (8 GB cfg) 25H2 + 26H1: save at PG0W/PG1/LSTAR/SYS+500, then replay + probe"
for b in 25h2 26h1; do for tgt in "PG0W 0 60" "PG1 0 1500" "LSTAR 0 600" "SYS 500 60"; do set -- $tgt; T=$1; O=$2; TO=$3
  fresh $b $(cfg8 $b); tr=$(trig $b $T $O); F=/root/fixtures/$b-$T.sav
  s=$(date +%s); xl save $(vm $b) $F > $R/fx-save-$b-$T.log 2>&1; srce=$?; sv=$(( $(date +%s)-s ))
  qemu-img snapshot -c fx-$b-$T $(img $b) 2>>$R/fx-save-$b-$T.log; qs=$?
  log "P4 save $b $T $tr | save_rc=$srce ${sv}s size=$(stat -c %s $F 2>/dev/null) disksnap_rc=$qs"
  done; done
for b in 25h2 26h1; do for tgt in "PG0W 60" "PG1 1500" "LSTAR 600" "SYS 60"; do set -- $tgt; T=$1; TO=$2; F=/root/fixtures/$b-$T.sav
  killvms; qemu-img snapshot -a fx-$b-$T $(img $b); s=$(date +%s); xl restore -p $F > $R/fx-restore-$b-$T.log 2>&1; rrc=$?; rs=$(( $(date +%s)-s ))
  st=$(xl list | awk -v v=$(vm $b) "\$1==v{print \$5}"); r=$(probe p4-$b-$T $(vm $b) $(prof $b) $TO ../initprobe-F)
  log "P4 replay $b $T restore_rc=$rrc ${rs}s xl=$st | $r"; killvms; qemu-img snapshot -a after-install-cold $(img $b); done; done

log "===== P9 stale page_mode demo (retry without vmi_init_paging), 25H2"
b=25h2; fresh $b; ./retryprobe-F $(vm $b) $(prof $b) --pause --no-refresh --max 45 > $R/p9-norefresh.txt 2>&1; log "P9 no-refresh: $(grep -E "^RESULT" $R/p9-norefresh.txt) attempts_after_20s_failing=$(awk -F"[= ]" "/^attempt=/ && \$4>20 && /os=0/" $R/p9-norefresh.txt | wc -l)"
./retryprobe-F $(vm $b) $(prof $b) --pause --max 60 > $R/p9-refresh.txt 2>&1; log "P9 with-refresh right after: $(grep -E "^RESULT" $R/p9-refresh.txt)"

log "===== P8 ASan (fixed libvmi built with -fsanitize=address), 25H2"
b=25h2; fresh $b; tr=$(trig $b CTX 3000); ASAN_OPTIONS=detect_leaks=0 timeout 120 ../initprobe-asan $(vm $b) $(prof $b) > $R/p8-caseA.txt 2>&1; log "P8 caseA $tr | rc=$? asan_errors=$(grep -c "ERROR: AddressSanitizer" $R/p8-caseA.txt) $(grep -a RESULT $R/p8-caseA.txt)"; xl unpause $(vm $b)
fresh $b; tr=$(trig $b SYS 500); ASAN_OPTIONS=detect_leaks=0 timeout 120 ../initprobe-asan $(vm $b) $(prof $b) > $R/p8-ok.txt 2>&1; log "P8 ok $tr | rc=$? asan_errors=$(grep -c "ERROR: AddressSanitizer" $R/p8-ok.txt) $(grep -a RESULT $R/p8-ok.txt)"
ASAN_OPTIONS=detect_leaks=0 timeout 120 /opt/libvmi-F-asan/bin/vmi-process-list -n $(vm $b) -j $(prof $b) > $R/p8-pl.txt 2>&1; log "P8 process-list rc=$? procs=$(grep -c "^\[" $R/p8-pl.txt) asan_errors=$(grep -c "ERROR: AddressSanitizer" $R/p8-pl.txt)"
ASAN_OPTIONS=detect_leaks=1 timeout 120 ../initprobe-asan $(vm $b) $(prof $b) > $R/p8-leaks.txt 2>&1; log "P8 leaks(info) rc=$? leak_bytes=$(grep -E "SUMMARY: AddressSanitizer" $R/p8-leaks.txt | head -1)"; xl unpause $(vm $b)

log "===== P7 Linux non-regression (linux-test, N vs F)"
killvms; xl create /root/linuxlab/linux-test.cfg >/dev/null 2>&1; sleep 45
for v in N F; do timeout 120 /opt/libvmi-$v-rel/bin/vmi-process-list -n linux-test -j /root/linuxlab/debian12-6.1.0-53.json > $R/p7-$v.txt 2>$R/p7-$v.err; echo "rc=$?" > $R/p7-$v.rc; done
log "P7 linux procs_N=$(grep -c "^\[" $R/p7-N.txt) procs_F=$(grep -c "^\[" $R/p7-F.txt) $(cat $R/p7-N.rc) $(cat $R/p7-F.rc) diff_lines=$(diff <(sort $R/p7-N.txt) <(sort $R/p7-F.txt) | wc -l)"
xl shutdown -w -F linux-test >/dev/null 2>&1 & sleep 30; killvms

log "===== P5 file mode non-regression (25H2 8 GB dump, N vs F)"
b=25h2; fresh $b $(cfg8 $b); sleep 75; xl pause $(vm $b); s=$(date +%s); ( /opt/libvmi-F-rel/bin/vmi-dump-memory -n $(vm $b) /root/dump-25h2.raw || /opt/libvmi-F-rel/bin/vmi-dump-memory $(vm $b) /root/dump-25h2.raw ) > $R/p5-dump.log 2>&1; log "P5 dump rc=$? $(( $(date +%s)-s ))s size=$(stat -c %s /root/dump-25h2.raw)"; killvms
for v in N F; do s=$(date +%s); timeout 1800 /opt/libvmi-$v-rel/bin/vmi-process-list -n /root/dump-25h2.raw -j $(prof $b) > $R/p5-$v.txt 2> $R/p5-$v.err; echo "rc=$? $(( $(date +%s)-s ))s" > $R/p5-$v.rc; done
log "P5 filemode procs_N=$(grep -c "^\[" $R/p5-N.txt) procs_F=$(grep -c "^\[" $R/p5-F.txt) N:$(cat $R/p5-N.rc) F:$(cat $R/p5-F.rc) diff_lines=$(diff <(sort $R/p5-N.txt) <(sort $R/p5-F.txt) | wc -l) failfast_msg_in_F=$(grep -a -c "Guest paging" $R/p5-F.err $R/p5-F.txt | tr "\n" " ")"

log "===== P6 Windows 10 1809 (4 GB/2 vCPU): map + state-targeted attaches (F-dbg)"
b=w10-1809; fresh $b; ./bootstate2 $(vm $b) ${RL[$b]} ${RS[$b]} --max 150 > $R/map-$b.txt 2>&1; log "P6 map $(grep SUMMARY $R/map-$b.txt) flips=$(grep -c "^STATE" $R/map-$b.txt)"
for tgt in "CTX 3000 60" "PG0W 0 60" "PG1 0 900" "LSTAR 0 600" "SYS 500 60"; do set -- $tgt; T=$1; O=$2; TO=$3
  fresh $b; tr=$(trig $b $T $O); r=$(probe p6-$b-$T $(vm $b) $(prof $b) $TO ../initprobe-F); log "P6 $b target=$T+${O}ms $tr | $r"; xl unpause $(vm $b) 2>/dev/null; done
killvms; qemu-img snapshot -a after-install-cold $(img $b)

log "===== P3 retry-loop caller (one instance, pause around each attempt), 25H2"
b=25h2
for run in "F 1000 1500" "F 5000 1500" "F 5000 1500" "N 1000 700"; do set -- $run; L=$1; I=$2; M=$3
  fresh $b; ./retryprobe-$L $(vm $b) $(prof $b) --pause --interval $I --max $M > $R/p3-$L-$I-$RANDOM.txt 2>&1; f=$(ls -t $R/p3-$L-$I-*.txt | head -1)
  log "P3 lib=$L interval=${I}ms $(grep -E "^RESULT" $f) attempts=$(grep -c "^attempt=" $f) slow_attempts=$(awk "/^attempt=/{split(\$NF,a,\"=\"); if(a[2]+0>5) n++} END{print n+0}" $f)"; done
killvms; for b in 21h2 22h2 23h2 24h2 25h2 26h1; do qemu-img snapshot -a after-install-cold $(img $b); done
log "===== ALL DONE"; touch $R/DONE
