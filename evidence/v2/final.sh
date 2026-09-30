#!/bin/bash
cd /root/kdbg-study/v2; until [ -f res/ALLPOSTDONE ]; do sleep 20; done
./fix26h1pg1.sh; ./archive.sh > res/archive.txt 2>&1; touch res/FINALDONE
