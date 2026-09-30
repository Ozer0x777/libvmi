/* File-mode init the way DRAKVUF configures LibVMI (GHashTable with volatility_ist + kpgd), then list processes. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <glib.h>
#include <libvmi/libvmi.h>
int main(int c,char**v){ vmi_instance_t vmi=NULL; uint64_t kpgd=strtoull(v[3],0,0);
 GHashTable *cfg=g_hash_table_new(g_str_hash,g_str_equal); g_hash_table_insert(cfg,"volatility_ist",v[2]); g_hash_table_insert(cfg,"kpgd",&kpgd); uint64_t ntpa=0x100400000ULL; if(c>4) g_hash_table_insert(cfg,"win_ntoskrnl",&ntpa); uint64_t ntva=(c>5)?strtoull(v[5],0,0):0; if(c>5) g_hash_table_insert(cfg,"win_ntoskrnl_va",&ntva);
 vmi_init_error_t err=0;
 if(VMI_FAILURE==vmi_init_complete(&vmi,v[1],VMI_INIT_DOMAINNAME,NULL,VMI_CONFIG_GHASHTABLE,cfg,&err)){ printf("INITFAIL err=%d\n",err); return 1; }
 printf("INIT ok pm=%d\n", vmi_get_page_mode(vmi,0));
 addr_t head=0,tasks=0,pid_off=0,name_off=0; vmi_read_addr_ksym(vmi,"PsActiveProcessHead",&head); vmi_get_offset(vmi,"win_tasks",&tasks); vmi_get_offset(vmi,"win_pid",&pid_off); vmi_get_offset(vmi,"win_pname",&name_off);
 addr_t cur=head,next=0; int n=0; while(n<500 && VMI_SUCCESS==vmi_read_addr_va(vmi,cur,0,&next) && next && next!=head){ vmi_pid_t pid=0; char nm[16]={0}; vmi_read_32_va(vmi,next-tasks+pid_off,0,(uint32_t*)&pid); vmi_read_va(vmi,next-tasks+name_off,0,15,nm,NULL); printf("[%5d] %s\n",pid,nm); cur=next; n++; }
 printf("PROCS=%d\n",n); vmi_destroy(vmi); return 0; }
