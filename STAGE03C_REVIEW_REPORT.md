# WHAT LIES BTWN — Stage 03C independent static validation

Date: 2026-10-13. User timezone: Europe/Bucharest. Scope: Stage 03C only.
Root: `D:\WHAT-LIES-BTWN-PRODUCTION-OS`.

## A. STAGE03C_STATUS = COMPLETE_WITH_LIMITATIONS

The independent review is complete. The preparation foundation is structurally consistent, and the original manifest validator passed with `executable=false`. This is **not readiness for G4 startup or G5 rendering**. Both remain BLOCKED pending remediation, prerequisite evidence and separate human authorization.

The 13 original artifacts total 61,585 bytes. All 12 hash/size rows actually published inside the Stage 03B receipt match. The receipt itself was independently hashed; its historical external hash is unavailable in the supplied material, so comparison with that external value is NOT_TESTED. All nine runtime-lock artifact bindings and the manifest's workflow/policy/runtime/Bible references match independently recomputed bytes. Three historical source-contract/report hashes also match.

There are **218 recorded checks: 175 PASS, 11 FAIL, 24 NOT_IMPLEMENTED, 5 NOT_TESTED, 3 BLOCKED**. The 11 failures are four component checks plus seven full-validator fixture checks; four reproduce the same graph typing defects. The seven distinct full-validator cases comprise four graph typing cases and three policy typing cases. Expected negative rejections count as PASS. An accepted malformed fixture counts as FAIL. Missing safeguards count as NOT_IMPLEMENTED, even though the current execution gate is closed.

No original artifact was modified. No real launcher, approval activation, job, image generation, Python runtime, ComfyUI/LTX server, external API or GPU inference was invoked. No installation, ACL/firewall/global-environment modification or Git operation occurred. Review files, test programs and fixtures are the only directed writes.

Evidence distinctions:

- **Executed original:** unchanged manifest validator, JSON/path/hash helpers and local JSON schema validation.
- **Executed extracted predicates:** original AST-selected graph and approval checks, without launcher invocation, approval consumption or submission.
- **Executed relocated validator:** byte-identical `Test-WlbManifest.ps1` against test-only copies. Only fixture root literals and fixture bindings changed; no validator guard was repaired. A relocated baseline passed before malformed cases were compared.
- **Static inference:** absence of process/network/submission implementations, source-only output checks and documented runtime limitations.
- **NOT_IMPLEMENTED / NOT_TESTED / BLOCKED:** distinct from operational protection or successful runtime evidence.

## B. STAGE03B_ARTIFACT_VERIFICATION

Initial recursive inventory contained exactly the requested 13 files, with no unexpected file. Sizes and hashes below are independently recomputed SHA-256 of raw file bytes, not hashes of parsed JSON or assumed Git content.

| Relative path under root | Bytes | Independently computed SHA-256 | Receipt comparison |
| --- | ---: | --- | --- |
| core\Invoke-WlbJob.ps1 | 3185 | 2278e14b700fe722c5ca6d7e2d6e2245c3b88b1288fdee006da2cdd415a5fe66 | MATCH |
| core\Test-WlbManifest.ps1 | 5547 | 960c8985a19c161e1a225faa59510ec655c6b53c066a0c7cf7574fedd4e668b3 | MATCH |
| core\Test-WlbOutput.ps1 | 3661 | 283718ce05f5caaaefbf5ef6bb2ee070ee5b0bc92d91f2a65c0ccee6ef7a6768 | MATCH |
| core\Wlb.Common.ps1 | 5376 | 4af7db578950a266dffc8ae8b2fb9f188cd26ed2d8133fa3c8b9d4bdbb57b7e1 | MATCH |
| policy\shot-manifest.schema.json | 8781 | 5516147b01714d4bebe49036147de104ee9268995434cec27baac57882ed5e84 | MATCH |
| policy\executor-policy.json | 4191 | 2782c8aed1b02b959b6efb13eb4244a7e871d3bb8b279c554a0ddbceb22baf31 | MATCH |
| policy\runtime-lock.json | 3049 | 43c0643240753edf5709d480226317cacdcd287605a32ef22ce17b0c720ee5b5 | MATCH |
| workflows\draft\poc0-calibration.api.json | 311 | 0f9f407cf4aef2bb98aea9f44603521eec38558b986ed09e535c1259d6ae3a1e | MATCH |
| manifests\draft\POC0-CALIBRATION-001.json | 4514 | 2b6cde0ef8db97cc42fc808d307d24004714f6cc81e009fa8a11e003a6c3bf31 | MATCH |
| bible\character-bible.v0.1.json | 1424 | 08e216196d54297bc1868fbabdfac69305b77aa7eedd64715706ee829e0a70f8 | MATCH |
| README.md | 5185 | 2fb547300d35053cfaad9f113534c6c9dd2dcf33d47fc52f52b8b110df6d3712 | MATCH |
| spec\FUTURE_EXECUTION_CONTRACT.md | 6282 | b1f4712b9fac09a52aa8e8ab2698a7caaf2aff9ccdf950705ff3b5cef404e598 | MATCH |
| STAGE03B_PREP_RECEIPT.md | 10079 | e266304fe7704e9b5473a3b9eddd46fa52f374b51856056102d28294bec10096 | Recomputed; no historical external value available |

