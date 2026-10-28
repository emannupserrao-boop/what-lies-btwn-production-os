# STAGE03D2_IMPLEMENTATION_RECEIPT

## A. STAGE03D2_STATUS

COMPLETE_WITH_LIMITATIONS. Controlled source implementation and mock/fixture tests delivered. G2, G3, G4, G5 and ALPHA remain closed. PREPARED describes source contracts, NOT_VERIFIED describes live capability, WAITING_HUMAN describes consent/parameters, and BLOCKED is actual admission. FUTURE_G4_ELIGIBLE exists only as a tested future-review decision; authorized_to_execute remains false.

## B. VERIFIED_STAGE03D1_BASELINE

Before editing, 2146 hash-bearing prior inventory entries verified with zero divergence; 2148 existing files independently recorded, including two prior inventory self-metadata exclusions. Stage03D1 receipt SHA-256: 0ee20d032ee427e771f1fe011118f4d4dd8a1a9f318f641a6e710da9e88e3078. Authoritative D1 results: 693 static PASS, with operational statuses retained. Mandatory receipts/reports/matrix and canonical files were read. Baseline copies and all-existing-before.json preserve original bytes/hashes. Final audit compares all 2148 existing files and permits exactly the four changes in C. Historical Stage03C/03D1 reports, evidence and test fixtures are byte-identical.

## C. EXACT_CHANGESET_AND_HASHES

| Existing file | Before SHA-256 | After SHA-256 | Justification |
|---|---|---|---|
| core\Test-WlbManifest.ps1 | 0cee15697d17b2a9e43a4fb91f042bd7646844c020a038b1834a75a390867509 | ec559370f75d541f66455187f4cae75b02297f3305da90df8e0707390076949f | Amplia somente a lista exata de artefatos preparados de 9 para 17; preserva validação estrita D1. |
| manifests\draft\POC0-CALIBRATION-001.json | 86c76c58eba4fc80a1398dcf51f1c3ede9823242e72473601a4ba8073b1ae6f1 | 349503c85cde19f23558f4dcecdaf4192dfea9cef52e19aa264cdf36fe5eeebb | Atualiza exclusivamente runtime_sha256; DRAFT e bloqueios preservados. |
| policy\runtime-lock.json | b8d3d5034191a02df4a0003eb2533aa8b86535c65cbfe5951902862b46810ce6 | 2cba41ae01245961e941edb9d1f5ce016b773d6a7d99236d5e71c1b2f4727a98 | Inclui 8 artefatos de preparação e atualiza SHA-256 legítimos; mantém G1_ONLY, snapshot ausente e nenhuma autoridade. |
| spec\FUTURE_EXECUTION_CONTRACT.md | b1f4712b9fac09a52aa8e8ab2698a7caaf2aff9ccdf950705ff3b5cef404e598 | 61b8642bf7c8fd3b6cf442cf18d33ca3a8a2fd7ed3fca42ba6a78797e67c6acc | Acrescenta limites e estados da preparação D2; não autoriza G4/G5. |

| New canonical artifact | Before | After SHA-256 |
|---|---|---|
| core\Start-WlbRuntime.ps1 | ABSENT | 3ed6a6cea5f1602bc47f95ffc4b031a102b12f9fdfe3f204b259ff9dfc6b9e26 |
| core\Wlb.RuntimeMonitor.ps1 | ABSENT | b2d68365699194ec2c0db37529d644006d167cc3918f659d0f3a9688b5aaeb1e |
| core\Wlb.Startup.ps1 | ABSENT | 1fffe9825cb7d7044e4e8e0dd2431aa9df559fec450c356e69538859cdd3825d |
| core\Wlb.StartupFiles.ps1 | ABSENT | a0f31be7e5b1920f95a14c64f419639312055edc9961d1cf62d4504b6f01dcdd |
| policy\startup-identity.json | ABSENT | 7f42355c74483f6965f6eb6e837b5ac09d71485fcde610882bc627c3dd420edb |
| policy\startup-policy.json | ABSENT | e1db244a744f6ee228956d7fdd199c89737822299bab7785b58ba8c9e527795f |
| spec\G4_DEPENDENCY_METADATA.json | ABSENT | 97710ef8f044f13c1eb2c570ba188a697ce301c17aa871ef573a0afbbaabe901 |
| spec\G4_SNAPSHOT_COPY_INVENTORY.csv | ABSENT | a8e69c205a7f98a1aa3bb34d399201a61e76c112c233f7202abc8b25ba2941eb |

Other new files are only D2 tests, baseline copies, fixtures, inventories and reports. Exact all-new path/size/hash ledger: tests/stage03d2/evidence/new-files-inventory.csv. Its self-hash is intentionally excluded from its own rows and recorded in delivery-integrity.json. Tests/reports are evidence, not runtime authority. Only prepared_artifacts changed semantically in runtime-lock; historical source-read/native-helper metadata describes the earlier G1 preparation and is retained. D2 observations are in startup-identity and this receipt. Manifest byte comparison proves only the runtime hash changed. The 17 bindings and both identity metadata references match current files. SHA-256 updates do not promote, approve or authorize anything.

