#!/bin/bash -e
# mirrors cognitive-complexity job: PR tree, then a fresh master checkout, then compare
export CC=clang-15 CXX=clang++-15 VERSION=15
cd /w && bash -e deps-clang15.sh
git clone -q /src /w/pr && cd /w/pr
source /w/complexity-calc.sh
mv complex-functions.log /tmp/
echo $complexity > /tmp/complexity.score
git clone -q /src /w/master && cd /w/master && git checkout -q master
source /w/complexity-calc.sh
echo $complexity > complexity.score
SCORE_PR=$(cat /tmp/complexity.score); SCORE_MAIN=$(cat complexity.score)
echo "Complexity of PR: $SCORE_PR"; echo "Complexity of main: $SCORE_MAIN"
if [ $SCORE_PR -gt $SCORE_MAIN ]; then diff complex-functions.log /tmp/complex-functions.log || :; echo "Cognitive complexity increase, please rework your PR"; exit 1; fi
echo JOB_OK
