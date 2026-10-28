#requires -Version 7.6
# Read-only audit of canonical/source files; writes only this stage's reports/evidence.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$Evidence=Join-Path $Root 'tests\stage03d2\evidence'
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Json([string]$Path){ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($Path)) -AsHashtable -DateKind String}
function WriteText([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
$before=Json (Join-Path $Evidence 'all-existing-before.json')
$reasons=@{
 'core\Test-WlbManifest.ps1'='Amplia somente a lista exata de artefatos preparados de 9 para 17; preserva validação estrita D1.'
 'policy\runtime-lock.json'='Inclui 8 artefatos de preparação e atualiza SHA-256 legítimos; mantém G1_ONLY, snapshot ausente e nenhuma autoridade.'
 'manifests\draft\POC0-CALIBRATION-001.json'='Atualiza exclusivamente runtime_sha256; DRAFT e bloqueios preservados.'
 'spec\FUTURE_EXECUTION_CONTRACT.md'='Acrescenta limites e estados da preparação D2; não autoriza G4/G5.'
}
$changed=@();$unchanged=0
foreach($item in $before){
 $path=Join-Path $Root $item.path
 if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "Preexisting file missing: $($item.path)"}
 $hash=Hash $path
 if($hash -cne $item.sha256){
  if(-not $reasons.ContainsKey($item.path)){throw "Out-of-scope preexisting change: $($item.path)"}
  $changed+= [pscustomobject]@{path=$item.path;before_sha256=$item.sha256;after_sha256=$hash;reason=$reasons[$item.path]}
 }else{$unchanged++}
}
if($changed.Count -ne 4){throw 'Expected exactly four preexisting changes'}
$lock=Json (Join-Path $Root 'policy\runtime-lock.json')
$oldLock=Json (Join-Path $Root 'tests\stage03d2\baseline\policy\runtime-lock.json')
$lockNoBindings=$lock.Clone();$null=$lockNoBindings.Remove('prepared_artifacts')
$oldNoBindings=$oldLock.Clone();$null=$oldNoBindings.Remove('prepared_artifacts')
if((ConvertTo-Json $lockNoBindings -Depth 40 -Compress) -cne (ConvertTo-Json $oldNoBindings -Depth 40 -Compress)){throw 'Historical lock metadata changed'}
$bindings=@();foreach($key in $lock.prepared_artifacts.Keys){$actual=Hash (Join-Path $Root $key);if($actual -cne $lock.prepared_artifacts[$key]){throw "Bad artifact binding: $key"};$bindings+=[pscustomobject]@{path=$key;sha256=$actual}}
if($bindings.Count -ne 17){throw 'Expected 17 artifact bindings'}
$oldManifest=[IO.File]::ReadAllText((Join-Path $Root 'tests\stage03d2\baseline\manifests\draft\POC0-CALIBRATION-001.json'))
$newManifest=[IO.File]::ReadAllText((Join-Path $Root 'manifests\draft\POC0-CALIBRATION-001.json'))
$oldHash=Hash (Join-Path $Root 'tests\stage03d2\baseline\policy\runtime-lock.json')
$lockHash=Hash (Join-Path $Root 'policy\runtime-lock.json')
if($oldManifest.Replace($oldHash,$lockHash) -cne $newManifest){throw 'Manifest contains change beyond runtime binding'}
$identity=Json (Join-Path $Root 'policy\startup-identity.json')
if((Hash $identity.snapshot.proposal_inventory) -cne $identity.snapshot.proposal_sha256 -or (Hash $identity.dependencies.metadata_path) -cne $identity.dependencies.metadata_sha256){throw 'Identity references diverge'}
$sourceRows=@(Import-Csv -LiteralPath $identity.snapshot.proposal_inventory)
foreach($row in $sourceRows){if((Hash $row.source) -cne $row.sha256){throw "Source changed: $($row.source)"};if(Test-Path -LiteralPath $row.planned_destination){throw 'Snapshot destination unexpectedly exists'}}
$dependencies=Json $identity.dependencies.metadata_path
$metadataCount=0;foreach($dependency in $dependencies){foreach($item in $dependency.metadata){if((Hash $item.path) -cne $item.sha256){throw "Dependency metadata changed: $($item.path)"};$metadataCount++}}
if((Hash $identity.python.path) -cne $identity.python.sha256 -or (Hash $identity.cli_source_evidence.path) -cne $identity.cli_source_evidence.sha256){throw 'Python entry/CLI source fingerprint changed'}
$suites=@(
 @{name='run2';path='run2\test-results.json'},
 @{name='additional';path='additional-results.json'},
 @{name='final-file';path='final-file-results.json'},
 @{name='final-contract';path='final-contract-results.json'}
)
$rows=@();foreach($suite in $suites){foreach($row in (Json (Join-Path $Evidence $suite.path))){$row.suite=$suite.name;$rows+=$row}}
if($rows.Count -ne 128 -or @($rows | Where-Object {$_.status -cne 'PASS'}).Count){throw 'Final test ledger not 128 PASS'}
$rechecks=@($rows | Where-Object {$_.evidence_kind -like 'RECHECK*'}).Count
if($rechecks -ne 5){throw 'Recorded recheck count differs'}
$matrix=@('# STAGE03D2 REGRESSION_MATRIX','', 'Final: 128 PASS rows = 123 checks executed + 5 recorded-evidence rechecks. PASS applies only to the stated static/mock/fixture expectation, never to real runtime capability.', '', '| Suite | ID | Result | Evidence kind | Expected behavior |','|---|---|---|---|---|')
foreach($row in $rows){$matrix+='| '+$row.suite+' | '+$row.id+' | '+$row.status+' | '+$row.evidence_kind+' | '+($row.expectation -replace '\|','/')+' |'}
$matrix+=@('', 'Initial run retained: 101 PASS / 2 FAIL; failures were harness datetime coercion and a directory handle that did not prevent parent rename. Final source uses typed tuple cloning in tests, held GENERIC_READ parent handles and checks before/after open. Fresh run2: 103 PASS. Additional and targeted suites were executed after relevant final changes.', '', 'NOT_IMPLEMENTED / NOT_VERIFIED: real process start/stop, trusted consent and consumption, live process/port observation, RAM/commit/private/GPU/disk telemetry, runtime compatibility, job HTTP/submission/cancellation. NOT_TESTED: actual abandoned-kernel-mutex event and power-loss durability. Historical 24 operational NOT_IMPLEMENTED entries are not promoted.', '', 'Relevant Stage03D1 variants include seven distinct string/array/type failures and their composite hash-rebound reproductions; original graph topology, nodes/providers, hashes, paths/state rejections and blocked job launcher remain covered. Historical matrices retain their original statuses.')
WriteText (Join-Path $Evidence 'REGRESSION_MATRIX.md') ($matrix -join "`n")
WriteText (Join-Path $Evidence 'consolidated-results.json') (ConvertTo-Json -InputObject $rows -Depth 60)
$commands=@();$members=@()
foreach($name in @('Wlb.Startup.ps1','Start-WlbRuntime.ps1','Wlb.RuntimeMonitor.ps1','Wlb.StartupFiles.ps1')){
 $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root ('core\'+$name)),[ref]$tokens,[ref]$errors)
 if($errors.Count){throw "Parse errors: $name"}
 $commands+=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true) | ForEach-Object {[pscustomobject]@{file=$name;command=$_.GetCommandName();text=$_.Extent.Text}})
 $members+=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst]},$true) | ForEach-Object {[pscustomobject]@{file=$name;text=$_.Extent.Text}})
}
$forbidden=@($commands | Where-Object {$_.command -match '^(Start-Process|Stop-Process|Invoke-WebRequest|Invoke-RestMethod|Set-Acl|Set-NetFirewallRule|New-NetFirewallRule|python|python.exe|curl|wget)$'})
if($forbidden.Count){throw 'Forbidden command in new modules'}
WriteText (Join-Path $Evidence 'new-module-ast-census.json') (ConvertTo-Json @{commands=$commands;member_invocations=$members;interpretation='STATIC_CENSUS_ONLY_NOT_SANDBOX_PROOF'} -Depth 10)
$policy=Json (Join-Path $Root 'policy\executor-policy.json')
if($policy.execution_enabled){throw 'Job execution enabled'}
$review=& (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode StaticReview
$plan=& (Join-Path $Root 'core\Start-WlbRuntime.ps1') -Mode Plan
if($review.executable -or $plan.startup_performed -or $plan.state -cne 'BLOCKED'){throw 'Unexpected execution admission'}
$refusal='';try{$null=& (Join-Path $Root 'core\Start-WlbRuntime.ps1') -Mode Admission;throw 'Unexpected admission'}catch{$refusal=$_.Exception.Message;if($refusal -notlike 'BLOCKED:*'){throw}}
$audit=[ordered]@{status='COMPLETE_WITH_LIMITATIONS';preexisting_files=2148;unchanged_preexisting=$unchanged;changed_preexisting=$changed;bindings=$bindings;source_inventory_files=$sourceRows.Count;source_inventory_bytes=($sourceRows | Measure-Object bytes -Sum).Sum;dependency_distributions=$dependencies.Count;dependency_metadata_files=$metadataCount;source_fingerprints_rechecked_without_execution=$true;final_pass_rows=128;executed_checks=123;recorded_rechecks=5;initial_run_failures_retained=2;static_review=$review;startup_plan_state=$plan.state;startup_admission_refusal=$refusal;actual_runtime_started=$false;python_executed=$false;real_process_stopped=$false;real_approval_created_or_consumed=$false;snapshot_copied=$false;next_gate='WAITING_HUMAN_REVIEW'}
WriteText (Join-Path $Evidence 'final-audit.json') (ConvertTo-Json $audit -Depth 30)
$hashTable=@('| Existing file | Before SHA-256 | After SHA-256 | Justification |','|---|---|---|---|');foreach($item in $changed){$hashTable+='| '+$item.path+' | '+$item.before_sha256+' | '+$item.after_sha256+' | '+$item.reason+' |'}
$newTable=@('| New canonical artifact | Before | After SHA-256 |','|---|---|---|');foreach($item in $bindings | Where-Object {-not $oldLock.prepared_artifacts.ContainsKey($_.path)} | Sort-Object path){$newTable+='| '+$item.path+' | ABSENT | '+$item.sha256+' |'}
$receipt=@'
# STAGE03D2_IMPLEMENTATION_RECEIPT

## A. STAGE03D2_STATUS

COMPLETE_WITH_LIMITATIONS. Controlled source implementation and mock/fixture tests delivered. G2, G3, G4, G5 and ALPHA remain closed. PREPARED describes source contracts, NOT_VERIFIED describes live capability, WAITING_HUMAN describes consent/parameters, and BLOCKED is actual admission. FUTURE_G4_ELIGIBLE exists only as a tested future-review decision; authorized_to_execute remains false.

## B. VERIFIED_STAGE03D1_BASELINE

Before editing, 2146 hash-bearing prior inventory entries verified with zero divergence; 2148 existing files independently recorded, including two prior inventory self-metadata exclusions. Stage03D1 receipt SHA-256: 0ee20d032ee427e771f1fe011118f4d4dd8a1a9f318f641a6e710da9e88e3078. Authoritative D1 results: 693 static PASS, with operational statuses retained. Mandatory receipts/reports/matrix and canonical files were read. Baseline copies and all-existing-before.json preserve original bytes/hashes. Final audit compares all 2148 existing files and permits exactly the four changes in C. Historical Stage03C/03D1 reports, evidence and test fixtures are byte-identical.

## C. EXACT_CHANGESET_AND_HASHES

__EXISTING_HASH_TABLE__

__NEW_HASH_TABLE__

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
'@
$receipt=$receipt.Replace('__EXISTING_HASH_TABLE__',($hashTable -join "`n")).Replace('__NEW_HASH_TABLE__',($newTable -join "`n"))
WriteText (Join-Path $Root 'STAGE03D2_IMPLEMENTATION_RECEIPT.md') $receipt
$inventoryPath=Join-Path $Evidence 'new-files-inventory.csv'
$integrityPath=Join-Path $Evidence 'delivery-integrity.json'
$excluded=@($inventoryPath,$integrityPath)
$known=@{};foreach($item in $before){$known[$item.path]=$true}
$newFiles=@(Get-ChildItem -LiteralPath $Root -File -Recurse | Where-Object {$_.FullName -notin $excluded} | ForEach-Object {$relative=$_.FullName.Substring($Root.Length+1);if(-not $known.ContainsKey($relative)){[pscustomobject]@{path=$relative;bytes=$_.Length;sha256=Hash $_.FullName;before='ABSENT'}}} | Sort-Object path)
$newFiles | Export-Csv -LiteralPath $inventoryPath -NoTypeInformation -Encoding utf8
WriteText $integrityPath (ConvertTo-Json @{receipt_sha256=Hash (Join-Path $Root 'STAGE03D2_IMPLEMENTATION_RECEIPT.md');new_inventory_sha256=Hash $inventoryPath;new_files_hashed=$newFiles.Count;self_exclusions=@('tests\stage03d2\evidence\new-files-inventory.csv','tests\stage03d2\evidence\delivery-integrity.json');new_total_including_metadata=$newFiles.Count+2;changed_preexisting=4;unchanged_preexisting=2144;next_gate='WAITING_HUMAN_REVIEW'} -Depth 10)
ConvertTo-Json @{status=$audit.status;final_pass_rows=128;executed_checks=123;recorded_rechecks=5;changed_preexisting=4;unchanged_preexisting=2144;new_files=$newFiles.Count+2;metadata_files_rechecked=$metadataCount;receipt_sha256=Hash (Join-Path $Root 'STAGE03D2_IMPLEMENTATION_RECEIPT.md');next_gate='WAITING_HUMAN_REVIEW'}
