#!/bin/bash
# Windows Server evaluation ISOs from Microsoft (no published sha1: the size is checked against Content-Length, the wim is checked afterwards)
D=/root/iso/winsrv; mkdir -p $D; cd $D; S=$D/STATUS.txt; : > $S
log(){ echo "$(date +%T) $*" | tee -a $S; }
get(){ name=$1 url=$2
  out="$D/$name.iso"; [ -s "$out" ] && { log "$name exists"; return; }
  want=$(curl -s -I -L --max-time 60 "$url" | grep -i content-length | tail -1 | tr -dc 0-9)
  log "$name start (expect $want bytes)"
  for try in 1 2 3; do wget -q -c -O "$out.part" "$url" && break; sleep 30; done
  got=$(stat -c%s "$out.part")
  if [ "$got" = "$want" ]; then mv "$out.part" "$out"; log "$name OK $(du -h "$out" | cut -f1) sha256 $(sha256sum "$out" | cut -c1-16)"; else log "$name SIZE MISMATCH got=$got want=$want"; fi; }
get WinServer2016_EVAL_x64 "https://software-static.download.prss.microsoft.com/pr/download/Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.ISO"
get WinServer2022_EVAL_x64 "https://software-static.download.prss.microsoft.com/sg/download/888969d5-f34g-4e03-ac9d-1f9786c66749/SERVER_EVAL_x64FRE_en-us.iso"
get WinServer2025_EVAL_x64 "https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
get WinServer2012R2_EVAL_x64 "https://download.microsoft.com/download/6/2/A/62A76ABB-9990-4EFC-A4FE-C7D698DAEB96/9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.ISO"
log ALLDONE
