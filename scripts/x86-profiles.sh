#!/bin/bash
# kernel JSON profiles for the Win10 x86 test VMs: ntoskrnl.exe from each ISO's install.wim (index 1 = the installed edition), PDB via volatility3 pdbconv
O=/root/profile/w10x86; mkdir -p $O/krnl /mnt/x86chk; L=$O/profiles.log; : > $L
for b in 1507 1511 1607 1703 1709 1803 1809 1903 1909 2004 20H2 21H1 21H2 22H2; do
  out=$O/win10-$b-x86-test.json; [ -s "$out" ] && { echo "$b exists" >> $L; continue; }
  k=$O/krnl/ntoskrnl-$b.exe
  if [ ! -s "$k" ]; then
    mount -o loop,ro /root/iso/win10-x86/Win10_${b}_x86.iso /mnt/x86chk || { echo "$b MOUNT FAILED" >> $L; continue; }
    w=$(ls /mnt/x86chk/sources/install.* | head -1)
    wimlib-imagex extract "$w" 1 /Windows/System32/ntoskrnl.exe --dest-dir=$O/krnl --no-acls --no-attributes >/dev/null 2>&1 && mv $O/krnl/ntoskrnl.exe "$k"
    umount /mnt/x86chk
    [ -s "$k" ] || { echo "$b EXTRACT FAILED" >> $L; continue; }
  fi
  g=$(python3 - "$k" <<'P'
import sys, struct, pefile
pe = pefile.PE(sys.argv[1])
print("MACHINE %#x" % pe.FILE_HEADER.Machine, file=sys.stderr)
for d in pe.DIRECTORY_ENTRY_DEBUG:
    if d.struct.Type == 2:
        raw = pe.__data__[d.struct.PointerToRawData:d.struct.PointerToRawData + d.struct.SizeOfData]
        d1, d2, d3 = struct.unpack("<IHH", raw[4:12])
        print("%08X%04X%04X%s%X %s" % (d1, d2, d3, raw[12:20].hex().upper(), struct.unpack("<I", raw[20:24])[0], raw[24:].split(b"\0")[0].decode())); break
P
)
  guid=${g%% *}; pdb=${g##* }
  c=$(ls $O/cache-$guid.json 2>/dev/null)
  if [ -z "$c" ]; then ( cd /opt/volatility3 && python3 -m volatility3.framework.symbols.windows.pdbconv -p "$pdb" -g "$guid" -o "$O/cache-$guid.json" ) > $O/pdbconv-$b.log 2>&1; fi
  [ -s "$O/cache-$guid.json" ] && cp "$O/cache-$guid.json" "$out" && echo "$b OK $pdb $guid $(stat -c%s $out) bytes" >> $L || echo "$b FAILED $pdb $guid" >> $L
done
# offsets table: tasks pid pname pdbase (hex), for the no-JSON attach
for b in 1507 1511 1607 1703 1709 1803 1809 1903 1909 2004 20H2 21H1 21H2 22H2; do
  python3 - $b $O/win10-$b-x86-test.json <<'P' >> $O/offsets.txt 2>&1
import sys,json
b,f=sys.argv[1],sys.argv[2]
try:
    d=json.load(open(f)); e=d["user_types"]["_EPROCESS"]["fields"]; k=d["user_types"]["_KPROCESS"]["fields"]
    print(b, "%x %x %x %x" % (e["ActiveProcessLinks"]["offset"], e["UniqueProcessId"]["offset"], e["ImageFileName"]["offset"], k["DirectoryTableBase"]["offset"]), "ptr", d["base_types"]["pointer"]["size"])
except Exception as x: print(b, "ERR", x)
P
done
echo PROFILESDONE >> $L
