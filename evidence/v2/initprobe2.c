/* Like initprobe, but after a "successful" init it checks whether the result is
 * actually usable: reads win_sysproc, tries a kernel symbol read through the
 * kpgd LibVMI selected, and lists the first processes. */
#include <stdio.h>
#include <time.h>
#include <inttypes.h>
#include <libvmi/libvmi.h>
int main(int c,char**v){ vmi_instance_t vmi; struct timespec a,b; clock_gettime(CLOCK_MONOTONIC,&a);
 status_t r=vmi_init_complete(&vmi,v[1],VMI_INIT_DOMAINNAME,NULL,VMI_CONFIG_JSON_PATH,v[2],NULL);
 clock_gettime(CLOCK_MONOTONIC,&b);
 printf("RESULT rc=%d init_ms=%ld\n",r,(b.tv_sec-a.tv_sec)*1000+(b.tv_nsec-a.tv_nsec)/1000000);
 if(r!=VMI_SUCCESS) return 1;
 addr_t sysproc=0, head=0, dtb0=0, dtb4=0; 
 status_t s1=vmi_get_offset(vmi,"win_sysproc",&sysproc);
 status_t s2=vmi_read_addr_ksym(vmi,"PsActiveProcessHead",&head);
 status_t s3=vmi_pid_to_dtb(vmi,0,&dtb0);
 status_t s4=vmi_pid_to_dtb(vmi,4,&dtb4);
 printf("CHECK win_sysproc rc=%d val=%#lx | ksym PsActiveProcessHead rc=%d val=%#lx | pid0_dtb rc=%d val=%#lx | pid4_dtb rc=%d val=%#lx\n",s1,(unsigned long)sysproc,s2,(unsigned long)head,s3,(unsigned long)dtb0,s4,(unsigned long)dtb4);
 int n=0; if(s2==VMI_SUCCESS){ addr_t tasks=0,pid_off=0; vmi_get_offset(vmi,"win_tasks",&tasks); vmi_get_offset(vmi,"win_pid",&pid_off);
   addr_t cur=head,next=0; while(n<5 && VMI_SUCCESS==vmi_read_addr_va(vmi,cur,0,&next) && next && next!=head){ vmi_pid_t pid=0; vmi_read_32_va(vmi,next-tasks+pid_off,0,(uint32_t*)&pid); printf("PROC pid=%d\n",pid); cur=next; n++; } }
 printf("USABLE=%s\n",(s2==VMI_SUCCESS&&n>0)?"yes":"NO");
 vmi_destroy(vmi); return 0;}
