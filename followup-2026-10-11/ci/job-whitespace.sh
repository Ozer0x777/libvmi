#!/bin/bash -e
# mirrors .github/workflows/whitespace.yml
export DEBIAN_FRONTEND=noninteractive
apt-get update -q; apt-get install -y git ca-certificates
git clone -q /src /w/libvmi && cd /w/libvmi
git remote add upstream https://github.com/libvmi/libvmi
git fetch upstream
git diff --check upstream/master
echo JOB_OK
