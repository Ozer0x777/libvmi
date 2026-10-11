#!/bin/bash
# kernel JSON profiles for the Win7/8 test VMs: kernel files from each ISO's install.wim (edition installed), PDB via volatility3 pdbconv
O=/root/profile/w78; mkdir -p $O/krnl /mnt/x86chk; L=$O/profiles.log; : > $L
# vm:iso:wim index:kernel files
LIST="win7-7600-x86-test:win7/Win7_7600_RTM_x86.iso:5:ntoskrnl.exe,ntkrnlpa.exe
win7-7600-x64-test:win7/Win7_7600_RTM_x64.iso:4:ntoskrnl.exe
win7-7601-x86-test:win7/Win7_7601_SP1_x86.iso:5:ntoskrnl.exe,ntkrnlpa.exe
win7-7601-x64-test:win7/Win7_7601_SP1_x64.iso:4:ntoskrnl.exe
win8-9200-x86-test:win8/Win8_9200_RTM_x86.iso:1:ntoskrnl.exe
win8-9200-x64-test:win8/Win8_9200_RTM_x64.iso:1:ntoskrnl.exe
win81-9600-x86-test:win8/Win81_9600_Update1_x86.iso:1:ntoskrnl.exe
win81-9600-x64-test:win8/Win81_9600_Update1_x64.iso:1:ntoskrnl.exe"
for e in $LIST; do IFS=: read VM ISO IDX KS <<< "$e"
  mount -o loop,ro /root/iso/$ISO /mnt/x86chk || { echo "$VM MOUNT FAILED" >> $L; continue; }
  for k in ${KS//,/ }; do
    tag=${k%.exe}; kf=$O/krnl/$VM-$k; out=$O/$VM${tag/ntoskrnl/}.json; [ $tag = ntkrnlpa ] && out=$O/$VM-ntkrnlpa.json
    [ -s "$kf" ] || { wimlib-imagex extract /mnt/x86chk/sources/install.wim $IDX /Windows/System32/$k --dest-dir=$O/krnl --no-acls --no-attributes >/dev/null 2>&1 && mv $O/krnl/$k "$kf"; }
    [ -s "$kf" ] || { echo "$VM $k EXTRACT FAILED" >> $L; continue; }
    g=$(python3 - "$kf" <<'P'
import sys, struct, pefile
pe = pefile.PE(sys.argv[1])
for d in pe.DIRECTORY_ENTRY_DEBUG:
    if d.struct.Type == 2:
        raw = pe.__data__[d.struct.PointerToRawData:d.struct.PointerToRawData + d.struct.SizeOfData]
        d1, d2, d3 = struct.unpack("<IHH", raw[4:12])
        print("%08X%04X%04X%s%X %s" % (d1, d2, d3, raw[12:20].hex().upper(), struct.unpack("<I", raw[20:24])[0], raw[24:].split(b"\0")[0].decode())); break
P
)
    guid=${g%% *}; pdb=${g##* }
    [ -s "$O/cache-$guid.json" ] || ( cd /opt/volatility3 && python3 -m volatility3.framework.symbols.windows.pdbconv -p "$pdb" -g "$guid" -o "$O/cache-$guid.json" ) > $O/pdbconv-$VM-$tag.log 2>&1
    [ -s "$O/cache-$guid.json" ] && cp "$O/cache-$guid.json" "$out" && echo "$VM $k OK $pdb $guid $(stat -c%s $out) bytes -> $(basename $out)" >> $L || echo "$VM $k FAILED $pdb $guid" >> $L
  done
  umount /mnt/x86chk
done
echo PROFILESDONE >> $L
