# Test evidence: LibVMI on 32-bit guests and on Windows 7 / 8 (branch `windows-32bit-guests`, 2026-10-09 to 2026-10-11)

Evidence for the PR "windows: 32-bit guests, and the kernel base from the IDT under KVA shadowing" (commits `88d4f79` + `a8804a0` on master `6898847`).
The evidence for #1127 is on the branch `test-evidence/kdbg-final-2026-10-08`.

Setup: Xen 4.21.0 (`ept=ad=0`), Debian 13 (`host-xen.txt`, `host-specs.txt`), one VM at a time, clean snapshot of a fresh unattended install
restored before every boot (`vm-config-example-win10-21H2-x86.cfg`), LibVMI built with `-DVMI_DEBUG=__VMI_DEBUG_ALL`.
Each attach is done without a profile (`scripts/nojson2.c`: config hashtable with only the EPROCESS offsets of the build) and with the
JSON profile of the build (`scripts/jsonsym2.c`; profiles from the media kernel with volatility3 pdbconv, `scripts/x86-profiles.sh`, `w78-profiles.sh`).

Libraries compared:
- `BEFORE-fix` / `CR3-before`: the code of #1127 (0d6908d) without the two commits;
- `upstream-master-82bbee6`: master before #1127 was merged; `upstream-master-6898847` / `master-now`: master with #1127 merged;
- `WITH-fix` / `CR3-dbg`: the two commits (first on top of 0d6908d, then replayed on 6898847; identical tree).

## summaries/ (one line per attach, written by the scripts)
- `win10-x86-install-STATUS.txt`: unattended installs of the 14 Windows 10 x86 builds (`scripts/inst-x86c.sh`).
- `win10-x86-attach-BEFORE-fix-STATUS.txt`: 14 builds, JSON + no profile, before the fix: no profile 11/14 (1507/1511/1607 `procs=0`), JSON 6/14 (`JSONINITFAIL`).
- `win10-x86-attach-upstream-master-82bbee6-STATUS.txt`: master, 1507/1607/21H2: same failures (`no PsActiveProcessHead`, `conflicts with provided value`).
- `win10-x86-attach-WITH-fix-STATUS.txt`: 14 builds with the two commits: no profile 14/14, JSON 14/14.
- `win10-x86-eprocess-offsets.txt`, `win10-x86-profiles.log`: the offsets (tasks pid pname pdbase) and the PDBs used.
- `x64-regression-win10-win11-STATUS.txt`: Windows 10 x64 (14) + Windows 11 (6) with the two commits: no profile 20/20, JSON 19/20 (1709 x64 at 90 s).
- `win10-1709-x64-json-timing-*.txt`: the 1709 x64 JSON attach at 90 s: fails identically with the code before the commits (`STATUS.txt`, 3/3 each) and with master (`STATUS-stock.txt`); `STATUS-verify.txt` (both vCPU CR3 = System DTB 0x1aa000, the DTB slot reads 0); `STATUS-exp.txt` (raw reads of the EPROCESS DTB slot every 5 s from 90 s: zero until about 110 s, then `0x1aa000`, then JSON attach OK); `STATUS-late.txt` (2 more boots, attach at 150 s, OK).
- `win7-8-install-STATUS.txt`: installs of Windows 7 7600/7601 and 8 9200 / 8.1 9600, x86 + x64 (`scripts/inst-78b.sh`, `gen-au78.py`).
- `win7-8-attach-STATUS.txt`: the 8 guests, master (6898847) vs the branch, JSON + no profile, attach at 150 s.
- `win7-8-profiles.log`: PDBs used (Windows 7 x86 runs `ntkrnlpa.exe`, hence the `-ntkrnlpa` profiles).

## excerpts/ (debug logs with the "Reading pfn / MEMORY cache / PTLookup / cache" lines removed, first 400 KB)
- `win10-1507-x86-nojson-BEFORE-fix.txt` vs `...-WITH-fix.txt`: the block found by `find_kdbg_address_fast` and the wrong block VA (`0x8108f870`, below the kernel base), vs the non-contiguous path ("KdDebuggerDataBlock at RVA 0x22f820 of the kernel mapped at VA 0x8121b000") and the process list.
- `win10-21H2-x86-json-BEFORE-fix-kernel-base-conflict.txt`, `...-upstream-master-82bbee6.txt`, `...-WITH-fix.txt`: `kpcr_find3` giving `KernBase VA=0x83b13404` (KiTrap00Shadow) then "conflicts with provided value", vs the fixed base.
- `win10-21H2-x86-nojson-WITH-fix.txt`: a normal x86 attach without profile (plain block, contiguous kernel).
- `win10-*-kdbg-header-dump.txt`: raw dumps of the x86 KdDebuggerDataBlock headers (tag, size 0x360 / 0x380, KernBase, PaeEnabled).
- `win10-1709-x64-json-at-90s-FAIL-guest-still-booting.txt` vs `...-at-150s-OK.txt`.
- `win11-24h2-x64-nojson-WITH-fix.txt`: an x64 attach with the branch (decoder path unchanged).
- `win8-9200-x86-nojson-upstream-master-6898847-no-symbols.txt` vs `win8-9200-x86-nojson-WITH-fix.txt`: Windows 8 x86, non-contiguous kernel, master vs branch.
- `win7-7601-x64-nojson-plain-block.txt`, `win7-7601-x86-nojson-plain-block.txt`: the plain (non-encoded) block on Windows 7.
- `win81-9600-x64-nojson-encoded-block.txt`, `win8-9200-x64-nojson-upstream-master-6898847-encoded.txt`: the block is already encoded on 64-bit Windows 8 / 8.1.

## screenshots/
`win10-1709-x64-boot-t90s-still-boot-logo.png` / `...-t110s.png` (why the 1709 x64 JSON attach fails at 90 s), `win7-8-desktops-150s-after-create.png` (the 8 Windows 7/8 guests 150 s after `xl create`), `win10-1507-x86-desktop.png`.

## ci/
`ci-summary-fe57a67.txt` (10 jobs on the branch head, `cognitive-complexity-fe57a67.txt`: 3389 vs 3440 on master), `ci-summary-dd9e531-same-code-on-0d6908d.txt` (same commits on top of 0d6908d, before the merge of #1127), and the job scripts (`run-all.sh`, `job-*.sh`) that replay the repository workflows in containers.

## scripts/
Test programs (`nojson2.c`, `jsonsym2.c`, `rdpa.c` raw physical read, `cr3cmp.c` translation through each vCPU CR3), the matrix loops (`x86test.sh`, `x64test.sh`, `w78test.sh`, `stocktest.sh`), the 1709 timing experiments (`exp1709.sh`, `late1709.sh`, `shot1709.sh`), the installs (`inst-x86c.sh`, `inst-78b.sh`, `gen-au78.py`), the profiles (`x86-profiles.sh`, `w78-profiles.sh`), the media downloads (`dl-*.sh`, archive.org, sha1 checked) and `deploy32.sh` (rebuild + astyle check + matrix).
