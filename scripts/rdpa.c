#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <libvmi/libvmi.h>
/* raw physical read, no OS init: argv: domain pa len */
int main(int c,char**v){ vmi_instance_t vmi; if(c<4)return 1;
 if(VMI_FAILURE==vmi_init(&vmi,VMI_XEN,v[1],VMI_INIT_DOMAINNAME,NULL,NULL)){puts("RAWINITFAIL");return 2;}
 addr_t pa=strtoull(v[2],0,16); size_t len=strtoul(v[3],0,0); unsigned char *b=calloc(1,len); size_t got=0;
 vmi_read_pa(vmi,pa,len,b,&got); printf("PA %#"PRIx64" (%zu bytes):",pa,got);
 for(size_t i=0;i<got;i++){ if(i%16==0)printf("\n  %04zx:",i); printf(" %02x",b[i]); } puts(""); vmi_destroy(vmi); return 0; }
