#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <libvmi/libvmi.h>
static uint64_t rol(uint64_t v,unsigned r){r&=63;return r?(v<<r)|(v>>(64-r)):v;}
static uint64_t ror(uint64_t v,unsigned r){r&=63;return r?(v>>r)|(v<<(64-r)):v;}
/* candidate transform: p = bswap(ROL(e ^ kwn, kwn&0xff) ^ addr) ^ kwa */
static uint64_t dec(uint64_t e,uint64_t addr,uint64_t kwn,uint64_t kwa){
  return __builtin_bswap64(rol(e^kwn,kwn&0xff)^addr)^kwa; }
static uint64_t dec_ror(uint64_t e,uint64_t addr,uint64_t kwn,uint64_t kwa){
  return __builtin_bswap64(ror(e^kwn,kwn&0xff)^addr)^kwa; }
int main(int c,char**v){
 vmi_instance_t vmi;
 if(VMI_FAILURE==vmi_init_complete(&vmi,v[1],VMI_INIT_DOMAINNAME,NULL,VMI_CONFIG_JSON_PATH,v[2],NULL)){puts("INITFAIL");return 2;}
 vmi_pause_vm(vmi);
 addr_t kb=0,blk=0,pkwn=0,pkwa=0,pen=0; 
 vmi_get_offset(vmi,"win_ntoskrnl_va",&kb);
 vmi_translate_ksym2v(vmi,"KdDebuggerDataBlock",&blk);
 vmi_translate_ksym2v(vmi,"KiWaitNever",&pkwn);
 vmi_translate_ksym2v(vmi,"KiWaitAlways",&pkwa);
 vmi_translate_ksym2v(vmi,"KdpDataBlockEncoded",&pen);
 uint64_t kwn=0,kwa=0; uint8_t enc=0;
 ACCESS_CONTEXT(ctx,.translate_mechanism=VMI_TM_PROCESS_PID,.pid=0);
 ctx.addr=pkwn; vmi_read_64(vmi,&ctx,&kwn); ctx.addr=pkwa; vmi_read_64(vmi,&ctx,&kwa); ctx.addr=pen; vmi_read_8(vmi,&ctx,&enc);
 printf("kernbase=%#lx blk=%#lx KiWaitNever=%#lx KiWaitAlways=%#lx encoded=%u\n",kb,blk,kwn,kwa,enc);
 uint64_t e[0x60]; size_t got=0; ctx.addr=blk;
 if(VMI_FAILURE==vmi_read(vmi,&ctx,sizeof e,e,&got)){puts("READFAIL");return 3;}
 int n=sizeof e/8;
 for(int variant=0;variant<2;variant++){
   uint64_t p[0x60]; for(int i=0;i<n;i++) p[i]=(variant?dec_ror:dec)(e[i],blk+i*8,kwn,kwa);
   printf("variant %s: tag=%.4s size=%u kernbase=%#lx(%s)\n",variant?"ROR":"ROL",(char*)&p[2],(uint32_t)(p[2]>>32),p[3],p[3]==kb?"MATCH":"no");
 }

 { unsigned r=kwn&63; for(int i=2;i<=3;i++){ uint64_t pk=(i==3)?kb:0; if(i==3){ uint64_t T=__builtin_bswap64(pk^kwa)^rol(e[i]^kwn,r);
   printf("idx%d: used_addr=%#lx  blk+8i=%#lx  xor=%#lx\n",i,T,blk+i*8,T^(blk+i*8)); } }
   printf("e0..3: %#lx %#lx %#lx %#lx\n",e[0],e[1],e[2],e[3]); }
 /* symbol-less, constant-term model: p = bswap(ROL(e,r)) ^ C */
 {
  const char *srcs=NULL; (void)srcs;
  addr_t plm=0; vmi_translate_ksym2v(vmi,"PsLoadedModuleList",&plm);
  for(int r=0;r<64;r++){
   uint64_t C=kb^__builtin_bswap64(rol(e[3],r));
   uint64_t p[0x60]; for(int k=0;k<n;k++) p[k]=__builtin_bswap64(rol(e[k],r))^C;
   uint32_t size=p[2]>>32;
   if((uint32_t)p[2]==0x4742444b && size>=0x200 && size<=0x1000){
     printf("symless OK: r=%d C=%#lx size=%#x List=%#lx/%#lx\n",r,C,size,p[0],p[1]);
     printf("  PsLoadedModuleList: decoded@+0x48=%#lx json=%#lx %s\n",p[9],plm,p[9]==plm?"MATCH":"no");
     printf("  Break@+0x20=%#lx Saved@+0x28=%#lx  [+0x30]=%#lx [+0x38]=%#lx [+0x40]=%#lx [+0x50]=%#lx\n",p[4],p[5],p[6],p[7],p[8],p[10]);
   }
  }
  printf("expected r=%u\n",(unsigned)(kwn&63));
 }
 vmi_resume_vm(vmi); vmi_destroy(vmi); return 0; }
