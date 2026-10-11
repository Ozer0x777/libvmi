#!/bin/bash
# download the 4 final Windows 7 ISOs (RTM 7600 / SP1 7601, x86 + x64) from archive.org, verify sha1 from the archive metadata
D=/root/iso/win7; mkdir -p $D; cd $D; S=$D/STATUS.txt; : > $S
log(){ echo "$(date +%T) $*" | tee -a $S; }
get(){ name=$1 id=$2 file=$3 sha=$4
  out="$D/$name.iso"
  log "$name start $id"
  for try in 1 2 3; do wget -q -c -O "$out.part" "https://archive.org/download/$id/$file" && break; sleep 20; done
  got=$(sha1sum "$out.part" | cut -d' ' -f1)
  if [ "$got" = "$sha" ]; then mv "$out.part" "$out"; log "$name OK sha1 $got $(du -h "$out" | cut -f1)"; else log "$name SHA1 MISMATCH got=$got want=$sha"; fi; }
get Win7_7600_RTM_x86 en_windows_7_ultimate_x86_dvd_x15-65921_202107 en_windows_7_ultimate_x86_dvd_x15-65921.iso 5395dc4b38f7bdb1e005ff414deedfdb16dbf610
get Win7_7600_RTM_x64 en_windows_7_ultimate_x64_dvd_x15-65922_202107 en_windows_7_ultimate_x64_dvd_x15-65922.iso 326327cc2ff9f05379f5058c41be6bc5e004baa7
get Win7_7601_SP1_x86 en_windows_7_ultimate_with_sp1_x86_dvd_u_677460_202107 en_windows_7_ultimate_with_sp1_x86_dvd_u_677460.iso 65fce0f445d9bf7e78e43f17e441e08c63722657
get Win7_7601_SP1_x64 en_windows_7_ultimate_with_sp1_x64_dvd_u_677332_202107 en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso 36ae90defbad9d9539e649b193ae573b77a71c83
log ALLDONE
