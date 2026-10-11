#include <stdio.h>
#include <inttypes.h>
#include <libvmi/libvmi.h>
/* attach with a JSON profile: argv: domain profile.json */
int main(int c,char**v){ vmi_instance_t vmi; if(c<3)return 1;
 if(VMI_FAILURE==vmi_init_complete(&vmi,v[1],VMI_INIT_DOMAINNAME,NULL,VMI_CONFIG_JSON_PATH,v[2],NULL)){puts("JSONINITFAIL");return 2;}
 addr_t h=0; vmi_translate_ksym2v(vmi,"PsActiveProcessHead",&h);
 printf("JSON INIT OK winver=%d pm=%d addrwidth=%d PsActiveProcessHead=%#"PRIx64"\n",vmi_get_winver(vmi),vmi_get_page_mode(vmi,0),vmi_get_address_width(vmi),h);
 vmi_destroy(vmi); return 0;}
