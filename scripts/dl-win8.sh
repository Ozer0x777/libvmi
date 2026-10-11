#!/bin/bash
# download the 4 Windows 8 / 8.1 ISOs (9200 / 9600 with Update 1, x86 + x64, English MS originals) from archive.org, verify sha1
D=/root/iso/win8; mkdir -p $D; cd $D; S=$D/STATUS.txt; : > $S
log(){ echo "$(date +%T) $*" | tee -a $S; }
get(){ name=$1 id=$2 file=$3 sha=$4
  out="$D/$name.iso"; [ -s "$out" ] && { log "$name exists"; return; }
  log "$name start $id"
  for try in 1 2 3; do wget -q -c -O "$out.part" "https://archive.org/download/$id/$file" && break; sleep 20; done
  got=$(sha1sum "$out.part" | cut -d' ' -f1)
  if [ "$got" = "$sha" ]; then mv "$out.part" "$out"; log "$name OK sha1 $got $(du -h "$out" | cut -f1)"; else log "$name SHA1 MISMATCH got=$got want=$sha"; fi; }
get Win8_9200_RTM_x86 en_windows_8_enterprise_x86_dvd_917587_202405 en_windows_8_enterprise_x86_dvd_917587.iso fefce3e64fb9ec1cc7977165328890ccc9a10656
get Win8_9200_RTM_x64 en_windows_8_x64_dvd_915440_202405 en_windows_8_x64_dvd_915440.iso 1ce53ad5f60419cf04a715cf3233f247e48beec4
get Win81_9600_Update1_x86 en_windows_8.1_with_update_x86_dvd_6051550 en_windows_8.1_with_update_x86_dvd_6051550.iso c7fa828e01e98b601e0aca8019f1cb223eb23223
get Win81_9600_Update1_x64 en_windows_8.1_with_update_x64_dvd_6051480 en_windows_8.1_with_update_x64_dvd_6051480.iso a8b5df0b0816280ae18017bc4b119c77b6c6eb79
log ALLDONE
