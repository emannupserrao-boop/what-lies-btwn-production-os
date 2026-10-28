# WHAT LIES BTWN — STAGE 03D-1 STRICT CONTRACT REMEDIATION

Date: 2026-10-13; timezone: Europe/Bucharest. Authority: exclusively validators, typing, static contracts, directly affected bindings, isolated tests and reports.

## A. STAGE03D1_STATUS = PASS

S03C-09 and S03C-10 are closed for the prepared POC-0 static contracts. This PASS is not authorization or readiness for G4/G5. All execution gates remain closed.

Final regression matrix: 725 rows, including 693 executed static checks, all PASS; zero FAIL. The other 32 rows retain Stage03C assessments: 24 NOT_IMPLEMENTED, 5 NOT_TESTED, 3 BLOCKED. These are not newly verified operational controls.

## B. EXACT_CHANGESET

Exactly four preexisting files changed. No policy schema or package was added. The policy contract is local, explicit PowerShell data and type assertions with no reference-resolution/network dependency.

| File under Production OS root | Bytes before / after | SHA-256 before | SHA-256 after | Justification |
| --- | --- | --- | --- | --- |
| core\Test-WlbManifest.ps1 | 5547 / 4703 | 960c8985a19c161e1a225faa59510ec655c6b53c066a0c7cf7574fedd4e668b3 | 0cee15697d17b2a9e43a4fb91f042bd7646844c020a038b1834a75a390867509 | Invoke strict policy/graph contracts; require integer manifest budget scalars; retain all existing binding/path/state/value checks and unconditional ExecutionEligibility refusal. |
| core\Wlb.Common.ps1 | 5376 / 11364 | 4af7db578950a266dffc8ae8b2fb9f188cd26ed2d8133fa3c8b9d4bdbb57b7e1 | 193f970e487ee61cc59ae464cd8cb78bc95c95fd5e70af18eb53226e71b69255 | Untyped value boundaries; integer/boolean/string/array/object/null contracts; exact required keys; canonical graph/link; full policy shape/type contract; preserve JSON root container without pipeline unwrapping. |
| manifests\draft\POC0-CALIBRATION-001.json | 4514 / 4514 | 2b6cde0ef8db97cc42fc808d307d24004714f6cc81e009fa8a11e003a6c3bf31 | 86c76c58eba4fc80a1398dcf51f1c3ede9823242e72473601a4ba8073b1ae6f1 | Replace only binding.runtime_lock_sha256; all DRAFT/nonapproval/graph/parameter/budget/owner/provenance values preserved. |
| policy\runtime-lock.json | 3049 / 3049 | 43c0643240753edf5709d480226317cacdcd287605a32ef22ce17b0c720ee5b5 | b8d3d5034191a02df4a0003eb2533aa8b86535c65cbfe5951902862b46810ce6 | Replace only prepared_artifacts SHA-256 values for the two changed PowerShell files; no new runtime identity or gate claim. |

Full machine-readable before/after values: tests\stage03d1\evidence\EXACT_CHANGESET.json and .csv; source/binding delta: SOURCE_AND_BINDING_DIFF.md.

Implementation specifics: scalar values enter untyped parameters, then int/long JSON integer, bool, string, array or null types are checked before comparisons. Strings, arrays, objects, booleans, null and floating representations cannot satisfy an integer field. Every graph/policy object has exactly the required case-sensitive keys. The image link must be a two-element array, with string node ID "1" and integer slot 0; classes, calibration values and destination prefix retain the original fixed values. Policy allowed_nodes must be exactly the two correctly typed ordered strings, preventing comma-joined singleton ambiguity. The complete current policy shape, nested types and all consumed budget fields are validated; declarations remain declarations.

Read-WlbJson additionally preserves root container identity through both ConvertFrom-Json and the function pipeline, rejecting array-wrapped graph/policy roots. Two before-fix failing probes and component/full-validator post-fix rejections are recorded. This is necessary static JSON contract remediation within scope, not new operational architecture.

The runtime lock changes only the two source hash entries; the manifest changes only binding.runtime_lock_sha256. Their other parsed fields are proven identical. Revision, DRAFT state, no active approval, graph bytes/hash, policy bytes/hash, parameters, limits and unknown runtime/owner/CPU facts are unchanged. Recomputed hashes are consistency maintenance and confer no promotion, gate authority, approval or runtime success.

## C. SEVEN_DISTINCT_FAILURES_CLOSURE

| Required case | Current outcome | Actual rejection |
| --- | --- | --- |
| D-STRING-WIDTH | PASS | BLOCKED: Expected JSON Integer at graph/1/inputs/width |
| D-ARRAY-WIDTH | PASS | BLOCKED: Expected JSON Integer at graph/1/inputs/width |
| D-STRING-BATCH | PASS | BLOCKED: Expected JSON Integer at graph/1/inputs/batch_size |
| D-STRING-LINK-SLOT | PASS | BLOCKED: Expected JSON Integer at graph/2/inputs/images/1 |
| COMPOSITE-POLICY-STRING-BOOL | PASS | BLOCKED: Expected JSON Boolean at policy/auto_retry |
| COMPOSITE-POLICY-STRING-BUDGET | PASS | BLOCKED: Expected JSON Integer at policy/budget/max_incremental_commit_gib |
| COMPOSITE-POLICY-STRING-CONCURRENCY | PASS | BLOCKED: Expected JSON Integer at policy/max_active_jobs |

All four corresponding full-validator graph cases (COMPOSITE-STRING-WIDTH, COMPOSITE-ARRAY-WIDTH, COMPOSITE-STRING-BATCH and COMPOSITE-STRING-LINK) also reject. Their fixtures have correctly rebound hashes, so rejection is from strict contracts rather than stale fingerprints. JSON root-array variants also reject both in components and full-validator copies.