The lock deliberately fingerprints nine implementation/spec artifacts. It does not self-hash, bind the manifest, or include README/receipt. The manifest deliberately has no self-hash; a later external authenticated approval would bind it. These omissions are documented choices, not discovered hash mismatches. They also mean this is a **consistency chain, not an authenticated authority chain**.

Verified historical source hashes:

| Source | SHA-256 | Result |
| --- | --- | --- |
| D:\What Lies Btwn\WHAT_LIES_BTWN_STAGE03A_PRODUCTION_OS_FOUNDATION_DESIGN_v0.1.txt | f7ff595ac7292030b162e13cc7b3aa6db560965b626f2e6100371ebdf8e7df3c | MATCH |
| D:\What Lies Btwn\WLB_PRODUCTION_OS_STAGE03B_CORE_PREP_v0.1.txt | 495cb933e2c66613b08978740b211fc8eb9882c5e3430b1cdc4c6cf31d616cf5 | MATCH |
| C:\Users\user\.codex\attachments\89d4ccad-39e1-4c9a-846b-fc30c803dac6\Texto colado.txt | c77e83d38c2034fbe4feb25910cc179ed955d1242867cb529b398855514abdfd | MATCH |

The Stage 03A file available locally is the **design-request contract**, not the delivered accepted design response. Comparison with its stated requirements is supported; complete correspondence with an unavailable accepted response cannot be independently claimed. The prepared topology, separate executor authority, draft POC, human/QC gates and deferred Alpha capability align with that contract. Its complete one-shot state machine and privilege boundaries have not yet been implemented.

Four original PowerShell files parsed with zero diagnostics. Six JSON artifacts passed the original strict JSON reader. PowerShell 7.6.5 was observed, satisfying the 7.4 minimum. The fixed native link helper compiled in process and successfully inspected ordinary files. PSScriptAnalyzer was not installed; no package was installed. AST/source inspection supplements syntax parsing but is not represented as PSScriptAnalyzer output.

## C. TEST_MATRIX

The complete per-check expectation, actual outcome, classification, evidence kind and fixture path are in:

- `tests\stage03c\evidence\ALL_TEST_MATRIX.md` — all 218 checks.
- `tests\stage03c\evidence\ALL_TEST_RESULTS.json` — machine-readable consolidated evidence.
- `tests\stage03c\evidence\test-results.json` — original component run, preserved.
- `tests\stage03c\evidence\composite-results.json` — all 15 full-validator fixture cases.
- `tests\stage03c\evidence\composite-fixture-adaptations.json` — exact fixture relocation boundaries and validator identity checks.

| Test family | Verified result | Limits |
| --- | --- | --- |
| A — mandatory fields/types/IDs/states/JSON/schema | Missing top-level required fields, representative missing nested field, extra properties, wrong manifest types/IDs/states, malformed/duplicate/case-colliding/deep/oversize JSON, invalid local schema reference/version, parameter changes and cap increase rejected | Nested required-field coverage is representative, not exhaustive. Draft schema is not an execution schema |
| A — bindings/models/inputs | Raw workflow/policy/runtime/Bible/core mutations rejected against unchanged bindings; core/graph mutations also rejected in full fixture validator | No models or inputs exist in POC; additions rejected. Future per-model/per-input hash validation is NOT_IMPLEMENTED and optional for this POC |
| B — approval predicates | Missing file, wrong ID/job/scope, expired/malformed expiry, changed manifest/graph/runtime/policy hashes, UNKNOWN owner and CONSUMED status rejected | Component predicates only; no actual approval authority record or launcher invoked |
| B — forged/replayed authorization | Fabricated nonempty identity passes predicates; final extracted throw refuses. Authentication and atomic one-use consumption NOT_IMPLEMENTED | Current closed gate is not evidence of an authenticated issuer or durable replay protection |
| C — paths | Relative/dot traversal, outside-root paths, sibling-prefix escape, UNC/device/drive-relative paths, wrong drive, ADS, wildcard, empty paths and existing destination rejected; legal slash/case spelling normalized | Junction/symlink/hardlink escapes NOT_TESTED. No privileged object or ACL manipulation. Actual no-overwrite writes and TOCTOU protection NOT_IMPLEMENTED |
| D — workflow | Unknown/model/custom/provider/network/shell/sampler types, extra graph nodes, extra input, changed destination/link/color rejected | No node executes. String/array numeric coercion cases FAIL |
| E — executor | Original ExecutionEligibility refuses; static source has no current HTTP/process-start/retry implementation | Exclusive ownership, consumption, deduplication, uncertain-state timeout handling, recovery, cancellation and operational budgets NOT_IMPLEMENTED |
| Resource / isolation / QC | Constants verified; ACLs read; output checker and isolation policy inspected | Runtime resource measurements, real launcher and real output checks BLOCKED_PENDING_AUTHORIZATION |

