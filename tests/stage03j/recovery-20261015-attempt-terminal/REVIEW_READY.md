# Stage03J attempt identity and shared refusal — second review package

Status: READY_FOR_INDEPENDENT_REVIEW. This is an incremental correction after the independent reviewer identified two P2 issues in the first recovery. NORMAL_EXIT remains NOT_RUN_AWAITING_INDEPENDENT_REVIEW; zero real helpers were created. Historical Stage03J remains PARTIAL_WITH_BLOCKERS, 137 PASS / 1 FAIL, with G4/G5 closed.

## Findings verified before changing canonical files

The preceding module used HashSet<string> with the default case-sensitive comparer even though Guid.TryParseExact accepts case variants. A consumed lowercase GUID could reach the creation interceptor again through its uppercase representation. The wrapper's early resource refusal or provider error set only the local terminal flag; a later direct native call with the same ID could reach the interceptor.

The same test source reproduced both findings without real creation: [terminal-before-tests.json](terminal-before-tests.json), 21 PASS / 7 FAIL. The seven failures cover both case directions, simultaneous case aliases, wrapper resource refusal to direct call after resource recovery, wrapper provider error to direct, malformed wrapper reading to direct, and clearing the wrapper-local terminal flag. These results are preserved rather than replaced.

## Incremental backup and exact scope

[BACKUP_VERIFIED.json](BACKUP_VERIFIED.json) records verified raw-byte backups of the preceding reviewed module, runtime-lock and draft. [prechange-inventory.csv](prechange-inventory.csv) covers 3,502 files before this correction. The entire first recovery package was validated before backup. Preapply checks found no concurrent content changes; all three target preimages were verified under exclusive file handles before any canonical write.

Only these three existing files changed:

| File | Final SHA-256 |
|---|---|
| core/Wlb.WorkerProcess.ps1 | 21a16861c526d52b8ce70fc7dc534bed2898b2a58b2ae34c905bb223a105d34e |
| policy/runtime-lock.json | 83a5eb5e7468ef57cce68ddc4d42f725b0f07c64d83db1a9408be2b7b0a7c1df |
| manifests/draft/POC0-CALIBRATION-001.json | 5f1978b1a811e3ed3260d9fb00f0b4608ae3255b670929ad5c8e661eac9e267d |

See [CHANGESET.diff](CHANGESET.diff) and [FINAL_CHANGESET.json](FINAL_CHANGESET.json). The diff is relative to the first recovery's final state, not the original Stage03J source.

## Minimal implementation

The consumed-attempt set and lease map now use Guid keys. Start normalizes the textual attempt ID to Guid.ToString("D") for the lease and fixed command line; stop lookup parses the same GUID value and retains all existing nonce, creator, handle, creation-time, image/hash and lease-reference checks.

MarkAttemptRefused parses a valid D-format GUID and records it under the existing lifecycle lock in the same consumed-attempt set used by Start. The wrapper calls it before exposing its local terminal state on resource/provider/native errors. This API is monotonic: it can only consume an attempt, cannot remove a refusal or grant creation, and cannot expand the 32-attempt bound. At capacity, every Start remains denied even when a further refused ID is not added.

The existing native RAM/headroom guard and its placement immediately before CreateProcessW are unchanged. The fixed helper, executable hash, modes, arguments, stop reasons, concurrency/attempt bounds and resource thresholds remain unchanged. The lock replaces exactly one module pin; the draft replaces exactly the dependent 64-character lock hash. There remain 21 valid pins. Original module LF line endings were retained.

## Selected verification

- [terminal-final-tests.json](terminal-final-tests.json): 28 PASS / 0 FAIL on the final canonical module, including all seven formerly failing cases. [terminal-proposed-tests.json](terminal-proposed-tests.json) preserves the preapply run of the same corrected bytes.
- [Test-AttemptTerminalNoCreate.ps1](Test-AttemptTerminalNoCreate.ps1): exact production C# compilation plus isolated in-memory behavioral namespace. Native creation is replaced by a throwing interceptor, termination by a throw, memory by controlled inputs, and scratch creation by a counter. No production Start/Stop is called, and production exposes no provider override or test switch.
- [terminal-final-verification.json](terminal-final-verification.json): 16 PASS / 0 FAIL. Confirms 3,499 prechange files unchanged, only three expected modifications, no missing/foreign new files, exact bindings, 21 pins, backup identity, first-package preservation and the before/after seven-test comparison. Static execution eligibility, G4 admission and G5 without approval all remain refused.
- A passive read of the unchanged native PSAPI memory reader at 2026-10-15T01:56:10.7709682Z returned 12,423,450,624 bytes available RAM and 32,329,629,696 bytes commit headroom. Eligibility at that instant provides no startup authority.

These counts are separate from the historical 137/1 matrix. The first recovery's files, diff, backups, 21/0 and 14/0 evidence, original Stage03J inventory/documents, run06 and other historical evidence were not rewritten. Both historical inventories now differ at their three intentionally updated live paths; original bytes are retained in their corresponding backups. No unexpected evidence drift was detected.

## Exact limits of the claim

For a valid attempt that reaches the lifecycle consumed-attempt registry, its GUID identity cannot be reopened by case variants. After a valid-ID wrapper admission/provider refusal has been registered, subsequent supported wrapper or direct Start calls in that supervisor cannot create it, including after resource recovery or local flag changes.

This is not a universal or durable prohibition across arbitrary processes, assembly reloads or malformed invocation contracts. Direct native argument/mode validation happens before registry admission; invalid contract calls are refused without claiming a consumed valid admission. The wrapper's initial scope/created/terminal assertion also remains before its catch. The registry lasts only for that supervisor's process; changing to a genuinely new attempt ID is not the same logical attempt. The change does not cancel an already-running call that acquired creation authority before a competing refusal, and MarkAttemptRefused never terminates a helper. This is not same-account security isolation.

The RAM check remains point-in-time admission rather than continuous monitoring or an OS cap. A directly refused call may leave the preexisting scratch-preparation side effect. No helper startup/IPC/exit under the final guard has been demonstrated. NVIDIA lifecycle, GPU attribution, full budgets and runtime compatibility remain outside this correction.

## Review gate and rollback

The coordinator must complete a new independent review of these exact hashes before releasing the single benign NORMAL_EXIT. Use a fresh supervisor and fresh eligible RAM/headroom if that later step is released; create separate evidence and do not run old harnesses that launch six cases or select run06. This package neither starts nor schedules that attempt.

No Python, ComfyUI, LTX, NVIDIA, GPU workload, G4/G5, Alpha or MCP was started or enabled. No foreign process was terminated; MIRAE and Pulse were not accessed. Human parameters, budgets, policies and consent ABSENT are unchanged.

Rollback, only if separately directed: revalidate current hashes and the incremental backups, restore these three backup files together to recover the first correction's final state, verify its 21 pins/binding, and retain both recovery packages. No rollback or deletion was performed.