## D. STARTUP_ONLY_DESIGN_AND_IMPLEMENTATION

core/Start-WlbRuntime.ps1 accepts only Plan or Admission. Plan runs strict canonical validation and produces fixed metadata; Admission unconditionally refuses actual startup. No shell fragments, arbitrary paths, URLs, Python CLI, approval or callback are accepted by the entry point. The existing job launcher is byte-identical and disabled. New modules expose static/injected evaluation; there is no real process-start, process-stop, REST or approval adapter.

Fixed future candidate: main runtimes/core/ComfyUI/main.py; working directory runtimes/core; 127.0.0.1:8189; base/input/output/user under runtimes/core/state; temp under scratch/temp; caches under state/cache. The one historical external Python candidate is fingerprinted metadata only, never launched. CLI and process-local environment dictionary are visible in policy/startup-identity.json and Plan evidence; neither is applied. Flags disable custom nodes/partner nodes and intentional provider use, set offline/no auto-launch/no metadata/no bytecode/cache-none/gpu-only. Source flags are checked statically; offline/loopback do not prove egress blocking. Missing snapshot, consent, dependency identity, human parameters and monitor prevent admission.

## E. PROCESS_OWNERSHIP_AND_LOCK_EVIDENCE

Owned-process evaluation requires exact typed PID, creation UTC timestamp, executable path/hash and per-attempt owner token. Port ownership requires known fixed address/port and matching full tuple. These observations are injected; live observation remains NOT_VERIFIED. PID mismatch/reuse/unknown/foreign ownership refuse admission and cannot authorize StopMock. Watchdog checks ownership on every tick and immediately before an authorized owned mock stop. The mock consent is explicitly MOCK_ONLY/G4_STARTUP_ONLY; no real consent file was created or consumed.

Real harmless test mechanics use one named Local mutex derived from root/fixed engine/test identity across different attempt namespaces, nonblocking acquisition, CreateNew persistent reservation and no implicit retry. Concurrent attempts and concurrent file creators were exercised with runspaces. Releasing the test mutex retains the reservation; interrupted/replayed namespace is refused. Abandoned mutex branch fails closed but an actual abandoned-kernel event is NOT_TESTED. Test mutex is not a real runtime engine lock or cross-session security boundary. Actual process termination was never attempted.

## F. RESOURCE_MONITORING_TEST_RESULTS

Injected providers and monotonic clocks exercise missing/stale/future/clock-reversed samples, invalid types, provider failures, ownership loss, deadline and resource thresholds. Limits unchanged: RAM minimum 8 GiB; commit headroom minimum 10 GiB; incremental commit maximum 4 GiB; own private bytes maximum 4 GiB; incremental VRAM maximum 2 GiB; startup 120 seconds; future job 30 seconds; aggregate output/log/temp 256 MiB. Exact resource boundaries are tested; startup aborts at its deadline. Heavy process/foreign GPU activity, untrusted attribution or negative/reversed counters block. CPU/cadence/freshness operational fields remain UNKNOWN. The bounded injected watchdog has no live polling/sleep/start adapter and no automatic retry. Thresholds request monitoring/abort; they are not guaranteed hard caps. RAM/commit/private/VRAM attribution/disk live adapters remain NOT_VERIFIED.

## G. FILESYSTEM_AND_TRUST_BOUNDARIES

Actual file operations are confined to tests/stage03d2, bounded to 1 MiB, CreateNew/no overwrite, exclusive writer, Flush(true), same-handle bytes/hash/identity and one hardlink. Parent handles are held with no delete sharing; canonical paths, volume/file identities and reparse/link checks are repeated around use. Parent-swap was blocked by held handles; replacement/hash change/traversal/outside paths/incomplete writes/recovery were tested. Incomplete evidence and persistent reservation remain; no cleanup grants permission or retry. Power-loss durability and a full hostile filesystem race campaign are NOT_TESTED.

SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0 is the already accepted boundary. No strong operator/executor isolation, filesystem sandbox, egress block, independent authentication or creative-agent execution authority is claimed. Same-account users able to edit code/policy can bypass source checks; hashes/text identity are not independent authorization. Proposed cache paths/environment do not confine all third-party writes. Add-Type compiled only the fixed Windows file-handle helper in the PowerShell test process; no Python, installed package, server or host setting was involved.

## H. G4_SNAPSHOT_COPY_PROPOSAL

STAGE03D2_G4_SNAPSHOT_COPY_PROPOSAL.md and spec/G4_SNAPSHOT_COPY_INVENTORY.csv contain exact 619 source candidates, 9,533,695 measured bytes, origin/planned destination/per-file SHA-256 and group counts, inclusion/exclusions/license/dependency risk. Snapshot status NOT_CREATED, actual_inventory_sha256 null. No code copied into runtimes. Only explicit root files and .py/.pyi in bounded groups are candidates; code directories named models/input are source modules, not weights or user inputs. Root weights/custom nodes/API partners/.git/credentials/caches/user/input/output and non-code contents are excluded. Initial incomplete 615-file inventory was archived, not overwritten as history.