The 11 FAIL rows are `D-STRING-WIDTH`, `D-ARRAY-WIDTH`, `D-STRING-BATCH`, `D-STRING-LINK-SLOT`, `COMPOSITE-STRING-WIDTH`, `COMPOSITE-ARRAY-WIDTH`, `COMPOSITE-STRING-BATCH`, `COMPOSITE-STRING-LINK`, `COMPOSITE-POLICY-STRING-BOOL`, `COMPOSITE-POLICY-STRING-BUDGET`, and `COMPOSITE-POLICY-STRING-CONCURRENCY`.

The five NOT_TESTED rows are historical receipt-hash comparison, optional PSScriptAnalyzer, and three link-escape classes. The three BLOCKED rows concern real launcher invocation, runtime measurement and real-output QC. All retain closed gates.

Three harness/finalizer incidents are preserved, not concealed: the component harness failed **after recording all 203 results**, when Measure-Object was applied directly to dictionary objects; only its summary aggregation was corrected. The first composite attempt failed before running its baseline because the manifest fixture parent was absent; its ten partial copied files remain under `tests\stage03c\composite`. The corrected harness used the new `composite-run2` directory and completed all 15 cases. The first finalization attempt generated a false preservation alert because PowerShell converted JSON timestamp strings to DateTime values before comparing them with strings. Read-only diagnosis confirmed every original size/hash and timestamp; loaded timestamps were then normalized without changing original or baseline files. These incidents are not Stage 03B defects. The finalizer consolidates existing evidence without rerunning tests, reusing already-created result files only when their contents are identical.

## D. SECURITY_FINDINGS

Severities below describe the impact of each gap **before enabling its relevant gate**. There is no observed current launcher-to-job bypass: the original launcher is still unconditionally closed. A party already able to edit executable files can alter a gate; checksums stored alongside those files do not remove that privilege.

### S03C-01 — HIGH — Approval issuer and executable trust are not protected

- Affected: `core\Invoke-WlbJob.ps1:18-35`, especially line 24; `policy\executor-policy.json:14-23,75-81`; root/core/policy ACLs.
- Evidence: `B-FORGED-AUTHENTICITY`; `filesystem-acl-readonly.json`. A fabricated `approved_by` passed all extracted predicates. The observed root, core, policy, launcher and policy file inherit Allow `Modify, Synchronize` for Authenticated Users (AU); protected ACLs are false. No effective-token write probe was performed.
- Mechanism: any allowed writer can invent issuer text, edit code/policy, and recompute adjacent hashes. An approval file is not proof of human issuance. Current final refusal prevents execution, but does not authenticate a future permit.
- Minimal correction: select and document the issuer/trust boundary; verify trusted code/policy ownership and issuer evidence before any gate can act. For a constrained supervised POC, require explicit operator acceptance of same-account limitations and keep creative tools technically unable to reach execution. Strong independent approval authority needs protected ownership or an equivalent separately provisioned trust anchor.
- Dependencies: operator identity, chosen threat model and trust ownership. Future authorization: Stage03D source-only work; separately G2 for ACL/identity changes, if selected; distinct G4/G5 authority. Verification: forged identity, mutable policy/launcher, replaced signed/bound bytes and unauthorized writer must not authorize startup/submission. Supervised mode must never claim adversarial isolation.

### S03C-02 — HIGH — Resource budgets have no operational enforcement

