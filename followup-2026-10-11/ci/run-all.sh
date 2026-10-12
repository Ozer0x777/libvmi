#!/bin/bash
cd /root/ci-K; mkdir -p logs
run(){ name=$1 img=$2; shift 2
  podman run --rm --network=host -v /root/libvmi-K-ci:/src:ro,Z -v /root/ci-K:/w0:ro,Z $img bash -c "mkdir -p /w && cp /w0/*.sh /w/ && cd /w && bash -e $*" > logs/$name.log 2>&1
  r=$?; echo "$name rc=$r $(grep -c "^Done building" logs/$name.log) builds $(tail -1 logs/$name.log | cut -c1-80)"; }
run astyle ubuntu:24.04 job-astyle.sh
run whitespace ubuntu:24.04 job-whitespace.sh
for cc in gcc clang; do for b in autotools cmake; do run compile-$cc-$b ubuntu:22.04 job-compile.sh $cc $b; done; done
for cc in gcc clang; do run container-$cc debian:bookworm-slim job-container.sh $cc; done
run scan-build ubuntu:24.04 job-scanbuild.sh
run cognitive-complexity ubuntu:24.04 job-complexity.sh
echo ALLDONE
