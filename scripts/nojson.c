#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <glib.h>
#include <libvmi/libvmi.h>
int main(int c,char**v){
 /* argv: domain tasks pid pname pdbase (hex) */
 uint64_t tasks=strtoull(v[2],0,16),pid=strtoull(v[3],0,16),pname=strtoull(v[4],0,16),pdb=strtoull(v[5],0,16);
 GHashTable *cfg=g_hash_table_new(g_str_hash,g_str_equal);
 g_hash_table_insert(cfg,"ostype","Windows");
 g_hash_table_insert(cfg,"win_tasks",&tasks); g_hash_table_insert(cfg,"win_pdbase",&pdb);
 g_hash_table_insert(cfg,"win_pid",&pid); g_hash_table_insert(cfg,"win_pname",&pname);
 vmi_instance_t vmi;
 if(VMI_FAILURE==vmi_init_complete(&vmi,v[1],VMI_INIT_DOMAINNAME,NULL,VMI_CONFIG_GHASHTABLE,cfg,NULL)){puts("INITFAIL");return 2;}
 printf("INIT OK winver=%d\n",vmi_get_winver(vmi));
 vmi_pause_vm(vmi);
 addr_t head=0; if(VMI_FAILURE==vmi_translate_ksym2v(vmi,"PsActiveProcessHead",&head)){puts("no PsActiveProcessHead");return 3;}
 printf("PsActiveProcessHead=%#lx\n",head);
 addr_t cur=0; ACCESS_CONTEXT(ctx,.translate_mechanism=VMI_TM_PROCESS_PID,.pid=0,.addr=head);
 vmi_read_addr(vmi,&ctx,&cur); int n=0;
 while(cur!=head && n<500){ addr_t ep=cur-tasks; uint64_t p=0; char *nm=NULL;
   ctx.addr=ep+pid; vmi_read_64(vmi,&ctx,&p); ctx.addr=ep+pname; nm=vmi_read_str(vmi,&ctx);
   printf("  pid=%-5"PRIu64" %s\n",p,nm?nm:"?"); free(nm); n++;
   ctx.addr=cur; if(VMI_FAILURE==vmi_read_addr(vmi,&ctx,&cur))break; }
 printf("PROCS=%d\n",n); vmi_resume_vm(vmi); vmi_destroy(vmi); return 0; }
