#!/bin/bash
# Bundle everything a reader needs (no raw multi-GB logs): summaries, filtered logs, boot maps, host specs, probe sources, scripts.
cd /root/kdbg-study; OUT=/root/libvmi-early-boot-evidence-$(date +%Y%m%d).tar.gz
tar czf $OUT --exclude="*.raw.gz" -C /root/kdbg-study v2/res v2/*.c v2/*.sh host-specs.txt final/T1.txt final/T2.txt final/T3.txt final/ebG/*.log eb-summary.txt ebF-summary.txt ebD-summary.txt ab/summary.txt cyc-summary.txt mx-summary.txt seg-summary.txt seg1-summary.txt seg2-summary.txt t2-summary.txt t3-summary.txt final/libvmi-commits.txt 2>/dev/null
ls -l $OUT | awk "{print \$5, \$9}"; tar tzf $OUT | wc -l
