#!/bin/bash
# download Windows 10 x86 ISOs from archive.org into their own dir, verify sha1 from the archive metadata
D=/root/iso/win10-x86; mkdir -p $D; cd $D; S=$D/STATUS.txt; : > $S
log(){ echo "$(date +%T) $*" | tee -a $S; }
get(){ build=$1 id=$2 path=$3 sha=$4
  out="$D/Win10_${build}_x86.iso"
  url="https://archive.org/download/$id/$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$path")"
  log "$build start $id"
  for try in 1 2 3; do wget -q -c -O "$out.part" "$url" && break; sleep 20; done
  got=$(sha1sum "$out.part" | cut -d' ' -f1)
  if [ "$got" = "$sha" ]; then mv "$out.part" "$out"; log "$build OK sha1 $got $(du -h "$out" | cut -f1)"; else log "$build SHA1 MISMATCH got=$got want=$sha"; fi; }
get 1507 windows-10-pro-build-10240-x86 Windows10_Pro_Build_10240_X86.iso d927a91e1dd7d9c6023d0da1dbcb16defec5b6c1
get 1511 Windows10EnterpriseTH2RTMx86Build10586 Windows_10_Enterprise_Build_10586_32Bit.ISO be25b11fc508d0350bc8b81906fec7c3d7b7343e
get 1607 en_windows_10_enterprise_version_1607_updated_jul_2016_x86_dvd_9060097 en_windows_10_enterprise_version_1607_updated_jul_2016_x86_dvd_9060097.iso 89e415fec5f4ed23d96cb543d3cea838f57a10a0
get 1703 en_windows_10_multiple_editions_version_1703_updated_july_2017_x86_dvd_10925404 en_windows_10_multiple_editions_version_1703_updated_july_2017_x86_dvd_10925404.iso c705fae388aed17303698dd684be1e94c9f714bf
get 1709 en_windows_10_multi-edition_vl_version_1709_updated_nov_2017_x86_dvd_100289940 en_windows_10_multi-edition_vl_version_1709_updated_nov_2017_x86_dvd_100289940.iso fa6c7107eae008db407ac88fb273b6d1ce5d83a0
get 1803 da_windows_10_consumer_editions_version_1803_updated_march_2018_x86_dvd_12063374 da_windows_10_consumer_editions_version_1803_updated_march_2018_x86_dvd_12063374.iso 1f95a80a3f40b9c8576dca91946e54776ff2b730
get 1809 win101809 "(GetMyOS)Windows_10_Multi(Home_Pro)_X86_V1809_Nov_EN-GB.iso" 265c8c0d86ce55173c29f727b7634e191d5e751e
get 1903 en-gb_windows_10_consumer_editions_version_1903_x86_dvd_edcb6966 en-gb_windows_10_consumer_editions_version_1903_x86_dvd_edcb6966.iso ff6fb948a01cd810d628e72d08a94ed28fa72822
get 1909 en_windows_10_consumer_editions_version_1909_updated_aug_2020_x86_dvd_430d0e79 en_windows_10_consumer_editions_version_1909_updated_aug_2020_x86_dvd_430d0e79.iso c76fd489845a37db5cfff2205055ed72589f123d
get 2004 windows-10-2004-home-pro-english-x-86 "Windows 10 2004 Home-Pro English x86.iso" 7ea6827131b176442c4f9fb007df95d0b149f6b2
get 20H2 en_windows_10_consumer_editions_version_20h2_updated_jan_2021_x86_dvd_090f17b4 en_windows_10_consumer_editions_version_20h2_updated_jan_2021_x86_dvd_090f17b4.iso 2e344ac87065075f45d370baf87518d57636505c
get 21H1 win-10-21-h-1-english-x-32-iso Win10_21H1_English_x32.iso 13f5057eb527dc561e473b80d538cb4cd4e69fb7
get 21H2 windows-10-32-bit-64-bit-1709-1803-20h2-21h1-21h2-22h2 21H2/Win10_21H2_English_x32.iso 3731950540c1136d16014fc999365da2c3a41758
get 22H2 windows-10-32-bit-64-bit-1709-1803-20h2-21h1-21h2-22h2 22H2/Win10_22H2_English_x32v1.iso c721252625c91105903dd7aefb6e1de47fbca5ae
log ALLDONE
