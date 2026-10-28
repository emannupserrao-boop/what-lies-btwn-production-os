# WHAT LIES BTWN — Stage 03B CORE-PREP evidence receipt

Date: 2026-10-13; user timezone: Europe/Bucharest.
Evidence labels: EVIDENCE = observed preparation/read-only inspection;
DESIGN = proposed behavior or source contract; NOT_VERIFIED = no runtime proof.

## A. STAGE03B_STATUS = CORE_PREP_COMPLETE_WITH_LIMITATIONS

EVIDENCE: the 11 requested deliverables and two small supporting files were
created under the initially absent authorized root. The future launcher is a
deliberately fail-closed contract, not a functioning submission adapter.
Execution/security/performance evidence: NONE / NOT_VERIFIED.

## B. EXACT_G1_AUTHORIZATION_EVIDENCE

The operator's accompanying chat message contains exactly:

> AUTORIZO G1 — STAGE 03B CORE-PREP, SOMENTE CRIACAO DE ARQUIVOS NA NOVA RAIZ.

It also explicitly forbids Python, servers, dependencies, GPU jobs and advance
approvals and requires preservation of existing environments. The attached
contract is supporting scope, not an independent execution authorization.

Read-only input identity (SHA256 of actual files):

| Input | SHA256 |
| --- | --- |
| D:\What Lies Btwn\WLB_PRODUCTION_OS_STAGE03B_CORE_PREP_v0.1.txt | 495cb933e2c66613b08978740b211fc8eb9882c5e3430b1cdc4c6cf31d616cf5 |
| D:\What Lies Btwn\WHAT_LIES_BTWN_STAGE03A_PRODUCTION_OS_FOUNDATION_DESIGN_v0.1.txt | f7ff595ac7292030b162e13cc7b3aa6db560965b626f2e6100371ebdf8e7df3c |
| C:\Users\user\.codex\attachments\89d4ccad-39e1-4c9a-846b-fc30c803dac6\Texto colado.txt | c77e83d38c2034fbe4feb25910cc179ed955d1242867cb529b398855514abdfd |

Requested GPT-6.1 Sol / High is recorded as requested configuration only.
Actual session model/settings were not exposed or changed by preparation tools;
active-setting verification remains NOT_VERIFIED.

## C. CREATED_FILES_AND_SHA256

EVIDENCE: raw-file SHA256 computed after creation. No hash is invented or derived
from a presumed clean Git revision. The manifest binds graph, policy, runtime
lock and Bible hashes; the runtime lock binds nine prepared implementation/spec
artifacts. Direct read-only recomputation found zero binding mismatches.

| Absolute path | Bytes | SHA256 |
| --- | ---: | --- |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\core\Invoke-WlbJob.ps1 | 3185 | 2278e14b700fe722c5ca6d7e2d6e2245c3b88b1288fdee006da2cdd415a5fe66 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\core\Test-WlbManifest.ps1 | 5547 | 960c8985a19c161e1a225faa59510ec655c6b53c066a0c7cf7574fedd4e668b3 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\core\Test-WlbOutput.ps1 | 3661 | 283718ce05f5caaaefbf5ef6bb2ee070ee5b0bc92d91f2a65c0ccee6ef7a6768 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\core\Wlb.Common.ps1 | 5376 | 4af7db578950a266dffc8ae8b2fb9f188cd26ed2d8133fa3c8b9d4bdbb57b7e1 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\policy\shot-manifest.schema.json | 8781 | 5516147b01714d4bebe49036147de104ee9268995434cec27baac57882ed5e84 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\policy\executor-policy.json | 4191 | 2782c8aed1b02b959b6efb13eb4244a7e871d3bb8b279c554a0ddbceb22baf31 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\policy\runtime-lock.json | 3049 | 43c0643240753edf5709d480226317cacdcd287605a32ef22ce17b0c720ee5b5 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\workflows\draft\poc0-calibration.api.json | 311 | 0f9f407cf4aef2bb98aea9f44603521eec38558b986ed09e535c1259d6ae3a1e |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\manifests\draft\POC0-CALIBRATION-001.json | 4514 | 2b6cde0ef8db97cc42fc808d307d24004714f6cc81e009fa8a11e003a6c3bf31 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\bible\character-bible.v0.1.json | 1424 | 08e216196d54297bc1868fbabdfac69305b77aa7eedd64715706ee829e0a70f8 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\README.md | 5185 | 2fb547300d35053cfaad9f113534c6c9dd2dcf33d47fc52f52b8b110df6d3712 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\spec\FUTURE_EXECUTION_CONTRACT.md | 6282 | b1f4712b9fac09a52aa8e8ab2698a7caaf2aff9ccdf950705ff3b5cef404e598 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\STAGE03B_PREP_RECEIPT.md | Computed after creation | Provided in final conversation after write; intentionally not self-embedded |

Support files: Wlb.Common.ps1 consolidates path/link/JSON guards; the spec makes
unimplemented authority and negative-test contracts explicit. No other supporting
fixture is created. This receipt is the thirteenth file. Self-hashing is excluded
from its own contents to avoid a circular hash; its external hash is delivered
in the final conversation.

## D. ORIGIN_READ_ONLY_AND_ISOLATION_ATTESTATION

