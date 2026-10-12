#!/bin/bash
# Windows Server 2008 SP2 / 2008 R2 SP1 / 2012 RTM (Microsoft originals) from archive.org, sha1 checked against the archive metadata
D=/root/iso/winsrv; mkdir -p $D; cd $D; S=$D/STATUS-old.txt; : > $S
log(){ echo "$(date +%T) $*" | tee -a $S; }
get(){ name=$1 id=$2 file=$3 sha=$4
  out="$D/$name.iso"; [ -s "$out" ] && { log "$name exists"; return; }
  log "$name start $id"
  for try in 1 2 3; do wget -q -c -O "$out.part" "https://archive.org/download/$id/$file" && break; sleep 20; done
  got=$(sha1sum "$out.part" | cut -d' ' -f1)
  if [ "$got" = "$sha" ]; then mv "$out.part" "$out"; log "$name OK sha1 $got $(du -h "$out" | cut -f1)"; else log "$name SHA1 MISMATCH got=$got want=$sha"; fi; }
get WinServer2008R2_SP1_x64 en_windows_server_2008_r2_with_sp1_x64_dvd_617601_202405 en_windows_server_2008_r2_with_sp1_x64_dvd_617601.iso d3fd7bf85ee1d5bdd72de5b2c69a7b470733cd0a
get WinServer2012_RTM_x64 en_windows_server_2012_x64_dvd_915478_20260913 en_windows_server_2012_x64_dvd_915478.iso d09e752b1ee480bc7e93dfa7d5c3a9b8aac477ba
get WinServer2008_SP2_x64 en_windows_server_2008_with_sp2_x64_dvd_342336_20250329 en_windows_server_2008_with_sp2_x64_dvd_342336.iso 34c7d726c57b0f8b19ba3b40d1b4044c15fc2029
log ALLDONE
