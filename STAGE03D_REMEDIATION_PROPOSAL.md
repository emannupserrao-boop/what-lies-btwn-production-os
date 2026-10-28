# WHAT LIES BTWN — bounded Stage03D remediation proposal

Date: 2026-10-13; Europe/Bucharest. **PROPOSAL ONLY. NOT AUTHORIZED OR IMPLEMENTED.**

Stage03C result: COMPLETE_WITH_LIMITATIONS; G4 startup and G5 job remain blocked.
Finding IDs refer to `STAGE03C_REVIEW_REPORT.md`. No limit increase, package installation, shared-venv change, approved workflow creation or GPU execution is part of this proposal.

## 1. Human decisions and exact authority boundaries

Before implementation can make startup eligible, confirm operator identity, the required CPU policy, monitor cadence/maximum telemetry age and the boundary mode. These are facts/decisions, not values to infer. Preserve RAM >=8 GiB, commit headroom >=10 GiB, incremental commit <=4 GiB, private bytes <=4 GiB, incremental VRAM <=2 GiB, startup <=120 s, job <=30 s and aggregate output/log <=256 MiB.

Boundary mode: either separately authorized protected code/approval ownership and any required OS/network controls, or explicitly accepted supervised same-account model-free POC limitations. A same-account mode must never claim authenticated independent approval authority, general filesystem confinement or network egress enforcement. Creative tools must retain no execution authority. Root/core/policy currently have inherited Authenticated Users Modify permission; hashes alone do not protect them.

Authorization separation:

| Future scope | May authorize | Must remain closed |
| --- | --- | --- |
| Stage03D source-only | Specific code/policy/docs changes below and owned local fixtures; preserve current gate defaults | Imports, server/startup, real approval activation, network, GPU and host changes |
| Separate bounded snapshot preparation | Read named Comfy source/license/dependency identities; copy only reviewed bounded files into new runtime namespace; record exact inventory | Shared source/venv mutation, installs/downloads, custom nodes/models, imports/startup |
| Separate G2 if chosen | Exact reviewed ACL/identity/network changes, with operator ownership/recovery instructions | Unlisted host changes and runtime execution |
| Separate G4 | Startup/import validation for the pinned dedicated candidate, with monitor and explicitly authorized own-process stop | POST /prompt, approved graph/job and GPU inference |
| Later G5 preparation + separate one-job authority | Reviewed promotion/approval/adapter/QC and exactly one specified job | Automatic retry, general queue, arbitrary job/workflow/provider access |

## 2. Smallest G4-ready changeset

| Priority | Proposed file/function | Minimal work | Findings | Local verification before G4 |
| --- | --- | --- | --- | --- |
| P0 | core\Test-WlbManifest.ps1 + core\Wlb.Common.ps1 | Explicit JSON integer/boolean/array checks for graph and consumed policy fields; keep static mode and submission refusal | 09,10 | Original DRAFT baseline passes; strings/arrays/coercion variants, missing/extra keys and cap drift reject after consistent fixture rebinding |
| P0 | policy\executor-policy.schema.json (small new local contract) OR equivalent explicit required-key/type assertions | Validate only reviewed policy/startup contract, fixed endpoint/arguments and monitor rules; local schema references only | 10,13 | No external schema retrieval; wrong booleans/numbers/endpoint/args and UNKNOWN monitor rules reject |
| P0 | policy\executor-policy.json + policy\runtime-lock.json | Resolved operator/CPU/cadence/freshness/boundary decisions; pinned source/Python/dependency inventory when separately authorized; explicit startup-only gate defaults false and job execution false | 01,02,03,07,13 | Missing/untrusted/tampered source identity, unresolved essential fields and unsupported startup configuration remain ineligible |
| P0 | core\Wlb.Common.ps1 | Immutable byte/handle validation helpers and exclusive owned namespace reservation for startup logs/evidence; safe no-overwrite handling, protected-parent prerequisite or clearly bounded supervised mode | 01,06 | Competing CreateNew attempts, changed parent/bytes and existing destinations never overwrite; isolated link checks only without elevation |
| P0 | core\Start-WlbRuntime.ps1 (small new startup-only entry point) | No arbitrary CLI/URL/path input; separately authenticated or explicitly supervised gate-scoped G4 consent; fixed pinned process candidate; dedicated engine mutex/reservation; verify PID/creation time/image/port ownership; process-local cache/temp/state settings; bounded evidence | 01,03,04,05,07 | Pure startup-plan and injected launcher/identity fixtures; unauthorized consent, existing listener/reservation and candidate mismatch refuse; no real process in source-only tests |
| P0 | core\Wlb.RuntimeMonitor.ps1 (small helper or equivalent functions in startup script) | Preflight and pre-start baseline; trustworthy RAM/commit/private/VRAM readings, foreign-heavy/GPU checks, monotonic startup timeout, missing/stale-counter refusal, aggregate logs/output budget and authorized owned shutdown, failure evidence preserved | 02,04,13 | Injected counters/clocks/log sizes at boundaries and above; staleness, unavailable attribution, watcher error and wrong-process stop all block without touching foreign processes |
| P1 | README.md + spec\FUTURE_EXECUTION_CONTRACT.md + new Stage03D receipt | Distinguish source tests, startup evidence and job evidence; enumerate exact proposed files, decisions, unresolved controls, authorizations and newly computed bindings | All | Manual consistency check against implemented code/test evidence; no PASS for absent controls |