EVIDENCE: initial root check returned TARGET_ROOT_ABSENT. No pre-existing content
was overwritten or merged. All writes were scoped to this new root. No existing
Comfy or Python files were opened as runtime, copied, changed or launched in G1.
No LTX Desktop runtime path was used. MIRAE/PULSE were not read or touched.

DESIGN decision: defer the optional code snapshot rather than perform an
unbounded recursive copy. runtime-lock has snapshot_created=false, empty copy
inventory and null snapshot fingerprint. Historical source Git SHA is recorded
separately from that missing local-source identity. No clean-worktree assertion.

No ACL/firewall/global environment/service/Git changes. OS-level isolation and
production-directory byte-for-byte comparison are NOT_VERIFIED; preservation
attestation describes the operations performed, not unrelated host activity.

## E. POC0_GRAPH_AND_MANIFEST_STATIC_REVIEW

EVIDENCE from textual review: exactly two graph nodes, EmptyImage -> SaveImage;
width=640, height=360, batch=1, color=3368601 (0x336699), fixed save prefix.
Manifest DRAFT, no approval_id, approval record_created=false; model, source asset
and reference lists empty. Prompt/negative/seed/fps/audio are typed null with N/A
reasons. Source-assets licensing N/A is limited to synthetic calibration.
Owner identity, CPU budget and character asset rights remain UNKNOWN; runtime,
device, observed resource usage and performance remain NOT_VERIFIED/NOT_EXECUTED.

EVIDENCE: six JSON files parsed as text. Four PowerShell files were inspected
by the host PowerShell AST parser, returning zero syntax diagnostics, without
invoking those files. This is syntax evidence only: no schema-validator execution,
PowerShell helper execution, C# compilation, API request or runtime proof.

Pre-receipt inventory: 12 files, 8 subdirectories, 51,506 bytes; no missing or
unexpected file, reparse point or binding mismatch. Paths approvals, jobs,
workflows\approved and runtimes were absent. Only core, policy, Bible, draft
manifest/workflow, spec and root documentation directories were necessary.

Preparation incident: the initial exclusive manifest write failed because
manifests\draft did not yet exist. No manifest or partial manifest was produced.
The missing draft path/file was then deliberately created inside the authorized
root; existing prepared artifacts were preserved. This was a preparation-path
correction, not an execution retry. Final read-only inspection confirmed the
manifest exists and its bindings match the already-written artifacts.

## F. SECURITY_LIMITATIONS_AND_OPEN_ITEMS

DESIGN/source, NOT_VERIFIED: static validator and helper contain containment,
traversal/alternate-stream/reparse/hardlink rejection and JSON key guards.
They do not constitute a tested OS sandbox or a live TOCTOU boundary.

NOT_IMPLEMENTED blockers in launcher: atomic consume-before-submit; immutable
submitted bytes; owned engine lock/process identity; live preflight; budget
watchdog and polling/telemetry policy; REST submit/cancel; crash/timeout history
reconciliation. Launcher always refuses, even with an approval. No approved
record can be generated or consumed by this version.

NOT_VERIFIED: Windows ownership/ACL boundary; PowerShell 7.4+ availability as a
future invocation dependency; native link helper compilation; Comfy snapshot,
runtime compatibility, CUDA device and resource peaks. Missing prerequisites
do not authorize installation or repair of production.

Offline/loopback/provider denial is application policy, not general Python
egress enforcement. Same-account Python is not strong isolation. Untrusted
custom nodes and import/startup effects remain code-execution boundaries.

QC checker covers file hash and PNG header only. Full PNG CRC/decode, all-pixel
RGB check, authenticated GPU/resource evidence and independent human verdict
remain pending. The checker always reports accepted=false.

## G. TESTS_NOT_RUN_AND_GATES_STILL_CLOSED

NOT_RUN: prepared scripts, schema validator, negative fixtures, link helper,
mock server, runtime imports, Python, Comfy startup, GPU execution and output QC.
NOT_VERIFIED: actual runtime functioning, resource budgets, approval atomicity,
GPU exclusivity, cancellation and security boundary enforcement.

G2 host modifications, G3 installations, G4 startup/imports, G5 one GPU job,
workflow promotion, release and Alpha preparation/inference remain closed.
No approvals, jobs, outputs, server calls, external network API calls, downloads,
models, credits or commits were created/performed in G1.

## H. NEXT_GATE_PROPOSAL

DESIGN: separately authorize Stage 03C static/negative tests of these prepared
PowerShell artifacts and new-root fixtures, without Python/Comfy/network/GPU.
Review placeholders and implement the bounded adapter only in an explicitly
approved scope. Authorize snapshot/runtime preparation separately. Then require
distinct G4 startup/import authorization and distinct G5 one-manifest GPU
authorization. Approval of this receipt alone opens none of those gates.

## I. NO_MUTATION_OUTSIDE_NEW_ROOT_ATTESTATION

EVIDENCE about agent operations: created source/doc/JSON files only beneath the
new root; read the attached contract and input hashes; inspected new-root text,
inventory and hashes using OS-native commands. No Python, new-script invocation,
C# helper compilation, server, API/network call, dependency installation, GPU
job, source copy, global environment change, process intervention or Git write.
The host and already-running applications may independently change their state.

## J. WAITING_HUMAN_REVIEW

CORE_PREP_COMPLETE_WITH_LIMITATIONS. No future gate is authorized.
WAITING_HUMAN_REVIEW.
