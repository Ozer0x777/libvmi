# Follow-up evidence (2026-10-11): version from the PE header, vCPU sampling, Windows Server 2008 to 2025

For the two commits added to the PR after the first review comment:
- `windows: sample the vCPUs before giving up on the KPCR search`
- `windows: version from the kernel PE header on the KDBG path`

Same setup as the top-level README (Xen 4.21.0, one VM at a time, clean snapshot before every boot, attach 150 s after `xl create`,
`master` = 6898847 built as `master-now`, this branch = `CR3-dbg`; final head listed in `ci/head-commits.txt`).

## summaries/
- `final-win10-x86-14builds-STATUS.txt`, `final-win10-win11-x64-20guests-STATUS.txt`: the runs of the PR description repeated on the final head (JSON + no profile, `winver=9` = `VMI_OS_WINDOWS_10` everywhere, no "Unsupported Windows version" line).
- `final-win7-8-STATUS.txt`: Windows 7/8/8.1 x86 + x64, `master` vs branch. On this boot `master` resolves no symbol on Windows 8.1 x86 (`procs=0`, same signature as Windows 8 x86 / Windows 10 1507 x86: non-contiguous kernel image this time); the branch attaches on the same boot.
- `final-winserver-2008-2025-STATUS.txt`: Server 2008 SP2, 2008 R2, 2012, 2012 R2, 2016, 2019, 2022, 2025, `master` vs branch. `master` fails on Server 2012 (both vCPUs in user mode, see below) and reports "Unsupported Windows version" on 2016 to 2025; the branch attaches 8/8 and reports the versions.
- `winserver-first-matrix-before-sampling-STATUS.txt`: the first Server run, with the branch before the sampling commit: Server 2012 fails with both libraries.
- `server2012-forced-user-mode-samples-STATUS.txt`: throw-away build (`scripts/force-build.sh`, NOT in the PR) where the first `KDBG_FORCE_USER_SAMPLES` samples are treated as "all vCPUs in user mode": 50 = the old single-sample behaviour, INITFAIL after a full physical scan; 5 = attach at the fifth sample.
- `server2012-3boots-natural-STATUS.txt`: 3 fresh boots, vCPU RIPs at attach time (`scripts/cr3cmp.c`), both builds.
- `winver-check-9guests-STATUS.txt`: first check of the version commit: block size, kernel PE version and the version reported with and without a profile.
- `winserver-install-STATUS.txt`, `winserver-profiles.log`: the unattended installs (2012 R2 needed three attempts: a real `CryptoSysPrep_Specialize` failure with one answer file, then an interrupted setup; Server 2008 SP2 stops at an OOBE error but its kernel is up, which is enough for these tests) and the PDBs used.

## excerpts/ (debug logs with the page-read noise removed)
- `server2012-FAIL-all-vcpus-user-mode-before-sampling.txt`: `find_kdbg_address_faster` goes straight to `find_ntoskrnl_physical_scan` (no vCPU in kernel mode), then `find_kdbg_address_fast` and `find_kdbg_address` read all of memory: "All KdDebuggerDataBlock search methods failed".
- `server2012-forced50-FAIL-like-before.txt` / `server2012-forced5-OK-sample5.txt`: the forced test, same boot.
- `server2012-final-OK.txt`, `server2025-final-OK.txt`, `server2008-plain-block-OK.txt`: final branch attaches (encoded block on 2012 and 2025, plain on 2008).
- `win10-1507-x64-version-from-pe-header.txt`, `win11-24h2-version-from-pe-header-0x3a0.txt`, `win81-x64-version-from-pe-header-6.3.txt`: the new `KdDebuggerDataBlock size 0x..., kernel PE version X.Y` line and the version returned.
- `win81-x86-master-no-symbols-this-boot.txt` / `win81-x86-branch-OK-same-boot.txt`.

## ci/
`ci-summary-final-head.txt` (10 jobs on the final head, all green), `cognitive-complexity-final-head.txt` (3389 vs 3440 on master), `head-commits.txt`, and the job scripts.

## scripts/
The matrix loops with the 150 s wait (`x86test150.sh`, `x64test150.sh`, `w78test.sh`, `wsrvtest.sh`), `final-chain.sh` (the whole final run + CI), `winvercheck.sh`, the Server 2012 experiments (`exp2012.sh`, `exp2012b.sh`, `force-build.sh`, `cr3cmp.c`), the Server installs (`inst-srv.sh`, `inst-srv2.sh`, `gen-ausrv*.py`), the profiles and the media downloads.
