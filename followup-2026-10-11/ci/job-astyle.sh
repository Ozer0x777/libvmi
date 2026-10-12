#!/bin/bash -e
# mirrors .github/workflows/astyle.yml (ubuntu-latest)
export DEBIAN_FRONTEND=noninteractive
apt-get update -q; apt-get install -y git astyle
git clone -q /src /w/libvmi && cd /w/libvmi
ARTISTIC_STYLE_OPTIONS=".astylerc" astyle -Q --recursive ./*.c,*.h > astyle.out
TEST=$(cat astyle.out | wc -l)
cat astyle.out
if [ $TEST -gt 3 ]; then git diff; exit 1; fi
echo JOB_OK
