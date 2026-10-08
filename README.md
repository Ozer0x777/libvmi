# Test evidence for libvmi PR #1127 (final code, 2026-10-08)

Evidence for https://github.com/libvmi/libvmi/pull/1127 (`windows: decode the encoded KdDebuggerDataBlock`, commit 0d6908d).
Earlier runs (stock LibVMI, first decoder revision, 14 Windows 10 builds) are on the branch `test-evidence/win10-kdbg-2026-10-06`.

Setup: Xen 4.21.0 (`ept=ad=0`), Debian 13, one VM at a time, clean snapshot restored before every boot, attach 90 s after `xl create`,
no JSON profile (the test program `nojson.c`, see the other branch, only passes the EPROCESS offsets), libvmi built with `-DVMI_DEBUG=__VMI_DEBUG_ALL`.
"json" lines compare `PsActiveProcessHead` with an attach that uses the JSON profile on the same boot (MATCH-nojson = identical).

## summaries/ (one line per attach, written by the scripts in scripts/)
- `win11-5builds-3a74d10.txt`, `win11-21h2-retries-3a74d10.txt`: Windows 11 21H2/22H2/23H2/24H2/26H1 with the previous revision (3a74d10, before the CR3 refresh). 21H2 fails on its first boot, then 3/3.
- `win11-21h2-10runs-without-refresh.txt`: 10 fresh boots of 21H2 without the refresh: 9 OK, p6 INITFAIL.
- `win11-21h2-15runs-with-refresh.txt`: 15 fresh boots with the refresh: 15/15 OK (`stale=0`: the refresh did not trigger in these).
- `forced-bad-cr3-with-and-without-refresh.txt`: throw-away builds that overwrite the init CR3 with a data page (`scripts/poison.py`, NOT part of the PR). Without the refresh: INITFAIL (~205 s), with it: OK (~38 s).
- `final-spot-25h2-win10.txt`, `final-win11-22h2-23h2-24h2-26h1.txt`: final code (identical to 0d6908d) on Windows 11 25H2/22H2/23H2/24H2/26H1 and Windows 10 1507/1607/1809/22H2: all OK, heads identical to the JSON path. On 1809 the refresh triggered by itself.
- `ci-local-final-commit.txt`: the repository workflows replayed locally on the final commit (10 jobs, complexity 3389 vs 3440 on master).

## excerpts/ (full logs are several hundred MB; these keep the start, 70 lines after the block is found, and the end; the "Reading pfn / MEMORY cache" lines are removed)
- `21h2-first-boot-FAIL-stale-cr3.txt`: the block is found (`Found encoded KdDebuggerDataBlock at PA 0x101002190`), then every translation through the init CR3 `0x3e2155002` fails: the PML4 entry at `0x3e2155f80` now reads `0x007200630069004d` (UTF-16 "Micr"), whereas the first lookup of the same attach (`PTLookup` at the start of the search) read a valid entry `0x3e0b063` from the same place. The page was freed and reused during the search.
- `21h2-p6-FAIL-stale-cr3.txt`: the same failure on another boot (the PML4 entry reads `0x3000000`, not a valid entry).
- `21h2-c1-OK-with-refresh.txt`: a normal successful attach with the final code.
- `1809-OK-refresh-triggered-naturally.txt`: Windows 10 1809, final code: `init CR3 0x55a00001 is stale, using the CR3 of vCPU 0 (0x25c00002)`, then `INIT OK`.
- `forced-bad-cr3-WITHOUT-refresh-FAIL.txt` / `forced-bad-cr3-WITH-refresh-OK.txt`: the forced test (init CR3 = 0x3000) on 21H2, same boot, without and with the refresh.

## scripts/
`all-w11.sh` (the loop used for the Windows 11 builds; the other loops are variants of it), `rep21h2c.sh` (15 runs), `poison.py` + `poison-run.sh` (forced test).