Keep `core\Invoke-WlbJob.ps1` unconditionally closed. Do not change draft workflow class names/values or create `workflows\approved`. Update hashes for legitimately changed code/schema/policy/lock/Bible references and bind the DRAFT manifest to the new preparation revision; updated hashes are not approval. No generic multi-agent harness, MCP integration, model system or architecture replacement is necessary for this slice.

Snapshot/dependency preparation must first specify an exact allowlisted copy inventory and bounded size. Exclude .git, models, custom_nodes, input/output/user/temp/config/cache/credentials and link objects, while retaining required upstream licensing. Historical Git SHA does not substitute for on-disk source identity. Do not run the candidate Python or scan unrelated MIRAE/PULSE/production content during source-only work. If a required dependency or local telemetry interface is unavailable, report BLOCKED; obtain a separate installation scope rather than altering the existing environment.

Operational watchers provide measured abort thresholds, not hard memory-allocation guarantees. Specify maximum data age, attribution limits, polling delay and own-process stop/escalation before G4. If reliable VRAM/commit telemetry cannot be obtained with available local tooling, startup stays blocked. Never resolve contention by terminating LTX, foreign Comfy or a generic python.exe name.

## 3. Required later G5 work; deliberately outside the minimal G4 changeset

| Proposed later work | Findings | Verification |
| --- | --- | --- |
| Execution-eligibility schema/state contract, immutable promoted graph and confirmed job owner | 12,13 | DRAFT/UNKNOWN/not-promoted/mismatched graph/policy/runtime/owner cannot become executable |
| Authenticated one-job approval plus durable atomic consume-before-action under engine lock | 01,05,06 | Forged/expired/wrong-job/changed-bytes/consumed/restored records, concurrent claims and interruption at each durable transition never authorize a duplicate |
| Fixed loopback adapter with exactly one POST, persistent job/client/prompt identity, no redirects/proxy/retries, uncertain-result reconciliation | 08 | Injected lost responses, ambiguous timeout and restart produce BLOCKED_UNCERTAIN and never resubmit |
| Scoped owned cancellation and authorized own-process escalation | 04,08 | Foreign prompt/process, reused PID or ambiguous ownership cannot be cancelled/interrupted/terminated |
| Full PNG CRC/decode/every-pixel QC, one-output/no-overwrite accounting and authentic resource/device/policy/receipt bindings plus human verdict | 02,06,11 | Malformed/truncated/wrong-color/extra outputs and forged/stale evidence cannot produce acceptance |

Model/input hash validation, asset rights, character consistency, video/audio QC, Alpha/VFX, MCP, broader queues and alternative engines remain optional future work. They are not prerequisites for the synthetic POC graph. No absence of a future optional feature should be disguised as a POC success or used to broaden Stage03D unnecessarily.

## 4. G4 admission criteria after separately authorized preparation

1. Stage03D source/fixture tests complete; original known coercion cases all reject and intended baseline still passes.
2. Operator identity, CPU/cadence/freshness and supervised/OS-boundary choice documented; any selected G2 work independently authorized and verified.
3. Bounded snapshot, licenses, Python/dependency fingerprints, imports/CLI review and process-local paths available; no shared production mutation.
4. Owned engine/process/namespace and trusted immediately current RAM/commit/VRAM/foreign-workload preflight verified; monitoring and own-stop authority defined for the entire startup.
5. Explicit G4-startup-only authorization identifies exact pinned bytes, startup budget/120 s deadline and own-process cleanup authority. GPU-job launcher remains closed and no real one-job approval is issued by remediation.

Only then propose one supervised G4 attempt with evidence retained on failure and no automatic retry. Success at G4 does not authorize G5. A 640x360 tensor estimate is not startup-memory evidence. Do not claim that POC will fit before measured G4/G5 evidence.

## 5. Stop condition

This document is a reviewable proposal, not approval. Stage03C made none of these source or host changes. **WAITING_HUMAN_REVIEW. STOP BEFORE STAGE03D.**