- Affected: `core\Invoke-WlbJob.ps1:40`; `core\Test-WlbManifest.ps1:58-63`; `policy\executor-policy.json:38-54`; `core\Test-WlbOutput.ps1:27`.
- Evidence: `E-RESOURCE-ENFORCEMENT`, eight RESOURCE-CONSTANT rows, resource table below. Constants match; no counter sampler, telemetry freshness check, startup/job timer, aggregate disk/log watcher or abort loop exists. The output checker has a post-hoc single-file size check only.
- Mechanism: valid declared budgets cannot stop actual startup memory, commit, VRAM or log growth. Missing telemetry cannot currently be evaluated or acted upon.
- Minimal correction: implement pre-start baseline, continuously sampled attributable counters, monotonic deadlines, stale/missing-counter blocking, aggregate output/log accounting and authorized owned-process abort with preserved evidence. Keep every existing threshold unchanged.
- Dependencies: available trustworthy Windows/GPU telemetry, approved sampling/data-age rule and owned-process identity. Future authorization: Stage03D source/fixture tests; G4 for runtime measurement/own-process stop; G5 for job deadline behavior. Verification: pure injected counter/clock fixtures for each threshold, stale/missing readings and watcher failure; separately authorized runtime peaks later. Operational abort thresholds are not hard allocator caps.

### S03C-03 — HIGH — No pinned runnable snapshot or startup/import boundary

- Affected: `policy\runtime-lock.json:5-33`; `policy\executor-policy.json:56-66`; future `runtimes\core\ComfyUI\main.py` (absent).
- Evidence: snapshot false/empty/null, Python hash null, runtime compatibility NOT_VERIFIED, cache redirects NOT_IMPLEMENTED; `RUNTIME-SNAPSHOT`, `ISOLATION-CACHE-REDIRECTS`.
- Mechanism: the historical Git/version record does not identify current source/dependency bytes or prove import behavior. Reusing `D:\Musicas\Bitter-End-Visual-Local\.venv\Scripts\python.exe` under the same account could write to permitted paths outside Production OS; cwd, `-B` and state-directory flags do not constrain all library code. No live outside-root write was tested or observed here.
- Minimal correction: separately prepare a bounded source snapshot excluding models/custom_nodes/state/credentials/links; record file hashes/licenses, Python identity and dependency provenance without modifying the candidate venv. Review startup imports and pin process-local cache/temp/config redirection. Missing provenance or unsupported CLI blocks startup.
- Dependencies: bounded source-copy approval and available local dependencies; S03C-07 boundary choice. Future authorization: separate snapshot/preparation scope and G4 imports/startup; G3 only if later installation is actually required. Verification: snapshot tampering, excluded files, link paths, missing identity and unsupported arguments fail safe local preflight; actual import/compatibility/write behavior only in later authorized G4.

### S03C-04 — HIGH — No exclusive engine/job/process ownership or GPU preflight

- Affected: `core\Invoke-WlbJob.ps1:37-40`; `policy\executor-policy.json:12,51-53`; `spec\FUTURE_EXECUTION_CONTRACT.md:24-26,38-40`.
- Evidence: `E-EXCLUSIVE-OWNERSHIP`, `ISOLATION-GPU`. `max_active_jobs=1` is checked as metadata; no cross-process mutex/reservation, PID+creation-time+image ownership or foreign-job check exists.
- Mechanism: a future launcher could race another launcher, attach to an unrelated port owner, or overlap LTX/another GPU workload. A mutex would serialize this executor only, not unrelated applications.
- Minimal correction: fail-closed engine mutex and exclusive owned namespace reservation; verify dedicated executable/process identity and listener ownership; authoritative immediately current foreign-GPU/heavy-job preflight, with no automatic foreign-process termination.
- Dependencies: S03C-02/03 and local telemetry. Future authorization: Stage03D simulations; G4 actual child/listener and owned shutdown. Verification: competing fixture claimants, existing reservation, wrong PID/creation time/image/listener and foreign workload reject. Missing GPU attribution also blocks.

### S03C-05 — HIGH — No atomic single-use approval consumption

- Affected: `core\Invoke-WlbJob.ps1:23,37-40`; `policy\executor-policy.json:18-22`; `spec\FUTURE_EXECUTION_CONTRACT.md:52-56`.
- Evidence: `B-ATOMIC-ONE-TIME-CONSUMPTION`, `B-REPLAY-RESTORED-UNUSED`, `E-SINGLE-USE-CONSUMPTION`. Current status comparison rejects CONSUMED text, but there is no consume operation, reservation or durable history.
- Mechanism: an UNUSED file could otherwise be read twice or restored after use; interruption between check and submit lacks a durable denial state.
- Minimal correction: authenticated approval, exclusive durable claim before action, no-overwrite same-volume reservation/transition and explicit recovery rules; never automatically restore UNUSED after uncertainty. Do not simulate this as already successful.
- Dependencies: S03C-01/04/06/08. Future authorization: Stage03D fixture-only implementation; G5 real one-job approval consumption. If G4 starts a process, its separate one-use startup consent needs equivalent gate-scoped semantics. Verification: concurrent claims, crash before/after claim, restored records and consumed-record reuse cannot authorize a second action.

