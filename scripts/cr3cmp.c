#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <glib.h>
#include <libvmi/libvmi.h>
/* argv: domain va tasks pid pname pdbase -- translate va with every vCPU CR3 (raw), then with the System DTB (no-JSON init) */
static void show(vmi_instance_t vmi, const char *tag, addr_t cr3, addr_t va){
 addr_t pa=0; uint64_t q=0; status_t s=vmi_pagetable_lookup(vmi,cr3,va,&pa);
 if(s==VMI_SUCCESS) vmi_read_64_pa(vmi,pa+0x28,&q);
 printf("%s cr3=%#"PRIx64" va->pa=%s %#"PRIx64" qword@+0x28=%#"PRIx64"\n",tag,(uint64_t)cr3,s==VMI_SUCCESS?"ok":"FAIL",pa,q); }
int main(int c,char**v){ if(c<7)return 1; vmi_instance_t vmi; addr_t va=strtoull(v[2],0,16);
 if(VMI_FAILURE==vmi_init(&vmi,VMI_XEN,v[1],VMI_INIT_DOMAINNAME,NULL,NULL)){puts("RAWINITFAIL");return 2;}
 if(VMI_PM_UNKNOWN==vmi_init_paging(vmi,0)){puts("PAGINGFAIL");return 2;}
 unsigned n=vmi_get_num_vcpus(vmi);
 for(unsigned i=0;i<n;i++){ reg_t cr3=0,rip=0; vmi_get_vcpureg(vmi,&cr3,CR3,i); vmi_get_vcpureg(vmi,&rip,RIP,i);
   char tag[32]; snprintf(tag,sizeof tag,"vcpu%u rip=%#"PRIx64,i,(uint64_t)rip); show(vmi,tag,cr3,va); }
 vmi_destroy(vmi);
 uint64_t tasks=strtoull(v[3],0,16),pid=strtoull(v[4],0,16),pname=strtoull(v[5],0,16),pdb=strtoull(v[6],0,16);
 GHashTable *cfg=g_hash_table_new(g_str_hash,g_str_equal);
 g_hash_table_insert(cfg,"ostype","Windows"); g_hash_table_insert(cfg,"win_tasks",&tasks); g_hash_table_insert(cfg,"win_pdbase",&pdb);
 g_hash_table_insert(cfg,"win_pid",&pid); g_hash_table_insert(cfg,"win_pname",&pname);
 if(VMI_FAILURE==vmi_init_complete(&vmi,v[1],VMI_INIT_DOMAINNAME,NULL,VMI_CONFIG_GHASHTABLE,cfg,NULL)){puts("INITFAIL");return 3;}
 addr_t dtb=0; vmi_pid_to_dtb(vmi,4,&dtb); show(vmi,"System",dtb,va);
 addr_t head=0; vmi_translate_ksym2v(vmi,"PsInitialSystemProcess",&head); addr_t sp=0; vmi_read_addr_va(vmi,head,0,&sp);
 printf("PsInitialSystemProcess via kdbg path: %#"PRIx64" -> System EPROCESS %#"PRIx64"\n",head,sp);
 vmi_destroy(vmi); return 0; }
