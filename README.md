# Test evidence: Windows early-boot initialization in LibVMI (2026-09-30)

Supporting data for the LibVMI issue on `vmi_init_complete()` behaviour when attaching
before the Windows kernel is up, and for the `windows-fail-fast-paging-disabled` branch.

Host: Xeon E5-2683 v4, 32 GB, Debian 13, Xen 4.21.0 (`evidence/host-specs.txt`).
Guests: Windows 11 21H2/22H2/23H2/24H2/25H2/26H1 (16 GB, 12 vCPU), Windows 10 1809, Debian 12.

Layout:

- `evidence/v2/res/summary.txt` - state-triggered pipeline: boot-phase maps (P0), the 30 targeted
  attaches with the guest paused in each state (P2), DRAKVUF attached in winload (P2b), fixture
  saves/replays (P4), stale page_mode demo (P9), ASan (P8), Linux (P7), file mode (P5), Windows 10 (P6).
- `evidence/v2/res/post.txt`, `live-lstar.txt` - proof of the false success at the LSTAR instant
  (12 runs) with the SYS+500 ms controls, Linux with the guest paused, fixture retries.
- `evidence/v2/res/p3v2.txt` - retry-loop callers (upstream vs fixed, 1 s / 5 s cadence, same
  instance vs re-init, GHashTable vs JSON path).
- `evidence/v2/res/map-*.txt` - raw sampler output per build (every vCPU0 state transition).
- `evidence/v2/res/*.log` - filtered LibVMI debug log of every attach (which init path ran).
- `evidence/final/T1.txt`, `T2.txt`, `T3.txt` - fixed-delay sweep (60 attaches), DRAKVUF early
  attach + re-attach, non-regression on booted guests, all on master + the fix.
- `evidence/eb-summary.txt`, `ebF-summary.txt`, `ebD-summary.txt` - the same 60-attach sweep on
  upstream master, on master + fix (first run), on master + fix (final code).
- `evidence/v2/*.c` - the probes: `bootstate2.c` (samples vCPU0 and pauses the domain in the target
  boot state), `initprobe2.c` (init + usability check), `retryprobe2.c` (retrying callers),
  `fileprobe.c` (file mode).
- `evidence/v2/*.sh` - the scripts that produced the summaries.

Full raw debug logs (several GB compressed) are kept on the test host and available on request.