### S03C-06 — HIGH — Paths are prechecked, not protected through use

- Affected: `core\Wlb.Common.ps1:38-80,97-104`; `core\Test-WlbManifest.ps1:16-27,49-56`; `policy\executor-policy.json:26-36`.
- Evidence: path negative tests passed; `C-TOCTOU`, `C-ATOMIC-NO-OVERWRITE` NOT_IMPLEMENTED. `Read-WlbJson` and `Get-WlbHash` validate/open/close/reopen; manifest raw text is read again for schema validation. No executor creation operation exists.
- Mechanism: another allowed writer can replace bytes/parents between checks and reads or between absent-destination check and future write. Reparse and link-count checks describe a moment, not an ongoing handle boundary.
- Minimal correction: use one validated immutable byte snapshot/held identity for parsing/hashing/submission; protect parent ownership; reserve files with CreateNew, durable flush and no-overwrite promotion; recheck required parent/handle identity at use. Preserve failures instead of cleanup.
- Dependencies: S03C-01 and supported Windows handle/rename semantics. Future authorization: Stage03D local owned-fixture tests; G2 only for chosen ownership hardening. Verification: controlled replacement races and duplicate creation must refuse or use the original pinned bytes; unprivileged isolated link fixtures only when supported. Actual junction/symlink/hardlink escape behavior remains untested in this review.

### S03C-07 — HIGH CONDITIONAL — No OS/filesystem/network sandbox

- Affected: `policy\executor-policy.json:62,75-81`; `README.md:68-75`; future process launch (absent).
- Evidence: `ISOLATION-PROCESS`, `ISOLATION-OS`, `ISOLATION-EGRESS`, `ISOLATION-ACL`; policy expressly declares no OS sandbox or egress enforcement. ACL observation in S03C-01 supports lack of a restrictive file authority boundary.
- Mechanism: fixed graph allowlisting prevents graph-level provider/command nodes; it does not confine Python imports or arbitrary same-account code. Loopback listen and offline configuration do not enforce egress denial. Directory flags do not deny writes elsewhere.
- Minimal correction: make the operator's boundary choice a hard prerequisite: separately authorized OS/access/network restrictions if those are required, or explicit supervised same-account acceptance for the limited model-free POC with no claim of strong isolation. Do not redesign the whole architecture merely to add an optional future sandbox.
- Dependencies: human risk decision and S03C-03 import review. Future authorization: G2 for any host boundary changes; G4 runtime checks. Verification: in a separately authorized constrained environment, evaluate permitted/denied writes and egress without touching production. Supervised mode must retain clear residual-risk labeling and closed autonomous submission.

### S03C-08 — HIGH BEFORE G5 — No submission lifecycle/recovery/cancellation adapter

- Affected: `core\Invoke-WlbJob.ps1:37-40`; `spec\FUTURE_EXECUTION_CONTRACT.md:57-71`.
- Evidence: E-DUPLICATE-SUBMISSION, E-AMBIGUOUS-TIMEOUT, E-INTERRUPTION-RECOVERY, E-CANCELLATION-AUTHORIZATION and E-NO-AUTO-RETRY-CONTROL are NOT_IMPLEMENTED. No present HTTP client exists; current no-submit/no-retry source checks pass.
- Mechanism: a future POST can succeed despite response timeout; without a durable ledger and owned reconciliation, duplicate jobs or unauthorized global cancellation could result. Metadata `auto_retry=false` cannot configure a nonexistent transport.
- Minimal correction: later bounded fixed-loopback adapter, durable single job/client identity, exactly one POST, disabled transport retries/redirects/proxy, uncertain outcome as BLOCKED with read-only owned history reconciliation; cancel only exact owned prompt/process under authorized scope. Preserve evidence.
- Dependencies: S03C-01 through 06 and execution contract revision. Future authorization: later G5 implementation/test scope; real submit/cancel only separately approved G5. This adapter need not be enabled for G4 startup-only testing. Verification: injected transport timeout-before/after-acceptance, lost response, restart and wrong-job cancel fixtures never cause resubmit or foreign intervention.

### S03C-09 — MEDIUM — Graph numeric checks accept strings and arrays