## D. REGRESSION_TEST_MATRIX

Authoritative complete expectation/actual/status/evidence/fixture matrix: tests\stage03d1\evidence\run2\REGRESSION_TEST_MATRIX.md; data: run2\test-results.json. Seven-case closure: run2\seven-distinct-closure.json. The Stage03C coverage map identifies which prior rows were rerun and which are preserved historical evidence; no claim that all 218 old inventory/approval/QC checks were newly executed.

All 15 original Stage03C composite variants were replayed, expanded to 28 full-validator fixture cases. Test-WlbManifest.ps1 is byte-identical to the current validator in every composite copy; only fixture-root literals in helper/data and fixture hashes are adjusted, then controlled malformed values/bytes are introduced. No validator predicate is weakened for tests.

Coverage includes all graph scalar fields and link/container types; each mandatory graph key and extra properties; each mandatory policy key at every nested object, extra properties, boolean/numeric/string/string-array/null/container alternatives; preserved JSON/schema negatives; unknown/model/custom/provider/network/shell/sampler types and extra nodes; destinations/links; path traversal/outside/UNC/ADS/collisions; enabled policy and invalid preparation state; graph/core/policy/runtime hash divergence; cap drift; missing lock inventory entry. No graph node or live launcher executes.

Evidence incidents are retained: first run saved its complete results before a case-insensitive variable collision in closure aggregation. Root-array probes then demonstrated a real static helper type defect and justified a fresh complete regression run after correction. Run2 raw summary grouping lost dictionary properties; FINAL_SUMMARY.json computes authoritative counts from recorded result rows. The test harness has the grouping correction for future runs. No failed evidence was deleted, overwritten or represented as runtime success.

## E. ORIGINAL_BASELINE_PRESERVATION

Before editing, all 13 source artifacts matched the final Stage03C hashes. Exact byte copies of all 13 are preserved under tests\stage03d1\baseline and verified against the pre-edit inventory. The before and final original-root StaticReview both pass as preparation with executable=false, approval=ABSENT and submission=NOT_PERFORMED.

Of 308 preexisting files, 304 retain bytes/hash and UTC last-write time; only the four authorized files differ. All 295 historical Stage03C files/reports are unchanged. Of the original 13 current files, nine are byte-identical and four have authorized changes; it would be incorrect to claim all 13 current files unchanged.

The canonical graph remains EmptyImage -> SaveImage, 640x360, batch 1, color 0x336699, one expected RGB PNG, no models/source inputs/sampling/providers/automatic retries. The workflow, executor-policy.json, shot-manifest schema, launcher, QC checker, Bible, README, future contract and original prep receipt are byte-preserved. The unchanged launcher ends with its unconditional G4/G5 refusal; ExecutionEligibility still refuses. No real approvals/jobs/approved-workflow/runtime namespace exists.

## F. REMAINING_G4_BLOCKERS

- S03C-01 / 07: issuer/code trust, inherited writable ACLs and OS/filesystem/egress boundary decision remain unresolved; no host hardening or approval authenticity implementation.
- S03C-02 / 04: no live trusted RAM/commit/private/VRAM telemetry, freshness, preflight, exclusive owned process/engine, foreign GPU-workload check, startup timer, watchdog or aggregate log/output enforcement.
- S03C-03 / 06: no executable snapshot/dependency identity/import validation, process-local cache isolation or path/byte TOCTOU/use-time protection and atomic namespace creation implementation.
- S03C-13: owner identity, CPU policy and monitor cadence/freshness remain UNKNOWN. Existing resource limits remain exactly unchanged; no runtime measurement or fit claim.
- Stage03D-2, any G2/G3 preparation, and G4 startup each require separate human authorization. No startup implementation was added here.

## G. REMAINING_G5_BLOCKERS

- All relevant G4 prerequisites remain.
- S03C-01 / 05: no authenticated operator-issued approval or durable atomic one-use consumption/replay protection.
- S03C-08: no job submission adapter, persistent ownership/deduplication ledger, ambiguous-timeout reconciliation, recovery, authorized owned cancellation or transport retry controls.
- S03C-12: no execution-eligibility lifecycle/promotion contract or approved workflow; DRAFT is not executable.
- S03C-11: no full PNG integrity/decode/every-pixel color QC or authentic device/resource/completion evidence and human acceptance path; QC accepted=false remains unchanged.
- General input/model hashing and character/media capabilities remain deferred; no Alpha Gen or MCP work performed.

## H. NO_OUT_OF_SCOPE_MUTATION_ATTESTATION

Directed modifications: the four listed source/binding files only. Directed creations: own Stage03D1 fixtures, exact baseline copies, test/finalization programs, evidence and this report, all inside Production OS. CREATED_FILES.csv enumerates every created absolute path and raw hash (self-referential inventory/attestation metadata excluded). COMMANDS.md / .json list operations and saved scripts preserve nested commands. all-existing-after-comparison.json supports scope preservation.

No changes to MIRAE, PULSE, LTX Desktop, production ComfyUI or any Python environment; no installs/downloads/dependencies, Python/CUDA/runtime imports, servers/GPU/images, external APIs, real approvals/consumption, process mutex/watchdog/HTTP/cancellation/snapshot implementation, ACL/firewall/registry/services/global environment changes or commits. The existing fixed native helper is invoked only for read-only file handle queries. This is an attestation of directed operations and scoped file evidence, not a whole-host before/after claim.

## I. NEXT_GATE = WAITING_HUMAN_REVIEW

Stage03D-1 delivered. STOP. Stage03D-2 is not authorized or started. G2/G3/G4/G5, approval, promotion and release remain closed.