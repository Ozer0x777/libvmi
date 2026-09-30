/* Samples vCPU0 state every 50 ms from right after xl create and reports boot
 * phase transitions: CTX (context readable), PG (CR0.PG), IDT (IDTR base != 0),
 * LSTAR (kernel syscall entry set), SYS (PsInitialSystemProcess non-NULL).
 * With --on PHASE --offset ms it exits (printing TRIGGER) at that instant. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <inttypes.h>
#include <libvmi/libvmi.h>
static double now(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec + t.tv_nsec/1e9; }
int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s domain rva_KiSystemCall64Shadow rva_PsInitialSystemProcess [--on CTX|PG|IDT|LSTAR|SYS] [--offset ms] [--max s]\n", argv[0]); return 2; }
    const char *dom = argv[1];
    uint64_t rva_lstar = strtoull(argv[2],0,0), rva_sys = strtoull(argv[3],0,0);
    const char *on = NULL; int offset_ms = 0; int max_s = 120;
    for (int i=4;i<argc;i++){ if(!strcmp(argv[i],"--on")) on=argv[++i]; else if(!strcmp(argv[i],"--offset")) offset_ms=atoi(argv[++i]); else if(!strcmp(argv[i],"--max")) max_s=atoi(argv[++i]); }
    double t0 = now();
    vmi_instance_t vmi = NULL; int tries=0;
    while (VMI_FAILURE == vmi_init(&vmi, VMI_XEN, (void*)dom, VMI_INIT_DOMAINNAME, NULL, NULL)) { if(++tries>100){puts("INITFAIL");return 2;} usleep(100000); }
    printf("t=%.2f vmi_init ok (tries=%d)\n", now()-t0, tries); fflush(stdout);
    double tctx=-1,tpg=-1,tidt=-1,tlstar=-1,tsys=-1; int pm_done=0;
    int p_ctx=-1,p_pg=-1,p_idt=-1,p_ls=-1,p_sys=-1,p_lma=-1;
    double trigger_at=-1;
    while (now()-t0 < max_s) {
        reg_t cr0=0,cr3=0,rip=0,lstar=0,idtr=0,efer=0;
        int ctx = (VMI_SUCCESS==vmi_get_vcpureg(vmi,&cr0,CR0,0));
        int pg=0, idt=0, ls=0, sys=0, lma=0; uint64_t kb=0, sysv=0;
        if (ctx) {
            vmi_get_vcpureg(vmi,&cr3,CR3,0); vmi_get_vcpureg(vmi,&rip,RIP,0);
            vmi_get_vcpureg(vmi,&lstar,MSR_LSTAR,0); vmi_get_vcpureg(vmi,&idtr,IDTR_BASE,0); vmi_get_vcpureg(vmi,&efer,MSR_EFER,0);
            pg = !!(cr0 & (1u<<31)); lma = !!(efer & (1u<<10));
            idt = (idtr != 0);
            ls = ((lstar >> 63) == 1);
            if (pg && ls) {
                if (!pm_done) { vmi_init_paging(vmi,0); pm_done=1; }
                kb = lstar - rva_lstar;
                addr_t pa=0;
                if ((kb & 0xfff)==0 && VMI_SUCCESS==vmi_pagetable_lookup(vmi, cr3, kb+rva_sys, &pa) && VMI_SUCCESS==vmi_read_64_pa(vmi,pa,&sysv) && (sysv>>63)==1) sys=1;
            }
        }
        double t=now()-t0;
        if (ctx!=p_ctx||pg!=p_pg||idt!=p_idt||ls!=p_ls||sys!=p_sys||lma!=p_lma) {
            printf("t=%.2f ctx=%d PG=%d LMA=%d IDT=%d LSTAR=%d SYS=%d cr0=%#lx cr3=%#lx rip=%#lx lstar=%#lx idtr=%#lx kb=%#lx sysproc=%#lx\n",
                   t,ctx,pg,lma,idt,ls,sys,(unsigned long)cr0,(unsigned long)cr3,(unsigned long)rip,(unsigned long)lstar,(unsigned long)idtr,(unsigned long)kb,(unsigned long)sysv);
            fflush(stdout);
            if (ctx&&tctx<0) tctx=t; if(pg&&tpg<0) tpg=t; if(idt&&tidt<0) tidt=t; if(ls&&tlstar<0) tlstar=t; if(sys&&tsys<0) tsys=t;
            p_ctx=ctx;p_pg=pg;p_idt=idt;p_ls=ls;p_sys=sys;p_lma=lma;
        }
        if (on && trigger_at<0) {
            double tt=-1;
            if(!strcmp(on,"CTX")) tt=tctx; else if(!strcmp(on,"PG")) tt=tpg; else if(!strcmp(on,"IDT")) tt=tidt; else if(!strcmp(on,"LSTAR")) tt=tlstar; else if(!strcmp(on,"SYS")) tt=tsys;
            if (tt>=0) trigger_at = tt + offset_ms/1000.0;
        }
        if (trigger_at>=0 && now()-t0 >= trigger_at) { printf("TRIGGER %s+%dms at t=%.2f\n",on,offset_ms,now()-t0); fflush(stdout); vmi_destroy(vmi); return 0; }
        if (!on && tsys>=0 && t > tsys+5) break;
        usleep(50000);
    }
    printf("SUMMARY T_CTX=%.2f T_PG=%.2f T_IDT=%.2f T_LSTAR=%.2f T_SYS=%.2f\n",tctx,tpg,tidt,tlstar,tsys); fflush(stdout);
    vmi_destroy(vmi);
    return on ? 3 : 0;
}
