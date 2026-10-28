# Future execution contract — BLOCKED / NOT_IMPLEMENTED

This is an inspectable specification, not an executable adapter or approval.
G1 permits preparation only. All new scripts remain NOT_RUN.

## Implemented source versus unresolved execution

Prepared: strict manifest schema; fixed POC graph; hashing and binding checks;
path containment, reparse and hardlink rejection source; duplicate JSON key
rejection source; a read-only PNG header/hash checker; and a launcher that
unconditionally refuses submission. None has been executed or tested.

Not implemented: Comfy snapshot; process launch; REST submission; approval
consumption; resource monitor; cross-process engine lock; cancellation;
reconciliation; decoded PNG color/integrity; evidence authentication.
There is deliberately no reachable POST /prompt in G1.

## Required one-shot algorithm for a later separately authorized revision

1. Operator provisions approved code/runtime and an OS boundary or explicitly
   accepts supervised same-account limitations. Rehash scripts, policy, graph,
   schema and runtime lock; issue new manifest bindings. No clean worktree claim
   may be inferred from source Git SHA.
2. Acquire a fail-closed engine mutex and a CreateNew reservation beneath the
   owned job namespace. Bind the dedicated engine PID, process creation time,
   executable identity, port and job ID. Do not attach to arbitrary listeners.
3. Read only operator-issued approval: approval_id UUID, job_id, manifest,
   graph, policy and runtime-lock SHA256, scope ONE_GPU_JOB_ONLY, status UNUSED,
   approved_by, exact UTC expiry. An approval file under the same user is not
   authenticated human evidence by itself. Protect ownership with a separately
   authorized access-control boundary; no approval creation by creative agents.
4. Validate all essential fields, fixed node keys/links/parameters and paths.
   Keep handles/immutable snapshots for bytes actually submitted; a hash then
   close then reread sequence is not a TOCTOU defense. Reject reparse points,
   link count >1, alternate streams, traversal, pre-existing destinations and
   parent mutations. Use CreateNew for all evidence files. Any inability to prove
   the path boundary is BLOCKED.
5. Collect immediately current RAM >=8 GiB and commit headroom >=10 GiB;
   verify no LTX/heavy render/foreign engine job active. Never auto-kill them.
   A mutex cannot prevent unrelated applications using the GPU.
6. Start only a pinned dedicated Comfy process when G4 is approved. Fixed CLI,
   no Manager, all custom nodes disabled, offline; all state/cache/temp paths
   under root. No claims that offline means Python egress isolation. Refuse
   unreviewed import/startup side effects. Startup deadline 120 s.
7. Establish pre-start commit/VRAM baseline, process identity and telemetry.
   Monitor across startup and job: commit delta <=4 GiB, private bytes <=4 GiB,
   VRAM delta <=2 GiB, output+logs <=256 MiB, commit headroom >=10 GiB and
   available RAM >=8 GiB. Missing/stale/unattributable telemetry BLOCKS; no
   automatic cap changes. GPU job deadline 30 s. Measurements and polling
   latency are not hard memory allocator limits; define maximum data age and
   cancellation escalation before enabling execution.
8. Atomically claim the approval before submission: rename the UNUSED approval
   to a same-volume consumed/reserved namespace with no overwrite and durable
   reservation, under engine lock. Define crash recovery and fsync semantics
   in tested Windows implementation. A consumed approval is never made UNUSED
   automatically, including a crash before POST. Preserve original evidence.
9. Send exactly one POST /prompt to http://127.0.0.1:8189, with fixed graph,
   bounded HTTP timeout and stable client/job ID. No retries, redirects, proxy,
   arbitrary URLs, script args, upload, provider node or command fragment.
   POST validates AND queues; never use it for an unapproved dry-run.
10. Persist prompt_id using exclusive temp write, flush, close and rename without
    overwrite. HTTP timeout, crash or lost response means BLOCKED_UNCERTAIN.
    Reconcile with owned-engine history/queue and job/client ID. Do not POST
    again to discover whether the first submission succeeded.
11. Cancel queued work only by exact owned prompt_id. Interrupt the dedicated
    instance only after proving sole owned running job; never global production
    interrupt. Escalation may terminate only PID+creation-time+image identity
    launched by this executor under its separately approved lifecycle authority.
    Never kill by generic python.exe name. Preserve evidence on abort.
12. Quarantine only within that owned job namespace; never delete evidence.
    Human approves any cleanup. No service, daemon, scheduled task or auto-retry.

## Future QC acceptance

Require exactly one native PNG, SHA256 receipt bindings, 640x360, RGB 8-bit,
decoded pixel color 0x336699, no extra frames/audio/models, one prompt_id,
authenticated GPU/device and budget evidence, and human verdict. Current checker
examines hash/header only and always returns accepted=false. PNG CRC, complete
decode, every-pixel comparison and independent artifact review remain pending.

## Stage 03C negative test specification — NOT_RUN

No Python, Comfy, GPU, network, mock REST server or installations in this scope.
Test helper/validator scripts only if separately authorized, using isolated
new-root fixtures and preserved evidence. Any helper runtime requirement missing
(including PowerShell 7.4+) is BLOCKED, not permission to install.

Cases: baseline DRAFT; changed graph/manifest/policy/runtime/core hash; missing
required field; extra key; duplicate and case-colliding JSON keys; UNKNOWN
essential data; malformed typed N/A; provider, disconnected extra node or
unexpected link; traversal/UNC/alternate stream; junction/symlink/hardlink;
existing output; cap increase; wrong/expired/replayed approval; supplied approval
still refuses launch. The launcher must refuse without any write/network/process
side effect. Test parser diagnostics separately. Future atomicity/watchdog/lock
tests require their implementation and a specifically approved local test scope.

G4 startup/import tests and G5 one GPU job remain separate, later human gates.

## Stage03D2 — startup preparation revision, no G4 authority

The later operator-authorized preparation scope selects
SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0. This accepts supervised same-account
limitations only for the synthetic model-free POC; no OS filesystem sandbox,
egress enforcement or independently authenticated textual identity is claimed.

Start-WlbRuntime.ps1 exposes Plan/Admission only, with no arbitrary command,
URL, Python argument/path, consent creation, process launch/kill or HTTP adapter.
Wlb.Startup.ps1 provides fixed plan and pure admission/process/port decisions.
Wlb.RuntimeMonitor.ps1 evaluates injected counters/clocks and invokes only
test-owned stop callbacks after exact ownership/consent checks. Live process,
port and telemetry acquisition remain NOT_VERIFIED or disabled. A mock
FUTURE_G4_ELIGIBLE result means reviewability, never execution authority.

Wlb.StartupFiles.ps1 tests actual named mutex and persistent CreateNew/flush
operations only in Stage03D2 fixture namespaces, with held parent handles,
handle identity and pinned-byte checks. It cannot create real startup approvals
or runtime state through those interfaces. Partial writes/reservations are
retained and block automatic restart; machine-power-loss durability and a
malicious same-account code/policy writer are outside any proved guarantee.

startup-policy.json keeps real startup/jobs/retries disabled, consent ABSENT
and operator identity/CPU/cadence/freshness UNKNOWN. startup-identity.json and
spec/G4_SNAPSHOT_COPY_INVENTORY.csv identify static candidates only; no Comfy
snapshot has been copied and no Python import/execution has occurred. Dependency
METADATA/WHEEL/RECORD fingerprints are not proof of installed binary identity
or runtime compatibility. Separate snapshot approval, parameter decisions,
live monitor/owned adapters and specific human G4 consent remain prerequisites.
