/* Emulates a caller that retries OS init on ONE vmi instance until it succeeds,
 * the way a fixed DRAKVUF could. Each attempt: (refresh paging unless
 * --no-refresh) + flush caches + vmi_init_os; --pause pauses the domain around
 * each attempt like DRAKVUF does. Reports time-to-first-success. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <glib.h>
#include <libvmi/libvmi.h>
static double now(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec + t.tv_nsec/1e9; }
int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s domain profile.json [--pause] [--no-refresh] [--max s] [--interval ms]\n", argv[0]); return 2; }
    const char *dom = argv[1]; char *prof = argv[2];
    int pause=0, refresh=1, max_s=400, interval_ms=1000;
    for (int i=3;i<argc;i++){ if(!strcmp(argv[i],"--pause")) pause=1; else if(!strcmp(argv[i],"--no-refresh")) refresh=0; else if(!strcmp(argv[i],"--max")) max_s=atoi(argv[++i]); else if(!strcmp(argv[i],"--interval")) interval_ms=atoi(argv[++i]); }
    double t0 = now();
    vmi_instance_t vmi = NULL; int tries=0;
    while (VMI_FAILURE == vmi_init(&vmi, VMI_XEN, (void*)dom, VMI_INIT_DOMAINNAME, NULL, NULL)) { if(++tries>100){puts("INITFAIL");return 2;} usleep(100000); }
    printf("t=%.2f vmi_init ok\n", now()-t0); fflush(stdout);
    GHashTable *cfg = g_hash_table_new(g_str_hash, g_str_equal);
    g_hash_table_insert(cfg, "volatility_ist", prof);
    int attempt=0; double longest=0;
    while (now()-t0 < max_s) {
        attempt++;
        double a=now();
        if (pause) vmi_pause_vm(vmi);
        page_mode_t pm = VMI_PM_UNKNOWN;
        if (refresh) pm = vmi_init_paging(vmi, 0);
        vmi_v2pcache_flush(vmi, ~0ull); vmi_pidcache_flush(vmi); vmi_symcache_flush(vmi); vmi_rvacache_flush(vmi);
        vmi_init_error_t err = 0;
        os_t os = vmi_init_os(vmi, VMI_CONFIG_GHASHTABLE, cfg, &err);
        if (pause) vmi_resume_vm(vmi);
        double d=now()-a; if (d>longest) longest=d;
        printf("attempt=%d t_start=%.2f pm=%d os=%d err=%d took=%.2fs\n", attempt, a-t0, pm, os, err, d); fflush(stdout);
        if (os == VMI_OS_WINDOWS) {
            printf("RESULT success attempts=%d t_success=%.2fs longest_attempt=%.2fs\n", attempt, now()-t0, longest); fflush(stdout);
            vmi_destroy(vmi); return 0;
        }
        usleep(interval_ms*1000);
    }
    printf("RESULT giveup attempts=%d t=%.2fs longest_attempt=%.2fs\n", attempt, now()-t0, longest);
    vmi_destroy(vmi); return 1;
}
