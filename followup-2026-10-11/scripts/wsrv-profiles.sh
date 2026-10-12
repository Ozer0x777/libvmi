#!/bin/bash
# kernel JSON profiles for the Windows Server test VMs: ntoskrnl.exe from the ISO's install.wim, index 2 (Standard with desktop), PDB via pdbconv
O=/root/profile/wsrv; mkdir -p $O/krnl /mnt/x86chk; L=$O/profiles.log; : > $L
LIST="winsrv-2012r2-test:winsrv/WinServer2012R2_EVAL_x64.iso:2
winsrv-2016-test:winsrv/WinServer2016_EVAL_x64.iso:2
winsrv-2019-test:WinServer2019_EN_x64.iso:2
winsrv-2022-test:winsrv/WinServer2022_EVAL_x64.iso:2
winsrv-2025-test:winsrv/WinServer2025_EVAL_x64.iso:2
winsrv-2008r2-test:winsrv/WinServer2008R2_SP1_x64.iso:1
winsrv-2012-test:winsrv/WinServer2012_RTM_x64.iso:2
winsrv-2008-test:winsrv/WinServer2008_SP2_x64.iso:2"
for e in $LIST; do IFS=: read VM ISO IDX <<< "$e"
  out=$O/$VM.json; [ -s "$out" ] && { echo "$VM exists" >> $L; continue; }
  [ -s /root/iso/$ISO ] || { echo "$VM ISO not there yet" >> $L; continue; }
  kf=$O/krnl/$VM-ntoskrnl.exe
  if [ ! -s "$kf" ]; then
    mount -o loop,ro /root/iso/$ISO /mnt/x86chk || { echo "$VM MOUNT FAILED" >> $L; continue; }
    w=/mnt/x86chk/sources/install.wim; [ -f $w ] || w=/mnt/x86chk/sources/install.esd
    wimlib-imagex extract $w $IDX /Windows/System32/ntoskrnl.exe --dest-dir=$O/krnl --no-acls --no-attributes >/dev/null 2>&1 && mv $O/krnl/ntoskrnl.exe "$kf"
    umount /mnt/x86chk
  fi
  [ -s "$kf" ] || { echo "$VM EXTRACT FAILED" >> $L; continue; }
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
  [ -s "$O/cache-$guid.json" ] || ( cd /opt/volatility3 && python3 -m volatility3.framework.symbols.windows.pdbconv -p "$pdb" -g "$guid" -o "$O/cache-$guid.json" ) > $O/pdbconv-$VM.log 2>&1
  [ -s "$O/cache-$guid.json" ] && cp "$O/cache-$guid.json" "$out" && echo "$VM OK $pdb $guid $(stat -c%s $out) bytes" >> $L || echo "$VM FAILED $pdb $guid" >> $L
done
echo PROFILESDONE >> $L
