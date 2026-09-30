#!/bin/bash
# Retry-loop callers on 25H2 (16 GB), pause around each attempt like DRAKVUF.
cd /root/kdbg-study/v2; R=res; S=$R/p3v2.txt; b=25h2; VM=win11-25h2-test; P=/root/profile/w11/$VM.json
log(){ echo "$(date +%H:%M:%S) $*" | tee -a $S; }
killvms(){ for o in $(xl list | awk "NR>2{print \$1}"); do xl destroy $o; done; sleep 2; }
fresh(){ killvms; qemu-img snapshot -a after-install-cold /var/lib/xen/images/$VM.qcow2; xl create /root/kdbg-study/cfg/$VM.cfg >/dev/null 2>&1; }
run(){ tag=$1; shift; fresh; ./retryprobe2-$1 $VM $P --mode $2 --pause --interval $3 --max $4 $5 > $R/p3v2-$tag.txt 2>&1
  log "P3v2 $tag lib=$1 mode=$2 interval=${3}ms $(grep -E "^RESULT" $R/p3v2-$tag.txt) attempts=$(grep -c "^attempt=" $R/p3v2-$tag.txt) slow_attempts=$(awk "/^attempt=/{split(\$NF,a,\"=\"); if(a[2]+0>5) n++} END{print n+0}" $R/p3v2-$tag.txt) errs=$(awk "/^attempt=/{print \$6}" $R/p3v2-$tag.txt | sort | uniq -c | tr "\n" " ")"; }
run ghashtable-F F ghashtable 1000 30 ""
run jsonpath-F-norefresh F jsonpath 1000 60 --no-refresh
run jsonpath-F-refresh F jsonpath 1000 1500 ""
run reinit-F-1000 F reinit 1000 1500 ""
run reinit-F-5000-a F reinit 5000 1500 ""
run reinit-F-5000-b F reinit 5000 1500 ""
run reinit-N-1000 N reinit 1000 700 ""
killvms; qemu-img snapshot -a after-install-cold /var/lib/xen/images/$VM.qcow2; log "P3v2-DONE"; touch $R/P3V2DONE