- Affected: `core\Test-WlbManifest.ps1:45-46`.
- Evidence: four D-* FAIL rows and four COMPOSITE-* graph FAIL rows. A width of `"640"` or `[640]`, batch `"1"`, and link slot `"0"` pass; a full relocated baseline and rejection controls also pass.
- Mechanism: PowerShell `-eq` converts types and can return matching array elements, which then coerce to true. Exact node-key checks do not type-check input values. The manifest schema validates manifest parameters, not graph inputs.
- Minimal correction: require integer JSON scalars for graph dimensions/batch/color and integer link slot; require an actual two-element link array with string node ID, then compare exact values. A small closed graph schema or explicit type assertions suffices.
- Dependencies: original JSON reader already exists; no new package required. Future authorization: Stage03D source edits and isolated tests only. Verification: every seven distinct full-validator malformed typing case must reject after consistent fixture rebinding; original canonical graph must still pass. Existing hash checks reject changed unapproved bytes, so these results do not demonstrate an approval/hash bypass.

### S03C-10 — MEDIUM — Policy lacks strict types/schema

- Affected: `core\Test-WlbManifest.ps1:29-34,58-63`; `policy\executor-policy.json`.
- Evidence: COMPOSITE-POLICY-STRING-BOOL, -STRING-BUDGET and -STRING-CONCURRENCY FAIL. `execution_enabled="false"`, `auto_retry="false"`, a budget `"4"`, and concurrency `"1"` pass full validation with matching fixture bindings.
- Mechanism: policy has no strict schema; coercive comparisons accept wrong JSON types. Further declaration fields such as path rules, monitor and runtime options are hashed but not semantically enforced by the current validator.
- Minimal correction: strict local policy contract/type assertions for fields actually consumed by validators/startup; validate required keys, boolean/integer scalars, fixed route/endpoint and supported runtime options. Validate runtime identity semantics once the snapshot exists. Do not describe unused declarations as enforcement.
- Dependencies: reviewed policy/lock revisions and S03C-03 for actual runtime fields. Future authorization: Stage03D source/fixture scope. Verification: malformed types/extra/missing required policy keys, cap drift and disallowed arguments reject, unchanged intended policy passes; no installation.

### S03C-11 — MEDIUM BEFORE G5 ACCEPTANCE — Output QC cannot authenticate completion or image contents

- Affected: `core\Test-WlbOutput.ps1:12-19,30-48`; `policy\shot-manifest.schema.json:84-95`.
- Evidence: QC-FULL-PNG-DECODE and QC-EVIDENCE-AUTHENTICITY NOT_IMPLEMENTED. Only 33 header bytes are read; no CRC, IDAT/IEND, full decoding or pixel comparison. Resource/device/completion fields are required by name but their content/authenticity is not checked. `accepted=false` is unconditional and honest.
- Mechanism: matching header/hash cannot prove a valid full PNG or uniform color, nor that a GPU/job/measurement actually occurred. A string prompt ID is not proof of owned execution.
- Minimal correction: full locally available bounded PNG decode/CRC and every-pixel check, one output/receipt bound to immutable execution bytes/policy/device/resource history, explicit independent review and human acceptance. Fail safe if decoder unavailable; no package installation implied.
- Dependencies: S03C-08 trusted receipt production, source identity and locally available decoder. Future authorization: later source/fixture QC work; G5 actual output and human verdict. Verification: corrupt/truncated chunks, wrong pixels, extra outputs, false receipts, stale resource/device evidence and missing verdict cannot produce acceptance. No image was generated in Stage03C; production output checker was not invoked.

### S03C-12 — MEDIUM BEFORE G5 — Preparation schema cannot be promoted into an execution contract by toggling state

- Affected: `policy\shot-manifest.schema.json:25,42-45,99-108,124-128`; `core\Test-WlbManifest.ps1:65-69`; `core\Invoke-WlbJob.ps1:14,28-29`.
- Evidence: schema lists lifecycle states, but constants require DRAFT_NOT_PROMOTED workflow, draft path, record_created=false, NOT_EXECUTED/NOT_VERIFIED placeholders. Static mode additionally requires DRAFT; ExecutionEligibility always refuses; launcher still validates the draft path.
- Mechanism: a REVIEWED or approved manifest cannot satisfy the current full preparation validator; simply copying a graph to an approved directory or flipping execution flags does not implement promotion or lifecycle invariants. This is an intentional preparation limitation, not current fail-open execution.
- Minimal correction: keep preparation mode, add a separately reviewed execution-eligibility contract only when G5 work is authorized; bind promoted immutable workflow bytes, confirmed owner, actual runtime identity and gate-scoped approval. Persist legal state transitions rather than treating an enum as a state machine.
- Dependencies: S03C-01/03/05/08. Future authorization: G5 preparation/promotion and separate actual job permission. Verification: DRAFT/UNKNOWN/not-promoted/mismatched state combinations remain ineligible; no approved workflow is created by Stage03C or by the proposed G4-only Stage03D subset.

