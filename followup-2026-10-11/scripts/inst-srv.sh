#!/bin/bash
# unattended install of the Windows Server test VMs (x64), one at a time, + snapshot + boot screenshots (same logic as inst-78b.sh)
W=/root/w10builds/wsrv; mkdir -p $W; ST=$W/STATUS.txt; : >> $ST
cd /root/kdbg-study
say(){ echo "$(date +%F\ %T) $*" | tee -a $ST; }
LIST="winsrv-2012r2-test:winsrv/WinServer2012R2_EVAL_x64.iso:winsrv2012r2:11
winsrv-2016-test:winsrv/WinServer2016_EVAL_x64.iso:winsrv:12
winsrv-2019-test:WinServer2019_EN_x64.iso:winsrv:13
winsrv-2022-test:winsrv/WinServer2022_EVAL_x64.iso:winsrv:14
winsrv-2025-test:winsrv/WinServer2025_EVAL_x64.iso:winsrv:15"
for e in ${ONLY:-$LIST}; do
 IFS=: read VM ISO AU M <<< "$e"
 IMG=/var/lib/xen/images/$VM.qcow2; CFG=/root/w10builds/$VM.cfg; MAC="00:14:22:6f:74:$M"
 say "=== $VM iso=$ISO unattend=$AU mac=$MAC"
 [ -e "$IMG" ] && { say "$VM image already exists, SKIP"; continue; }
 [ -e /root/iso/$ISO ] || { say "$VM ISO missing, SKIP"; continue; }
 for o in $(xl list | awk 'NR>2{print $1}'); do say "another domain running: $o -> abort"; exit 1; done
 qemu-img create -f qcow2 "$IMG" 80G >/dev/null || { say "$VM create failed"; continue; }
 cat > "$CFG" <<CFG
name = "$VM"
type = "hvm"
memory = 4096
maxmem = 4096
vcpus = 2
cpus = "8-23"
altp2m = "external"
boot = "dc"
disk = [
    "format=qcow2, vdev=hda, access=w, target=$IMG",
    "format=raw, vdev=hdb, access=r, devtype=cdrom, target=/root/iso/$ISO",
    "format=raw, vdev=hdc, access=r, devtype=cdrom, target=/root/iso/autounattend-$AU.iso",
]
vif = [ "bridge=xen-mal0, mac=$MAC, type=ioemu, model=e1000" ]
cpuid = "host,hypervisor=0"
xen_platform_pci = 0
viridian = 0
acpi_s3 = 1
acpi_s4 = 1
smbios = [
    "bios_vendor=American Megatrends Inc.",
    "bios_version=2.17.1246",
    "system_manufacturer=Dell Inc.",
    "system_product_name=OptiPlex 7090",
    "system_version=1.0",
    "system_serial_number=7F3K2QP",
    "baseboard_manufacturer=Dell Inc.",
    "baseboard_product_name=0D6H9T",
    "enclosure_asset_tag=7F3K2QP",
]
sdl = 0
vnc = 1
vnclisten = "127.0.0.1"
on_poweroff = "destroy"
on_reboot   = "restart"
on_crash    = "destroy"
CFG
 xl create "$CFG" >/dev/null 2>&1 || { say "$VM xl create failed"; continue; }
 say "$VM install started"
 prev=0; idle=0; el=0; switched=0; domid=$(xl domid $VM)
 while true; do
  sleep 60; el=$((el+60))
  gone=1; for t in 1 2 3 4 5 6; do xl list $VM >/dev/null 2>&1 && { gone=0; break; }; sleep 5; done
  [ $gone = 1 ] && { say "$VM domain gone at ${el}s"; break; }
  nd=$(xl domid $VM); if [ "$nd" != "$domid" ] && [ $switched = 0 ]; then
   say "$VM rebooted at ${el}s (domid $domid -> $nd): switching to disk-only boot"
   xl destroy $VM 2>/dev/null; sleep 3; sed -i 's/^boot = "dc"/boot = "c"/' "$CFG"
   xl create "$CFG" >/dev/null 2>&1 || { say "$VM xl create (disk only) failed"; break; }
   switched=1; domid=$(xl domid $VM); prev=0; idle=0; continue
  fi
  cur=$(xl list $VM | awk 'NR==2{print $6}'); ci=${cur%.*}; d=$((ci-prev)); prev=$ci
  if [ $((el % 300)) -eq 0 ]; then say "$VM t=${el}s cpu=${cur}s delta=${d}s img=$(du -m "$IMG" | cut -f1)MB"; xl qemu-monitor-command $VM "screendump $W/$VM-progress.ppm" >/dev/null 2>&1; fi
  if [ $el -ge 900 ] && [ $switched = 1 ] && [ $d -le 6 ]; then idle=$((idle+1)); else idle=0; fi
  [ $el -ge 1200 ] && [ $(du -m "$IMG" | cut -f1) -lt 2000 ] && { say "$VM STUCK (img only $(du -m "$IMG" | cut -f1)MB after ${el}s)"; break; }
  [ $idle -ge 4 ] && { say "$VM idle after ${el}s (img $(du -m "$IMG" | cut -f1)MB)"; break; }
  [ $el -ge 4800 ] && { say "$VM TIMEOUT 80 min"; break; }
 done
 xl qemu-monitor-command $VM "screendump $W/$VM-final.ppm" >/dev/null 2>&1
 xl destroy $VM 2>/dev/null; sleep 3
 qemu-img snapshot -c after-install-cold "$IMG" && say "$VM snapshot after-install-cold created" || say "$VM SNAPSHOT FAILED"
 # run cfg without the cdroms
 sed -E '/devtype=cdrom/d; s/^boot = "dc"/boot = "c"/' "$CFG" > cfg/$VM.cfg; qemu-img snapshot -a after-install-cold "$IMG"
 xl create cfg/$VM.cfg >/dev/null 2>&1; sleep 90; xl qemu-monitor-command $VM "screendump $W/$VM-boot90.ppm" >/dev/null 2>&1
 sleep 60; xl qemu-monitor-command $VM "screendump $W/$VM-boot150.ppm" >/dev/null 2>&1
 xl destroy $VM 2>/dev/null; sleep 3; qemu-img snapshot -a after-install-cold "$IMG"
 say "$VM BOOT screenshots taken"
done
say "ALLDONE"
