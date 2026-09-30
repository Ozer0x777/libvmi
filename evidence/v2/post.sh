#!/bin/bash
# Runs after pipeline.sh: (1) live LSTAR false-success proof, (2) Linux N vs F with the guest paused, (3) fixtures retry.
cd /root/kdbg-study/v2; R=res; S=$R/post.txt
log(){ echo "$(date +%H:%M:%S) $*" | tee -a $S; }
killvms(){ for o in $(xl list | awk "NR>2{print \$1}"); do xl destroy $o; done; sleep 2; }
log "===== POST1 live LSTAR proof"; ./live-lstar.sh >> $S 2>&1
log "===== POST2 Linux N vs F, paused"
killvms; xl create /root/linuxlab/linux-test.cfg >/dev/null 2>&1; sleep 50; xl pause linux-test
for v in N F; do timeout 120 /opt/libvmi-$v-rel/bin/vmi-process-list -n linux-test -j /root/linuxlab/debian12-6.1.0-53.json > $R/post-linux-$v.txt 2>$R/post-linux-$v.err; echo "rc=$?" > $R/post-linux-$v.rc; done
xl unpause linux-test
log "POST2 linux(paused) procs_N=$(grep -c "^\[" $R/post-linux-N.txt) procs_F=$(grep -c "^\[" $R/post-linux-F.txt) $(cat $R/post-linux-N.rc) $(cat $R/post-linux-F.rc) diff_lines=$(diff <(sort $R/post-linux-N.txt) <(sort $R/post-linux-F.txt) | wc -l)"
xl shutdown -w -F linux-test >/dev/null 2>&1 & sleep 30; killvms
log "===== POST3 fixtures retry"; ./fixtures2.sh >> $S 2>&1
log "===== POST DONE"; touch $R/POSTDONE