### S03C-13 — LOW / REQUIRED HUMAN INPUT — Essential owner/CPU/cadence facts are unresolved

- Affected: `manifests\draft\POC0-CALIBRATION-001.json:7-11,84` (owner and provenance.cpu_budget); `policy\executor-policy.json:54` (monitor.polling_interval); `README.md:59-65`.
- Evidence: owner UNKNOWN/null, CPU budget UNKNOWN/null, sampling cadence UNKNOWN; source says these need resolution before execution. The original static review legitimately permits these preparation placeholders.
- Mechanism: startup approval ownership, monitor data-age guarantees and a required CPU policy cannot be inferred from folder/account names or from declared memory thresholds.
- Minimal correction: obtain explicit operator identity and approved POC CPU/cadence/freshness rules; make actual startup preflight reject unresolved essentials. Do not invent CPU limits or increase any existing limit.
- Dependencies: operator facts and S03C-02. Future authorization: human Stage03D policy decision, then G4. Verification: UNKNOWN, missing/stale telemetry rules and unconfirmed owner refuse startup. Character asset rights/licensing remain UNKNOWN but are optional/deferred for synthetic model-free POC; they block later character/model production.

## E. IMPLEMENTATION_GAP_MATRIX

### POC-0 contract

The graph is exactly `EmptyImage -> SaveImage`: two node keys, link `["1",0]`, width 640, height 360, batch 1, color 3,368,601 = `0x336699`, prefix `POC0-CALIBRATION-001/calibration`. Manifest/schema match these intended values, require one RGB 8-bit PNG and prohibit overwrite. Models, source assets and reference frames are empty. Prompt/negative/seed/FPS/audio are reasoned typed N/A. No sampling/provider/API/external-input node or automatic retry path exists. Manifest is DRAFT and declares no approval record. No real approvals, approved workflow, runtime directory or job directory exists at the root. Test-only copied paths under tests are fixtures, not promoted workflows/runtime state.

The graph and manifest/schema agree for the original bytes; graph typing is the demonstrated exception for malformed variants. This static graph review does not prove native node registration, CUDA selection, real output encoding, single-output behavior, runtime compatibility or resource fit. No image was generated.

| Control | Current result | Required for G4 startup-only | Required for G5 one-job/QC | Optional future |
| --- | --- | --- | --- | --- |
| Strict JSON/manifest/fixed graph identity | Implemented and tested; graph/policy typing failures | Fix shared validation | Fix execution contract | General shot variants |
| Closed gates, no arbitrary submit parameters | Original source unconditionally refuses | Keep GPU submit gate closed | Reviewed one-job adapter | MCP integration |
| Issuer/code trust boundary and owner | Missing; writable inherited ACLs observed | Explicit boundary choice and trusted startup consent | Authenticated single-job approval | Stronger sandbox if supervised POC accepted |
| Runtime source/Python/dependency identity/import review | Missing | Required before startup | Reuse verified G4 identity | New model/custom-node systems |
| Process-local cache/temp/state paths | Declared, not implemented | Required | Required | Alternate engines |
| Engine/process ownership, foreign-GPU preflight | Missing | Required | Required | Multiple GPU scheduling |
| Resource counter/watchdog/deadline/aggregate logs | Constants only | Required across startup | Also required across job | Larger workloads |
| Atomic reservations/path use/no overwrite | Prechecks only | Required for startup evidence/process ownership | Also required for approval/job/output | Generic workflows |
| One-job POST/reconciliation/cancel/no retry | Missing | Keep absent/disabled | Required before G5 | Autonomous queues |
| Full PNG/pixel/device/resource/human QC | Header/hash only; accepted=false | No image QC needed for startup-only | Required before acceptance | Video/identity/audio scoring |
| Model/input hashes and asset rights | Empty lists required | Not applicable | Not applicable to synthetic POC | Required for model/asset jobs |
| Character Bible/Alpha/VFX/MCP/agent harness | Design references only | Not required | Not required | Deferred; Alpha remains NO_GO |

### Resource policy validation

All eight declared values agree among manifest, schema and policy. This is value validation, not enforcement or performance evidence.

