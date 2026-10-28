# Stage03J central resource guard — ready for independent review

Status: READY_FOR_INDEPENDENT_REVIEW. No benign helper has been started by this recovery. NORMAL_EXIT remains NOT_RUN_AWAITING_INDEPENDENT_REVIEW. Historical Stage03J remains PARTIAL_WITH_BLOCKERS, 137 PASS / 1 FAIL; G4/G5 remain closed.

## Authorization and boundary

The human approved correction and controlled process creation with backup and canonical-state preservation. The coordinator explicitly deferred the single benign NORMAL_EXIT until independent review of this changeset. This delivery implements correction and tests without real helper creation. It grants no Python, ComfyUI, LTX, NVIDIA, GPU workload, G4/G5, Alpha or MCP authority. No foreign process was terminated. MIRAE and Pulse were not accessed.

No AGENTS.md or .agents/skills were found in the audited project/checked ancestors. Existing project policies and contracts were retained.

## Exact existing-file changes

Only these three existing files changed from the 3,476-file prechange inventory. All new project files are inside this recovery directory.

| File | Final SHA-256 |
|---|---|
| core/Wlb.WorkerProcess.ps1 | 4cd34847f8e83a9eda12fa8371c5a55efdede17bc4d1e01445f34e19f46c9c4d |
| policy/runtime-lock.json | 50c6b9dfe0d30934399fff7241fe062444e1aa3871dd49933b781a9be0ed7cc7 |
| manifests/draft/POC0-CALIBRATION-001.json | 122d4791c387dd193527e88dc38de8577be5d96f87bcbe088ce42a18c6f77bad |

See [FINAL_CHANGESET.json](FINAL_CHANGESET.json) and [CHANGESET.diff](CHANGESET.diff).

The new native PSAPI reader supplies typed counters with checked arithmetic. Lifecycle.Start validates availability/consistency, RAM >=8 GiB and commit headroom >=10 GiB under its existing creation lock, immediately before CreateProcessW. Direct callers use this same path. The existing consumed-attempt registry prevents retry after resource refusal. The wrapper retains its earlier check and now latches unexpected/native errors while leaving created=false and lease=null when creation was refused.

runtime-lock changes exactly one existing module pin; the draft changes exactly the dependent 64-character lock hash. There are still 21 pins. Helper source, executable, permitted modes/arguments, stop implementation, concurrency/attempt limits, budgets, policies, human parameters and both G4/G5 launchers are unchanged. The module retains its original LF line endings.

## Backup and concurrent-change evidence

[BACKUP_VERIFIED.json](BACKUP_VERIFIED.json) records three raw-byte backups before canonical writes and the SHA-256 of [prechange-inventory.csv](prechange-inventory.csv). Each original backup matches the prior audit hash. The preapply inventory comparison found no concurrent content changes or new files outside recovery. All three target files were opened exclusively and their preimages checked before the first canonical write.

[final-verification-01.json](final-verification-01.json) confirms 3,473 prechange files unchanged, exactly three expected modifications, no missing files, no unexpected new files, valid backups, all 21 pins and exact dependent replacements. It found no unexpected historical-evidence differences.

The old STAGE03J_SHA256_INVENTORY.csv, decision package, test matrix and DELIVERY_INTEGRITY.json were not rewritten. The old inventory now differs at the three intentionally updated live paths; their original bytes remain in backup/. Its other 87 entries still match. It remains a historical inventory, not the current recovery inventory. run06 and every historical evidence source remain untouched.

An intermediate CRLF version was briefly applied. Its exact three files are preserved in backup-intermediate/, with APPLIED_CHANGESET.json and canonical-tests-01.json. FINAL_CHANGESET.json and canonical-tests-02.json identify the final LF version. Preliminary proposed-tests-01.json is also retained. No intermediate artifact is presented as the selected final evidence.

## Verification selected for this delivery

- [canonical-tests-02.json](canonical-tests-02.json): 21 PASS / 0 FAIL against the final module hash.
- [Test-CentralGuardNoCreate.ps1](Test-CentralGuardNoCreate.ps1): compiles the exact production C# without invoking its lifecycle; behavioral tests compile an isolated in-memory namespace with CreateProcessW replaced by a throwing counter, TerminateProcess replaced by a throw, controlled native memory readings, fixed identity hashes, and scratch preparation intercepted. Production has no test flag, injected provider or exposed bypass.
- Direct-call coverage includes exact 8/10 GiB boundaries, one byte below either boundary, provider failure/exception, conversion and multiplication overflow, inconsistent counters, page size, no retry after recovery, serialized concurrent reads/creation and same-attempt concurrency. Wrapper tests cover high outer reading followed by low native reading and correct terminal state.
- [final-verification-01.json](final-verification-01.json): 14 PASS / 0 FAIL. Includes content preservation, bindings/pins, static manifest review, execution eligibility/G4/G5 refusal and one passive invocation of the new native memory reader. No production Start or Stop was invoked.
- The native passive reading at 2026-10-15T01:42:56.6031034Z returned 10,520,313,856 bytes available RAM and 31,471,886,336 bytes commit headroom, with 4,096-byte pages. This was eligible at that instant; it authorizes no launch and must be refreshed before any later attempt.

The 21 behavioral checks and 14 verification checks are separate recovery evidence. They are not added to, or substituted for, the historical 137/1 matrix.

## Limits and review focus

Review central-check placement, typed native layout, checked byte conversions, exact threshold constants, consumed-attempt semantics and wrapper error state. The behavioral fixture intercepts creation even on positive cases; it does not prove successful Windows helper startup under the final guard. That proof is intentionally pending.

This remains point-in-time admission, not continuous monitoring, an OS cap or same-account security isolation. RAM can change after the read. Existing scratch preparation precedes the last native resource check, so a directly refused call may leave an empty attempt directory; no automatic cleanup was added. Native readings do not establish GPU attribution, provider generation freshness, complete budgets or runtime compatibility.

Legacy NVIDIA collector calls and archived executable historical source copies were preserved. They are outside this benign helper path and must not be invoked by the recovery. No full old test runner or delivery generator was executed: they can create helpers/write historical namespaces and some select run06 by name.

## Required next action

Independent review of these exact hashes and tests must complete before the coordinator releases the single NORMAL_EXIT attempt. Use a fresh supervisor process to avoid an already-loaded old Add-Type definition, recheck files/pins and fresh RAM/headroom, and create separate new evidence with no overwrite or retry. This delivery does not run or schedule that attempt.

Rollback, if later authorized: verify current hashes and backups, restore only the three original backup files together, verify the original 21 pins and draft binding, and retain every recovery artifact. No rollback or deletion was executed.
