/* Boot-phase sampler v2. Samples vCPU0 every 50 ms from right after xl create.
 * Reports transitions (CTX, PG, IDT, LSTAR, SYS). With --on TARGET it pauses
 * the domain the moment the target state is observed, re-reads the state under
 * pause to verify it, prints TRIGGER and exits leaving the domain PAUSED.
 * Targets: CTX (+offset), PG0W (winload real-mode thunk: PG=0 after first PG=1),
 * PG1 (winload long mode: PG=1 and LSTAR unset), LSTAR (+offset; kernel up),
 * SYS (+offset; PsInitialSystemProcess set). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <inttypes.h>
#include <libvmi/libvmi.h>
static double now(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec + t.tv_nsec/1e9; }
struct st { int ctx,pg,lma,idt,ls,sys; reg_t cr0,cr3,rip,lstar,idtr; uint64_t kb,sysv; };
static uint64_t RVA_LS, RVA_SYS; static int pm_done=0;
static void sample(vmi_instance_t vmi, struct st *s) {
    memset(s,0,sizeof *s);
    s->ctx = (VMI_SUCCESS==vmi_get_vcpureg(vmi,&s->cr0,CR0,0));
    if (!s->ctx) return;
    reg_t efer=0;
    vmi_get_vcpureg(vmi,&s->cr3,CR3,0); vmi_get_vcpureg(vmi,&s->rip,RIP,0);
    vmi_get_vcpureg(vmi,&s->lstar,MSR_LSTAR,0); vmi_get_vcpureg(vmi,&s->idtr,IDTR_BASE,0); vmi_get_vcpureg(vmi,&efer,MSR_EFER,0);
    s->pg = !!(s->cr0 & (1u<<31)); s->lma = !!(efer & (1u<<10)); s->idt = (s->idtr != 0); s->ls = ((s->lstar >> 63) == 1);
    if (s->pg && s->ls) {
        if (!pm_done) { vmi_init_paging(vmi,0); pm_done=1; }
        s->kb = s->lstar - RVA_LS; addr_t pa=0;
        if ((s->kb & 0xfff)==0 && VMI_SUCCESS==vmi_pagetable_lookup(vmi, s->cr3, s->kb+RVA_SYS, &pa) && VMI_SUCCESS==vmi_read_64_pa(vmi,pa,&s->sysv) && (s->sysv>>63)==1) s->sys=1;
    }
}
static void show(const char *tag, double t, struct st *s) {
    printf("%s t=%.2f ctx=%d PG=%d LMA=%d IDT=%d LSTAR=%d SYS=%d cr0=%#lx cr3=%#lx rip=%#lx lstar=%#lx idtr=%#lx kb=%#lx sysproc=%#lx\n", tag, t, s->ctx,s->pg,s->lma,s->idt,s->ls,s->sys,(unsigned long)s->cr0,(unsigned long)s->cr3,(unsigned long)s->rip,(unsigned long)s->lstar,(unsigned long)s->idtr,(unsigned long)s->kb,(unsigned long)s->sysv);
    fflush(stdout);
}
int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s domain rva_KiSystemCall64Shadow rva_PsInitialSystemProcess [--on CTX|PG0W|PG1|LSTAR|SYS] [--offset ms] [--max s]\n", argv[0]); return 2; }
    const char *dom = argv[1]; RVA_LS = strtoull(argv[2],0,0); RVA_SYS = strtoull(argv[3],0,0);
    const char *on = NULL; int offset_ms = 0; int max_s = 120;
    for (int i=4;i<argc;i++){ if(!strcmp(argv[i],"--on")) on=argv[++i]; else if(!strcmp(argv[i],"--offset")) offset_ms=atoi(argv[++i]); else if(!strcmp(argv[i],"--max")) max_s=atoi(argv[++i]); }
    double t0 = now(); vmi_instance_t vmi = NULL; int tries=0;
    while (VMI_FAILURE == vmi_init(&vmi, VMI_XEN, (void*)dom, VMI_INIT_DOMAINNAME, NULL, NULL)) { if(++tries>100){puts("INITFAIL");return 2;} usleep(100000); }
    printf("t=%.2f vmi_init ok (tries=%d)\n", now()-t0, tries); fflush(stdout);
    double tctx=-1,tpg=-1,tidt=-1,tlstar=-1,tsys=-1; struct st p; memset(&p,0xff,sizeof p); int retries=0; double off=offset_ms/1000.0;
    while (now()-t0 < max_s) {
        struct st s; sample(vmi,&s); double t=now()-t0;
        if (s.ctx!=p.ctx||s.pg!=p.pg||s.idt!=p.idt||s.ls!=p.ls||s.sys!=p.sys||s.lma!=p.lma) { show("STATE",t,&s); p=s; }
        if (s.ctx&&tctx<0) tctx=t; if(s.pg&&tpg<0) tpg=t; if(s.idt&&tidt<0) tidt=t; if(s.ls&&tlstar<0) tlstar=t; if(s.sys&&tsys<0) tsys=t;
        int cond=0;
        if (on) {
            if(!strcmp(on,"CTX")) cond = (tctx>=0 && t>=tctx+off);
            else if(!strcmp(on,"PG0W")) cond = (tpg>=0 && s.ctx && !s.pg && t>=tpg+off);
            else if(!strcmp(on,"PG1")) cond = (tpg>=0 && s.pg && !s.ls && t>=tpg+off);
            else if(!strcmp(on,"LSTAR")) cond = (tlstar>=0 && t>=tlstar+off);
            else if(!strcmp(on,"SYS")) cond = (tsys>=0 && t>=tsys+off);
        }
        if (cond) {
            vmi_pause_vm(vmi); struct st s2; sample(vmi,&s2); double t2=now()-t0;
            int ok=1;
            if(!strcmp(on,"PG0W")) ok = (s2.ctx && !s2.pg);
            else if(!strcmp(on,"PG1")) ok = (s2.pg && !s2.ls);
            else if(!strcmp(on,"CTX")) ok = s2.ctx;
            show(ok?"PAUSED":"PAUSED-MISMATCH",t2,&s2);
            if (ok) { printf("TRIGGER %s+%dms at t=%.2f (T_CTX=%.2f T_PG=%.2f T_IDT=%.2f T_LSTAR=%.2f T_SYS=%.2f)\n",on,offset_ms,t2,tctx,tpg,tidt,tlstar,tsys); fflush(stdout); _exit(0); }
            vmi_resume_vm(vmi); if (++retries>200) { puts("TRIGGER-GIVEUP"); fflush(stdout); _exit(3); }
            continue;
        }
        if (!on && tsys>=0 && t > tsys+5) break;
        usleep(50000);
    }
    printf("SUMMARY T_CTX=%.2f T_PG=%.2f T_IDT=%.2f T_LSTAR=%.2f T_SYS=%.2f\n",tctx,tpg,tidt,tlstar,tsys); fflush(stdout);
    if (on) { puts("TRIGGER-TIMEOUT"); _exit(3); }
    vmi_destroy(vmi); return 0;
}