| Limit | Measurable in later authorized runtime | Current implementation | Required enforcement |
| --- | --- | --- | --- |
| Available RAM >=8 GiB | Windows current available physical memory | Constant checks only | Immediate preflight plus live freshness/threshold watcher |
| Commit headroom >=10 GiB | Commit limit minus current committed bytes | Constant checks only | Same across startup/job; missing measurement blocks |
| Incremental commit <=4 GiB | Current total commit minus pre-start baseline; host changes can confound attribution | No sampler/baseline | Define baseline/attribution; conservatively block ambiguous readings |
| Process private bytes <=4 GiB | Owned process private-byte counter | No sampler | Verify PID/creation time/image; live watcher |
| Incremental VRAM <=2 GiB | Reliable existing local GPU telemetry with device/process attribution | No telemetry/interface verified | Missing/stale/unattributable evidence blocks; no inferred tensor-size proof |
| Startup <=120 s | Monotonic clock from authorized child start | No start/timer | Watchdog with owned abort and preserved evidence |
| Job <=30 s | Monotonic job timing plus trusted owned-engine state | No job adapter/timer | Deadline plus uncertain-outcome reconciliation, no resubmit |
| Output + logs <=256 MiB | Aggregate owned namespace/log accounting | One output-file <=256 MiB check in source only | Aggregate write/log growth watcher; bounded log ingestion |

Polling can detect and abort after thresholds; it cannot guarantee zero transient allocator overshoot. Strong hard OS/resource caps require separate support/authorization. Runtime measurements are BLOCKED_PENDING_AUTHORIZATION, and this review makes no claim that the POC fits RAM/commit/VRAM budgets.

### Isolation levels

Application validation has executed evidence: strict JSON, manifest schema, exact node/type-name allowlist, hashes, lexical containment and existing-destination rejection, with typing defects noted. Process ownership/isolation is absent. OS sandbox and network egress enforcement are explicitly absent. ACL reads show broad inherited write authority, not independent executor/operator separation. GPU concurrency is a policy declaration without a monitor or engine lock. The candidate existing Comfy Python environment was not run, imported, altered or deeply scanned. Its future broad same-account filesystem capability remains a concrete residual risk, not a tested outside-root write event.

## F. STAGE03D_REMEDIATION_PLAN

See `STAGE03D_REMEDIATION_PROPOSAL.md` for the bounded file-level proposal, acceptance tests, dependencies and separate authorizations.

Smallest G4-ready subset: fix type validation; resolve owner/CPU/monitor/trust decisions; separately fingerprint bounded source/dependency candidates; implement dedicated startup-only gate, owned process/engine reservation, current preflight and startup resource/log/deadline watchdog, process-local paths and authorized owned shutdown. Keep `Invoke-WlbJob.ps1` and GPU submission closed. Do not install anything or modify shared environments as an incidental prerequisite. Source snapshot preparation, host boundary changes and G4 startup each need their own explicitly described authority.

Atomic one-job approval consumption, submission/reconciliation/cancellation, execution-manifest promotion and decoded-image QC remain required before G5/acceptance, but are not reasons to add a full rendering executor to a startup-only G4 changeset. No broad architectural replacement is justified by the present evidence.

## G. NO_MUTATION_ATTESTATION

The full file-by-file created inventory, including partial fixtures, reports, evidence and test scripts, is `tests\stage03c\evidence\CREATED_FILES.csv`. It lists absolute path, size and SHA-256 for each file; its own and the companion attestation's self-hashes are deliberately excluded to avoid recursion. `tests\stage03c\evidence\NO_MUTATION_ATTESTATION.md` records final preservation checks and the resulting file count.

Every shell command issued is recorded verbatim in `tests\stage03c\evidence\COMMANDS.md` and `COMMANDS.json`; nested operations are available in the three saved Stage03C scripts. File-edit tool operations are also enumerated there. The only edits after initial creation were to the two test harnesses, the explicitly marked test-only core comment mutation, and review/evidence authoring. The original 13 files were not patched or overwritten.

`originals-before.json`, `originals-after-tests.json` and `originals-final.json` support independent byte/hash/last-write-time preservation. The final comparison records 13/13 unchanged. Root policy remains execution_enabled=false, manifest DRAFT/record_created=false, no real approvals/jobs/workflows\approved/runtimes paths created.

The native helper uses a fixed in-process Add-Type definition and read-only Windows file-handle query; no persistent output assembly was requested. No full-host before/after inventory was taken, so this attestation describes the agent's directed operations and original-artifact preservation, not unrelated Windows/application activity or a host-wide sandbox proof. No credentials were read, no external network request was issued, and no production assets/environments were changed by directed operations.

## H. NEXT_GATE = WAITING_HUMAN_REVIEW

Stage03C delivered. G2/G3/G4/G5, workflow promotion and release remain closed. Human review of the findings and bounded Stage03D proposal is the next gate. **STOP. Stage03D is not authorized or implemented.**
