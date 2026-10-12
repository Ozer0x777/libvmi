#!/bin/bash
# final regression with the PR build (/opt/libvmi-CR3-dbg = b29b3aa) on every guest, then the CI replay on the same head
L=/root/w10builds/final-chain.log; say(){ echo "$(date +%F\ %T) $*" | tee -a $L; }
while ! grep -q ALLDONE /root/w10builds/wsrv/winver/STATUS.txt 2>/dev/null; do sleep 20; done; sleep 5
cd /root/kdbg-study
# keep the earlier results
D=$(date +%Y%m%d-%H%M)
[ -d /root/w10builds/x86/attach ] && mv /root/w10builds/x86/attach /root/w10builds/x86/attach-fix1-$D
[ -d /root/w10builds/x86/x64-regression ] && mv /root/w10builds/x86/x64-regression /root/w10builds/x86/x64-regression-fix1-$D
[ -d /root/w10builds/w78/attach ] && mv /root/w10builds/w78/attach /root/w10builds/w78/attach-fix1-$D
[ -d /root/w10builds/wsrv/attach ] && mv /root/w10builds/wsrv/attach /root/w10builds/wsrv/attach-fix1-$D
sed 's/^ sleep 90$/ sleep 150/' x86test.sh > x86test150.sh; sed 's/^ sleep 90$/ sleep 150/' x64test.sh > x64test150.sh; chmod +x x86test150.sh x64test150.sh
grep -c "sleep 150" x86test150.sh x64test150.sh | tee -a $L
say "regression start"
./x86test150.sh > x86test-final.nohup 2>&1; say "x86 done"
./x64test150.sh > x64test-final.nohup 2>&1; say "x64 done"
./w78test.sh > w78test-final.nohup 2>&1; say "w78 done"
./wsrvtest.sh > wsrvtest-final.nohup 2>&1; say "wsrv done"
# CI replay on the exact head
cd /root/libvmi-K-ci && git am /root/ci-K/p3/0001-*.patch /root/ci-K/p3/0002-*.patch >> $L 2>&1 && git log --format="%h %s" -5 >> $L
cd /root/ci-K && cp ci-summary.txt ci-summary.prev-fe57a67 && bash run-all.sh > ci-summary.txt 2>&1; say "CI done"
say "FINALDONE"
