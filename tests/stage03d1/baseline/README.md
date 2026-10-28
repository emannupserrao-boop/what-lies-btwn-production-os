# WHAT LIES BTWN — Production OS / Stage 03B CORE-PREP v0.1

**G1 only. Prepared source, NOT_EXECUTED. WAITING_HUMAN_REVIEW.**

Operator authorization received verbatim:

> AUTORIZO G1 — STAGE 03B CORE-PREP, SOMENTE CRIACAO DE ARQUIVOS NA NOVA RAIZ.

Authority is limited to creation and read-only verification under
`D:\WHAT-LIES-BTWN-PRODUCTION-OS`. No other gate is approved.

## Reviewable deliverables

The closed draft POC is `EmptyImage -> SaveImage`, 640x360, batch 1,
RGB 0x336699, one PNG, no model, audio, source input, sampler or provider.
Prompt, negative prompt, seed and FPS are typed null with N/A reasons.
No approval, approved workflow, runtime output or job receipt exists.

`Test-WlbManifest.ps1` contains future strict schema/binding/graph/path checks.
`Wlb.Common.ps1` contains future duplicate JSON key and Windows reparse/hardlink
checks. `Test-WlbOutput.ps1` contains future hash/PNG-header checks only.
`Invoke-WlbJob.ps1` is a fail-closed launcher contract: even a supplied valid
approval cannot trigger submission. No HTTP or process-start implementation
exists. This limitation is intentional and described in
`spec/FUTURE_EXECUTION_CONTRACT.md`; it must not be represented as a working
one-shot executor.

## Evidence and provenance

Stage 02 is the technical baseline; Stage 03A is the accepted design. Contract
and baseline SHA256 values are recorded in the prep receipt and runtime lock.
Hashes cover actual raw on-disk bytes; no hash is a runtime success attestation.
The runtime lock fingerprints prepared source artifacts, not a Comfy snapshot.
Existing Comfy code/venv and LTX Desktop were neither copied nor modified.
No source snapshot exists; its inventory/hash is null with a stated reason.
The origin Git revision is historical baseline evidence, not evidence of a
clean local worktree. Python facts are historical, not fresh runtime probes.

## Future prerequisites — no invocation is authorized here

PowerShell 7.4+ is the source requirement for these future scripts; availability
is NOT_VERIFIED and no installation is authorized. The helper uses .NET JSON
parsing and, when later invoked, Add-Type for a fixed Windows read-only
file-handle link-count query. This helper code has not been compiled or run.

The existing Comfy Python is only a future candidate. Python, imports, servers,
network calls, model acquisition and GPU jobs remain forbidden in this gate.
All scripts/tests are NOT_RUN; security/runtime validation is NOT_VERIFIED.

G1 policy deliberately has execution_enabled=false and the draft schema is
POC-specific. Promoting DRAFT or turning policy true is insufficient to execute:
the launcher still refuses. A later reviewed revision must implement atomic
approval consumption, immutable submission bytes, engine lock, trusted live
resource monitor, scoped submit/cancel and crash reconciliation, and receive
new hashes/approvals. Independent decoded-pixel QC is also pending.

## Resource policy, not performance evidence

Future preflight: available RAM >=8 GiB, commit headroom >=10 GiB, no LTX/heavy
render or foreign GPU job. Abort gates: incremental commit <=4 GiB, process
private bytes <=4 GiB, incremental VRAM <=2 GiB, startup <=120 s, job <=30 s,
output/log <=256 MiB. CPU cap and monitor sampling cadence remain UNKNOWN.
Missing measurements or essential fields block execution; no automatic retries
or budget increases. GPU device selection and all observed peaks are
NOT_VERIFIED. The existing 640x360 float32 tensor calculation (~2.64 MiB) does
not estimate full Comfy startup memory.

## Trust and privacy

Future endpoint fixed to 127.0.0.1:8189. Provider/partner/custom nodes, Manager,
API credits, downloads, arbitrary shell/URLs/scripts and production intervention
are denied by policy. Offline is not Python egress enforcement. These declarations
are not a tested OS sandbox; same-account Python has broad host access. No ACL,
identity, firewall or global environment changes were made. Custom-node startup
and code imports remain separate execution trust boundaries.

Human owner identity, asset rights, licensing entity/revenue and references are
not supplied or inferred. Synthetic POC uses no external asset/model license.
Alpha Gen remains deferred and NO_GO; no Alpha installation/model is prepared.

## Next gates

Propose a separately authorized Stage 03C static/negative-test scope under this
root. It must explicitly allow invocation of prepared PowerShell validators and
fixture creation; it does not include Python, Comfy, network or GPU. Then require
distinct G4 startup/import authorization after runtime/snapshot preparation,
and distinct G5 authorization for one reviewed GPU manifest. Any installation,
host isolation change, snapshot creation or workflow promotion requires its own
explicit scope. No Git init, commit, service or scheduled task is part of G1.

## Rollback

Nothing in production needs restoration. Retain preparation/evidence. Future
cleanup requires human authorization, absolute-path/root checks and no traversal
through reparse points. This version never deletes files or evidence, consumes
approvals, launches processes or terminates production processes.