Inventory is a bounded candidate, not a certified runnable/import-complete snapshot. alembic.ini and other non-Python configuration/assets are excluded pending necessity and credential-free template review. GPLv3 root evidence is recorded; per-file exceptions/distribution rights are not independently certified. Python hash covers the 255200-byte venv entry executable only, not the underlying interpreter/stdlib/DLL tree. Sixteen distributions have METADATA/WHEEL/RECORD fingerprints only; hashing RECORD does not verify its listed binaries. All imports/native compatibility/startup side effects remain RUNTIME_NOT_VERIFIED. Source/entry/metadata fingerprints rechecked before delivery without executing/importing. Separate authorization is required before any snapshot preparation/copy.

## I. HUMAN_PARAMETERS_PENDING

STAGE03D2_HUMAN_PARAMETERS_PENDING.md specifies startup-policy.human_parameters.operator_identity, cpu_budget, polling_cadence_ms and telemetry_freshness_ms. All remain UNKNOWN/null and block real admission. Candidate current account/SID is read-only evidence, not confirmed operator identity. Conservative proposals: 250 ms cadence / 1000 ms freshness or 500 ms / 2000 ms; operational cost and timing require review. CPU proposal remains blocking until grounded measurements, or separate explicit authorization for supervised observation; no numeric CPU budget invented. Test values 100/500/OBSERVE_ONLY_TEST do not become policy. Explicit human authorization is required before future operational binding; that binding also needs a separately reviewed contract change. Supervised boundary is not asked again.

## J. REGRESSION_MATRIX

tests/stage03d2/evidence/REGRESSION_MATRIX.md and consolidated-results.json: 128 PASS rows, comprising 123 executed checks and 5 recorded-evidence rechecks. Suite counts: fresh run2 103; additional 7 (2 new concurrency checks + 5 recorded rechecks); final-file 5; final-contract 13. Initial run's 101 PASS / 2 FAIL is retained with causes/remediation; final suites have zero FAIL. Relevant D1 seven distinct failures and composites, extra nodes/providers, paths/state/hash divergence, original baseline and launcher block were rechecked. Final strict identity/policy and continuously lost ownership were targeted after final source changes. Historical 693 D1 PASS are baseline evidence, not 693 newly reexecuted D2 tests. PASS is scoped to static/mock/fixture expectations. The 24 original operational NOT_IMPLEMENTED controls have not been relabeled PASS.

## K. REMAINING_G4_BLOCKERS

Separate human scope for snapshot preparation; reviewed import/config/license closure; actual snapshot fingerprint; Python interpreter/stdlib/native dependency identity and compatibility; trusted human startup-specific consent and conservative single-attempt protocol; explicit human parameter authorization; real process/port ownership observation; operational resource telemetry including reliable GPU attribution; actual owned-process start/stop and interruption/reconciliation adapters; real preflight concurrency/lock binding; live watchdog feasibility. Each requires future authorization/validation. Actual abandoned mutex/power-loss behavior remains untested. Native server/job API behavior and same-account access must be accepted within the supervised model; CLI flags do not provide REST/egress isolation. G4 stays BLOCKED.

## L. REMAINING_G5_BLOCKERS

G4 has not occurred. Real job approval/authentication, atomic single-use consumption, approval replay protection, real engine submission/ownership, HTTP dispatch, runtime cancellation, GPU attribution/job concurrency, 30-second live deadline, output integrity and executable snapshot/runtime validation remain absent or unverified. Launcher execution_enabled=false and DRAFT manifest continue to block all render/GPU jobs. No Alpha Gen/MCP work was started.

## M. NO_OUT_OF_SCOPE_MUTATION_ATTESTATION

Authorized writes are exactly four existing Production OS files plus new D2 source/contracts/tests/reports/fixtures. All other 2144 prior files, including Stage03C/03D1 evidence, retain SHA-256. External ComfyUI source, Python entry and dependency metadata were only read/hashed and rechecked unchanged. No snapshot/source copy, Python/import/CUDA, server, live process kill, network/REST/job, GPU generation, real approval, dependency install, venv/production modification, ACL/firewall/registry/global environment change or Git commit/merge/push/tag. No MIRAE/PULSE/LTX Desktop mutation. This attests this task's observed commands and audited files, not an omniscient host-wide mutation proof; external source verification is limited to inspected inventory/entry/metadata files. New artifacts and command ledger are provided for review.

## N. NEXT_GATE

WAITING_HUMAN_REVIEW. STOP_AFTER_DELIVERY. No snapshot preparation, G4, G5, Alpha Gen or MCP proceeds automatically. Preparation is not approval or promotion.