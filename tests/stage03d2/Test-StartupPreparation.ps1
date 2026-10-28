# Stage03D2 independent mocks + harmless own file/mutex objects. No runtime/source execution.
#requires -Version 7.6
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$Stage=Join-Path $Root 'tests\stage03d2'
$EvidenceRoot=Join-Path $Stage 'evidence\run2'
$Fixtures=Join-Path $Stage 'fixtures-run2'
if(Test-Path -LiteralPath $Fixtures){throw 'Fresh fixture namespace required'}
$null=New-Item -ItemType Directory -Path $Fixtures,$EvidenceRoot
. (Join-Path $Root 'core\Wlb.StartupFiles.ps1')
. (Join-Path $Root 'core\Wlb.RuntimeMonitor.ps1')
function Clone($Value){return ,(ConvertTo-Json -InputObject $Value -Depth 60 | ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Save([string]$Path,$Value){$bytes=[Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject $Value -Depth 80));$s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write($bytes,0,$bytes.Length);$s.Flush($true)}finally{$s.Dispose()}}
$Results=[Collections.Generic.List[object]]::new()
function Record([string]$Id,[string]$Expected,$Actual,[bool]$Passed,[string]$Kind='MOCK_DECISION'){$Results.Add([pscustomobject]@{id=$Id;expectation=$Expected;actual=$Actual;status=$(if($Passed){'PASS'}else{'FAIL'});evidence_kind=$Kind})}
function Reject([string]$Id,[scriptblock]$Action,[string]$Pattern,[string]$Kind='EXECUTED_STATIC_VALIDATION'){
    try{$out=@(& $Action);Record $Id 'Reject at specified guard' ('ACCEPTED: '+(ConvertTo-Json -InputObject $out -Depth 15 -Compress)) $false $Kind}
    catch{Record $Id 'Reject at specified guard' $_.Exception.Message ($_.Exception.Message -match $Pattern) $Kind}
}
$actualPolicy=Read-WlbJson (Join-Path $Root 'policy\startup-policy.json')
$identity=Read-WlbJson (Join-Path $Root 'policy\startup-identity.json')
$plan=Get-WlbFixedStartupPlan $actualPolicy $identity (Hash (Join-Path $Root 'policy\startup-policy.json')) (Hash (Join-Path $Root 'policy\runtime-lock.json'))
$policy=Clone $actualPolicy
foreach($key in $policy.human_parameters.Keys){$policy.human_parameters[$key].status='INJECTED_TEST_ONLY'}
$policy.human_parameters.operator_identity.value='TEST_OPERATOR_NOT_AUTHENTICATED'
$policy.human_parameters.cpu_budget.value='OBSERVE_ONLY_TEST'
$policy.human_parameters.polling_cadence_ms.value=100
$policy.human_parameters.telemetry_freshness_ms.value=500
$evidence=@{policy_sha256=$plan.policy_sha256;runtime_lock_sha256=$plan.runtime_lock_sha256;snapshot_exists=$true;snapshot_bytes_verified=$true;python_sha256=$plan.python_sha256;dependency_identity_verified=$true;port_identity_known=$true;port_occupied=$false;monitor_provider_ready=$true;prior_reservation=$false}
$ownerToken='00000000-0000-4000-8000-000000000002'
$consent=@{kind='MOCK_ONLY';scope='G4_STARTUP_ONLY';policy_sha256=$plan.policy_sha256;runtime_lock_sha256=$plan.runtime_lock_sha256;python_sha256=$plan.python_sha256;single_attempt=$true;stop_owned_allowed=$true;owner_token=$ownerToken}
$process=@{process_id=424242;creation_time_utc='2099-01-01T00:00:00.0000000Z';image_path=$plan.executable;image_sha256=$plan.python_sha256;owner_token=$ownerToken}
$good=Test-WlbStartupAdmission $policy $plan $evidence $consent -MockOnly
Record 'ADMISSION-ALL-MOCK-PREREQUISITES' 'FUTURE_G4_ELIGIBLE for review only; authorization=false' $good ($good.state -ceq 'FUTURE_G4_ELIGIBLE' -and -not $good.authorized_to_execute)
$without=Test-WlbStartupAdmission $policy $plan $evidence $null -MockOnly
Record 'STARTUP-NO-CONSENT' 'CONSENT_MISSING and no execution' $without ($without.reasons -contains 'CONSENT_MISSING' -and -not $without.authorized_to_execute)
$mutations=[ordered]@{
 'SNAPSHOT-INEXISTENT'=@{field='snapshot_exists';value=$false;reason='SNAPSHOT_MISSING_OR_UNVERIFIED'}
 'SNAPSHOT-UNPINNED'=@{field='snapshot_bytes_verified';value=$false;reason='SNAPSHOT_MISSING_OR_UNVERIFIED'}
 'PYTHON-FINGERPRINT-MISSING'=@{field='python_sha256';value='';reason='PYTHON_FINGERPRINT_MISSING_OR_DIVERGENT'}
 'POLICY-HASH-DIVERGENT'=@{field='policy_sha256';value=('0'*64);reason='POLICY_HASH_DIVERGENCE'}
 'RUNTIME-HASH-DIVERGENT'=@{field='runtime_lock_sha256';value=('0'*64);reason='RUNTIME_HASH_DIVERGENCE'}
 'DEPENDENCY-IDENTITY-UNKNOWN'=@{field='dependency_identity_verified';value=$false;reason='DEPENDENCY_IDENTITY_UNVERIFIED'}
 'PORT-OCCUPIED'=@{field='port_occupied';value=$true;reason='PORT_OCCUPIED_OR_UNKNOWN'}
 'PORT-UNKNOWN'=@{field='port_identity_known';value=$false;reason='PORT_OCCUPIED_OR_UNKNOWN'}
 'MONITOR-NOT-READY'=@{field='monitor_provider_ready';value=$false;reason='OPERATIONAL_MONITOR_NOT_READY'}
 'INTERRUPTED-RESERVATION'=@{field='prior_reservation';value=$true;reason='PRIOR_RESERVATION_RECONCILE_NO_RESTART'}
 'EVIDENCE-BOOL-STRING'=@{field='snapshot_exists';value='true';reason='Expected JSON Boolean'}
}
foreach($entry in $mutations.GetEnumerator()){$bad=Clone $evidence;$bad[$entry.Value.field]=$entry.Value.value;$out=Test-WlbStartupAdmission $policy $plan $bad $consent -MockOnly;Record $entry.Key 'Block changed/missing prerequisite' $out ($out.state -ceq 'BLOCKED' -and ($out.reasons -join ';') -match [regex]::Escape($entry.Value.reason))}
foreach($key in $actualPolicy.human_parameters.Keys){$bad=Clone $policy;$bad.human_parameters[$key]=Clone $actualPolicy.human_parameters[$key];$out=Test-WlbStartupAdmission $bad $plan $evidence $consent -MockOnly;Record ('UNKNOWN-'+$key) 'Unapproved human parameter blocks admission' $out ($out.state -ceq 'BLOCKED' -and ($out.reasons -contains ('HUMAN_PARAMETER_PENDING:'+ $key)))}
$real=Test-WlbStartupAdmission $actualPolicy $plan $evidence $consent
Record 'MOCK-CANNOT-AUTHORIZE-REAL-START' 'No real authority even with fabricated evidence' $real ($real.state -ceq 'BLOCKED' -and -not $real.authorized_to_execute)
$bad=Clone $consent;$bad.scope='GPU_JOB';$out=Test-WlbStartupAdmission $policy $plan $evidence $bad -MockOnly
Record 'WRONG-CONSENT-SCOPE' 'Startup-only consent required' $out ($out.state -ceq 'BLOCKED')
$bad=Clone $consent;$bad.single_attempt='true';$out=Test-WlbStartupAdmission $policy $plan $evidence $bad -MockOnly
Record 'CONSENT-TYPE-STRING' 'Strict bool consent field' $out (($out.reasons -join ';') -match 'Expected JSON Boolean')
foreach($field in @('main_path','working_directory')){$bad=Clone $identity;$bad[$field]='D:\outside\NOT_EXECUTED';Reject ('PLAN-ARBITRARY-'+$field) {Get-WlbFixedStartupPlan $actualPolicy $bad $plan.policy_sha256 $plan.runtime_lock_sha256} 'Arbitrary'}
$bad=Clone $identity;$bad.python.path='C:\NOT_EXECUTED\python.exe';Reject 'PLAN-ARBITRARY-PYTHON' {Get-WlbFixedStartupPlan $actualPolicy $bad $plan.policy_sha256 $plan.runtime_lock_sha256} 'Arbitrary Python'
$entry=& (Join-Path $Root 'core\Start-WlbRuntime.ps1') -Mode Plan
Record 'REAL-ENTRY-PLAN-NO-EFFECTS' 'Plan PREPARED/NOT_VERIFIED/WAITING_HUMAN/BLOCKED; startup false' $entry (-not $entry.startup_performed -and $entry.state -ceq 'BLOCKED') 'EXECUTED_PLAN_ONLY'
Reject 'REAL-ENTRY-ADMISSION-CLOSED' {& (Join-Path $Root 'core\Start-WlbRuntime.ps1') -Mode Admission} 'BLOCKED:'

$same=Test-WlbProcessIdentity $process (Clone $process);Record 'OWNED-PROCESS-TUPLE' 'Exact injected PID/time/image/hash/token matches' $same $same.owned
foreach($field in @('process_id','creation_time_utc','image_path','image_sha256','owner_token')){
    $bad=Clone $process;$bad[$field]=switch($field){'process_id'{424243};'creation_time_utc'{'2099-01-01T00:00:01.0000000Z'};'image_path'{'D:\foreign\python.exe'};'image_sha256'{('0'*64)};'owner_token'{'00000000-0000-4000-8000-000000000009'}}
    $out=Test-WlbProcessIdentity $process $bad;Record ('FOREIGN-'+$field) 'Any mismatch denies ownership and stopping' $out (-not $out.owned)
}
$port=@{known=$true;occupied=$true;listen_address='127.0.0.1';port=8189;process_id=$process.process_id}
$out=Test-WlbPortOwnership $process $process $port;Record 'OWNED-PORT-MOCK' 'Full owned tuple and pinned listener matches' $out $out.owned
foreach($field in @('known','process_id','listen_address')){$bad=Clone $port;$bad[$field]=switch($field){'known'{$false};'process_id'{424243};'listen_address'{'0.0.0.0'}};$out=Test-WlbPortOwnership $process $process $bad;Record ('FOREIGN-PORT-'+$field) 'Unknown/foreign listener denied' $out (-not $out.owned)}
$foreign=Clone $process;$foreign.process_id=424243
$out=Test-WlbMockStopAuthority $process $foreign $consent -MockOnly;Record 'FOREIGN-PROCESS-CANNOT-STOP' 'Stop authorization denied for foreign tuple' $out (-not $out.allowed)
$out=Test-WlbMockStopAuthority $process $process $consent;Record 'REAL-STOP-ADAPTER-DISABLED' 'No actual termination adapter, including matched tuple' $out (-not $out.allowed -and -not $out.real_process_stop_enabled)

$baseline=@{schema_version='wlb-startup-telemetry/0.1';source='INJECTED_TEST_ONLY';clock_id='mock-clock-1';sampled_ms=0;available_ram_bytes=[long](10GB);commit_headroom_bytes=[long](12GB);total_commit_bytes=[long](16GB);private_bytes=[long]0;vram_bytes=[long](1GB);aggregate_output_log_temp_bytes=[long]0;foreign_gpu_jobs=0;heavy_processes_active=$false;attribution_known=$true}
$sample=Clone $baseline;$sample.sampled_ms=100
$resourceGood=Test-WlbResourceSample $policy $baseline $sample 100 0;Record 'RESOURCE-WITHIN-THRESHOLDS' 'Continue injected monitoring only' $resourceGood (-not $resourceGood.abort)
$limits=[ordered]@{
 'RAM-LOW'=@{field='available_ram_bytes';value=[long](8GB-1);reason='AVAILABLE_RAM_BELOW_8_GIB'}
 'COMMIT-HEADROOM-LOW'=@{field='commit_headroom_bytes';value=[long](10GB-1);reason='COMMIT_HEADROOM_BELOW_10_GIB'}
 'COMMIT-DELTA-HIGH'=@{field='total_commit_bytes';value=[long](20GB+1);reason='INCREMENTAL_COMMIT_OVER_4_GIB'}
 'PRIVATE-BYTES-HIGH'=@{field='private_bytes';value=[long](4GB+1);reason='PRIVATE_BYTES_OVER_4_GIB'}
 'VRAM-DELTA-HIGH'=@{field='vram_bytes';value=[long](3GB+1);reason='INCREMENTAL_VRAM_OVER_2_GIB'}
 'AGGREGATE-LOG-TEMP-HIGH'=@{field='aggregate_output_log_temp_bytes';value=[long](256MB+1);reason='AGGREGATE_FILES_OVER_256_MIB'}
 'FOREIGN-GPU-JOB'=@{field='foreign_gpu_jobs';value=1;reason='FOREIGN_GPU_OR_HEAVY_WORKLOAD'}
 'HEAVY-PROCESS-ACTIVE'=@{field='heavy_processes_active';value=$true;reason='FOREIGN_GPU_OR_HEAVY_WORKLOAD'}
 'VRAM-ATTRIBUTION-UNKNOWN'=@{field='attribution_known';value=$false;reason='TELEMETRY_ATTRIBUTION_UNKNOWN'}
 'COUNTER-REVERSED'=@{field='total_commit_bytes';value=[long](15GB);reason='COUNTER_REVERSED_OR_UNATTRIBUTABLE'}
 'TELEMETRY-WRONG-CLOCK'=@{field='clock_id';value='foreign-clock';reason='Clock domain mismatch'}
 'TELEMETRY-NUMERIC-STRING'=@{field='private_bytes';value='0';reason='Expected JSON Integer'}
}
foreach($entry in $limits.GetEnumerator()){$bad=Clone $sample;$bad[$entry.Value.field]=$entry.Value.value;$out=Test-WlbResourceSample $policy $baseline $bad 100 0;Record $entry.Key 'Abort invalid/exceeded resource evidence' $out ($out.abort -and ($out.reasons -join ';') -match [regex]::Escape($entry.Value.reason))}
$boundary=Clone $sample;$boundary.available_ram_bytes=[long](8GB);$boundary.commit_headroom_bytes=[long](10GB);$boundary.total_commit_bytes=[long](20GB);$boundary.private_bytes=[long](4GB);$boundary.vram_bytes=[long](3GB);$boundary.aggregate_output_log_temp_bytes=[long](256MB)
$out=Test-WlbResourceSample $policy $baseline $boundary 100 0;Record 'RESOURCE-EXACT-BOUNDARIES' 'Inclusive memory/file thresholds without cap increase' $out (-not $out.abort)
$out=Test-WlbResourceSample $policy $baseline $null 100 0;Record 'TELEMETRY-MISSING' 'Absent sample blocks' $out $out.abort
$out=Test-WlbResourceSample $policy $baseline $sample 1000 0;Record 'TELEMETRY-STALE' 'Age beyond injected freshness blocks' $out ($out.abort -and $out.reasons -contains 'TELEMETRY_STALE')
$late=Clone $sample;$late.sampled_ms=120000;$out=Test-WlbResourceSample $policy $baseline $late 120000 0;Record 'DEADLINE-120S' 'Monotonic deadline reached blocks' $out ($out.abort -and $out.reasons -contains 'STARTUP_DEADLINE_EXPIRED')
$before=Clone $sample;$before.sampled_ms=119999;$out=Test-WlbResourceSample $policy $baseline $before 119999 0;Record 'DEADLINE-BEFORE-120S' 'Within window passes mock only' $out (-not $out.abort)
$out=Test-WlbResourceSample $policy $baseline $sample -1 0;Record 'CLOCK-REVERSED' 'Clock cannot reverse' $out $out.abort
foreach($foreignOwner in @($false,$true)){
    $ctx=@{now=100;stops=0};$bad=Clone $sample;$bad.private_bytes=[long](4GB+1);$observed=if($foreignOwner){$foreign}else{$process}
    $readClock={ $ctx.now }.GetNewClosure();$readSample={ $bad }.GetNewClosure();$readProcess={ $observed }.GetNewClosure();$stop={param($p) $ctx.stops++}.GetNewClosure();$advance={param($ms) $ctx.now+=$ms}.GetNewClosure()
    $out=Invoke-WlbInjectedWatchdog $policy $baseline $process $consent $readSample $readClock $readProcess $stop $advance
    Record $(if($foreignOwner){'WATCHDOG-FOREIGN-NO-STOP'}else{'WATCHDOG-OWNED-MOCK-STOP'}) 'Abort calls only proven owned mock stop; never real termination' $out $(if($foreignOwner){$ctx.stops -eq 0 -and -not $out.mock_stop_callback_invoked}else{$ctx.stops -eq 1 -and $out.mock_stop_callback_invoked})
}
$ctx=@{now=100;stops=0};$out=Invoke-WlbInjectedWatchdog $policy $baseline $process $consent {throw 'mock provider unavailable'} {100} {$process} {param($p) $ctx.stops++} {param($ms)}
Record 'WATCHDOG-PROVIDER-FAILURE' 'Counter provider failure aborts, no restart' $out ($out.state -ceq 'BLOCKED' -and -not $out.restart_allowed)

# Real harmless fixture file/mutex tests. No live namespace is passed to write functions.
$fileCase=Join-Path $Fixtures 'files';$null=New-Item -ItemType Directory -Path $fileCase
$filePath=Join-Path $fileCase 'evidence.test.json';$bytes=[Text.Encoding]::UTF8.GetBytes('{"test_only":true}')
$fingerprint=Write-WlbTestNewFile $filePath $bytes
$pinned=Read-WlbTestPinnedFile $fingerprint
Record 'CREATE-NEW-FLUSH-PIN' 'One exclusive created file has pinned immutable bytes' $fingerprint ($pinned.sha256 -ceq $fingerprint.sha256) 'REAL_FIXTURE_FILE_IO'
Reject 'NO-OVERWRITE' {Write-WlbTestNewFile $filePath $bytes} 'already exists|exists' 'REAL_FIXTURE_FILE_IO'
Reject 'NO-LIVE-NAMESPACE-WRITES' {Write-WlbTestNewFile (Join-Path $Root 'runtimes\core\startup\FORBIDDEN.json') $bytes} 'limited to own Stage03D2' 'REAL_PATH_GUARD'
Reject 'PATH-TRAVERSAL' {Write-WlbTestNewFile ($fileCase+'\..\escape.json') $bytes} 'traversal' 'REAL_PATH_GUARD'
Reject 'PATH-UNC' {Write-WlbTestNewFile '\\NOT_REAL\share\file.json' $bytes} 'absolute D:' 'REAL_PATH_GUARD'
$stashed=Join-Path $fileCase 'original-retained.json';$null=Assert-WlbStartupTestPath $stashed
[IO.File]::Move($filePath,$stashed)
$replacement=Write-WlbTestNewFile $filePath $bytes
Reject 'FILE-REPLACED-BETWEEN-USES' {Read-WlbTestPinnedFile $fingerprint} 'replaced since fingerprint' 'REAL_FIXTURE_FILE_IO'
[IO.File]::WriteAllText($filePath,'DIFFERENT OWN FIXTURE BYTES')
Reject 'FILE-BYTES-TAMPERED' {Read-WlbTestPinnedFile $replacement} 'Pinned bytes changed' 'REAL_FIXTURE_FILE_IO'
$partialPath=Join-Path $fileCase 'partial.test.json'
Reject 'INCOMPLETE-WRITE-RETAINED' {Write-WlbTestNewFile $partialPath $bytes -InjectIncompleteWrite} 'incomplete write' 'REAL_FIXTURE_FILE_IO'
Record 'PARTIAL-EVIDENCE-STILL-PRESENT' 'Incomplete evidence retained; no cleanup' ([ordered]@{exists=Test-Path -LiteralPath $partialPath;bytes=(Get-Item -LiteralPath $partialPath).Length}) ((Get-Item -LiteralPath $partialPath).Length -eq 3) 'REAL_FIXTURE_FILE_IO'
Reject 'PARTIAL-NO-IMPLICIT-RETRY' {Write-WlbTestNewFile $partialPath $bytes} 'already exists|exists' 'REAL_FIXTURE_FILE_IO'
$race=Join-Path $Fixtures 'race-parent';$raceNew=Join-Path $Fixtures 'race-parent-renamed';$null=New-Item -ItemType Directory -Path $race
$null=Assert-WlbStartupTestPath $race -MustExist;$null=Assert-WlbStartupTestPath $raceNew
$raceCallback={try{[IO.Directory]::Move($race,$raceNew)}catch{throw 'PATH_SWAP_BLOCKED_BY_HELD_PARENT_HANDLE'}}.GetNewClosure()
Reject 'PARENT-SWAP-DURING-USE' {Write-WlbTestNewFile (Join-Path $race 'new.json') $bytes -BeforeUse $raceCallback} 'PATH_SWAP_BLOCKED_BY_HELD_PARENT_HANDLE|Directory handle identity changed' 'REAL_FIXTURE_FILE_IO'
$leaseNamespace=Join-Path $Fixtures 'lease';$null=New-Item -ItemType Directory -Path $leaseNamespace
$lease=New-WlbTestStartupLease $leaseNamespace
$ps=[PowerShell]::Create()
try{
    $scriptText='param($module,$namespace) . $module; try { $lease=New-WlbTestStartupLease $namespace; Close-WlbTestStartupLease $lease; "UNEXPECTED_ACQUIRE" } catch { $_.Exception.Message }'
    $null=$ps.AddScript($scriptText).AddArgument((Join-Path $Root 'core\Wlb.StartupFiles.ps1')).AddArgument($leaseNamespace)
    $async=$ps.BeginInvoke();$out=@($ps.EndInvoke($async)) -join ';'
    Record 'MUTEX-CONCURRENT-RUNSPACE' 'Second thread cannot acquire same test executor mutex' $out ($out -match 'Concurrent executor mutex already owned') 'REAL_NAMED_TEST_MUTEX'
}finally{$ps.Dispose();Close-WlbTestStartupLease $lease}
Reject 'PERSISTENT-RESERVATION-RESTART-DENIED' {New-WlbTestStartupLease $leaseNamespace} 'already exists|exists' 'REAL_FIXTURE_MUTEX_AND_FILES'
$reservation=Join-Path $leaseNamespace 'reservation.test.json';Record 'RESERVATION-PERSISTS' 'Lease release does not remove reservation or permit implicit rerun' $reservation (Test-Path -LiteralPath $reservation) 'REAL_FIXTURE_FILE_IO'

# Concise regression: exact Stage03D1 graph/policy failures and existing path/node/value checks.
$originalGraph=Read-WlbJson (Join-Path $Root 'workflows\draft\poc0-calibration.api.json')
$jobPolicy=Read-WlbJson (Join-Path $Root 'policy\executor-policy.json')
foreach($id in @('D-STRING-WIDTH','D-ARRAY-WIDTH','D-STRING-BATCH','D-STRING-LINK-SLOT','D-ADDITIONAL-NODE','D-PROVIDER-NODE','D-COMMAND-NODE','D-UNEXPECTED-DESTINATION','D-UNEXPECTED-LINK','GRAPH-OBJECT-TYPE-ROOT-ARRAY')){
    $oldPath=Join-Path $Root ('tests\stage03d1\fixtures-run2\'+$id+'.json');$copy=Join-Path $Fixtures ($id+'.json');[IO.File]::Copy($oldPath,$copy,$false)
    Reject ('REGRESSION-'+$id) {Assert-WlbPoc0Graph (Read-WlbJson $copy)} 'BLOCKED:'
}
$bad=Clone $jobPolicy;$bad.execution_enabled='false';Reject 'REGRESSION-POLICY-STRING-BOOL' {Assert-WlbExecutorPolicy $bad} 'Expected JSON Boolean'
$bad=Clone $jobPolicy;$bad.budget.max_incremental_commit_gib='4';Reject 'REGRESSION-POLICY-STRING-BUDGET' {Assert-WlbExecutorPolicy $bad} 'Expected JSON Integer'
$bad=Clone $jobPolicy;$bad.max_active_jobs='1';Reject 'REGRESSION-POLICY-STRING-CONCURRENCY' {Assert-WlbExecutorPolicy $bad} 'Expected JSON Integer'
Reject 'REGRESSION-EXECUTION-ELIGIBILITY' {& (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode ExecutionEligibility} 'BLOCKED: G1'
$base=& (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode StaticReview;Record 'REGRESSION-DRAFT-BASELINE' 'Original POC graph remains valid nonexecutable preparation' $base (-not $base.executable) 'EXECUTED_CURRENT_VALIDATOR'
# One reusable owned mirror avoids hundreds of redundant copies; captured mutation/result identifies each case.
$mirror=Join-Path $Fixtures 'mirror';$runtime=Read-WlbJson (Join-Path $Root 'policy\runtime-lock.json')
$mirrorFiles=@($runtime.prepared_artifacts.Keys)+@('policy\runtime-lock.json','manifests\draft\POC0-CALIBRATION-001.json')
function Reset-Mirror {
    foreach($relative in $mirrorFiles){$path=Join-Path $mirror $relative;$parent=[IO.Path]::GetDirectoryName($path);if(-not(Test-Path -LiteralPath $parent)){$null=New-Item -ItemType Directory -Path $parent};$raw=[IO.File]::ReadAllText((Join-Path $Root $relative));$raw=$raw.Replace($Root.Replace('\','\\'),$mirror.Replace('\','\\')).Replace($Root,$mirror);[IO.File]::WriteAllText($path,$raw,[Text.UTF8Encoding]::new($false))}
}
function Bind-Mirror {
    $r=Get-Content -LiteralPath (Join-Path $mirror 'policy\runtime-lock.json') -Raw | ConvertFrom-Json -AsHashtable
    foreach($key in @($r.prepared_artifacts.Keys)){$r.prepared_artifacts[$key]=Hash (Join-Path $mirror $key)}
    [IO.File]::WriteAllText((Join-Path $mirror 'policy\runtime-lock.json'),(ConvertTo-Json -InputObject $r -Depth 60),[Text.UTF8Encoding]::new($false))
    $m=Get-Content -LiteralPath (Join-Path $mirror 'manifests\draft\POC0-CALIBRATION-001.json') -Raw | ConvertFrom-Json -AsHashtable
    $m.workflow.sha256=Hash (Join-Path $mirror 'workflows\draft\poc0-calibration.api.json');$m.binding.policy_sha256=Hash (Join-Path $mirror 'policy\executor-policy.json');$m.binding.runtime_lock_sha256=Hash (Join-Path $mirror 'policy\runtime-lock.json')
    [IO.File]::WriteAllText((Join-Path $mirror 'manifests\draft\POC0-CALIBRATION-001.json'),(ConvertTo-Json -InputObject $m -Depth 60),[Text.UTF8Encoding]::new($false))
}
Reset-Mirror;Bind-Mirror
$out=& (Join-Path $mirror 'core\Test-WlbManifest.ps1') -Mode StaticReview;Record 'COMPOSITE-BASELINE' 'Relocated full validator passes as nonexecutable' $out (-not $out.executable) 'EXECUTED_OWN_MIRROR'
$cases=[ordered]@{
 'COMPOSITE-STRING-WIDTH'=@{relative='workflows\draft\poc0-calibration.api.json';mutation={param($x) $x['1'].inputs.width='640'};pattern='Expected JSON Integer'}
 'COMPOSITE-ARRAY-WIDTH'=@{relative='workflows\draft\poc0-calibration.api.json';mutation={param($x) $x['1'].inputs.width=@(640)};pattern='Expected JSON Integer'}
 'COMPOSITE-STRING-BATCH'=@{relative='workflows\draft\poc0-calibration.api.json';mutation={param($x) $x['1'].inputs.batch_size='1'};pattern='Expected JSON Integer'}
 'COMPOSITE-STRING-LINK'=@{relative='workflows\draft\poc0-calibration.api.json';mutation={param($x) $x['2'].inputs.images=@('1','0')};pattern='Expected JSON Integer'}
 'COMPOSITE-POLICY-STRING-BOOL'=@{relative='policy\executor-policy.json';mutation={param($x) $x.auto_retry='false'};pattern='Expected JSON Boolean'}
 'COMPOSITE-POLICY-STRING-BUDGET'=@{relative='policy\executor-policy.json';mutation={param($x) $x.budget.max_incremental_commit_gib='4'};pattern='Expected JSON Integer'}
 'COMPOSITE-POLICY-STRING-CONCURRENCY'=@{relative='policy\executor-policy.json';mutation={param($x) $x.max_active_jobs='1'};pattern='Expected JSON Integer'}
 'COMPOSITE-NODE-EXTRA'=@{relative='workflows\draft\poc0-calibration.api.json';mutation={param($x) $x['3']=@{class_type='Provider';inputs=@{}}};pattern='Unexpected key count: graph'}
 'COMPOSITE-PROVIDER'=@{relative='workflows\draft\poc0-calibration.api.json';mutation={param($x) $x['1'].class_type='Provider'};pattern='Wrong source node'}
 'COMPOSITE-STATE'=@{relative='manifests\draft\POC0-CALIBRATION-001.json';mutation={param($x) $x.state='REVIEWED'};pattern='G1 artifact must remain DRAFT'}
}
foreach($entry in $cases.GetEnumerator()){
    Reset-Mirror;$path=Join-Path $mirror $entry.Value.relative;$x=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable;& $entry.Value.mutation $x
    [IO.File]::WriteAllText($path,(ConvertTo-Json -InputObject $x -Depth 60),[Text.UTF8Encoding]::new($false));Bind-Mirror
    Reject $entry.Key {& (Join-Path $mirror 'core\Test-WlbManifest.ps1') -Mode StaticReview} $entry.Value.pattern 'EXECUTED_OWN_MIRROR'
}
foreach($entry in @(@{id='COMPOSITE-GRAPH-HASH';relative='workflows\draft\poc0-calibration.api.json';pattern='Workflow hash mismatch'},@{id='COMPOSITE-RUNTIME-HASH';relative='policy\runtime-lock.json';pattern='Runtime lock hash mismatch'},@{id='COMPOSITE-POLICY-HASH';relative='policy\executor-policy.json';pattern='Policy hash mismatch'})){
    Reset-Mirror;Bind-Mirror;[IO.File]::AppendAllText((Join-Path $mirror $entry.relative),"`n ");Reject $entry.id {& (Join-Path $mirror 'core\Test-WlbManifest.ps1') -Mode StaticReview} $entry.pattern 'EXECUTED_OWN_MIRROR'
}
Reset-Mirror;Bind-Mirror
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'core\Invoke-WlbJob.ps1'),[ref]$tokens,[ref]$errors)
Record 'GPU-LAUNCHER-STILL-CLOSED' 'Unchanged final unconditional throw; never invoked' $ast.EndBlock.Statements[-1].Extent.Text ($ast.EndBlock.Statements[-1] -is [Management.Automation.Language.ThrowStatementAst]) 'STATIC_AST'
Save (Join-Path $EvidenceRoot 'test-results.json') @($Results)
$matrix=@('# Stage03D2 mock / fixture regression matrix','','Mock PASS is not live-runtime proof. Real file/mutex rows use own harmless test objects only.','','| Test | Expectation | Actual | Status | Kind |','| --- | --- | --- | --- | --- |')
foreach($row in $Results){$actual=if($row.actual -is [string]){$row.actual}else{ConvertTo-Json -InputObject $row.actual -Depth 25 -Compress};$matrix+='| '+$row.id+' | '+$row.expectation+' | '+$actual.Replace('|','\|').Replace("`n",' ').Replace("`r",' ')+' | '+$row.status+' | '+$row.evidence_kind+' |'}
[IO.File]::WriteAllText((Join-Path $EvidenceRoot 'TEST_MATRIX.md'),($matrix -join "`n"),[Text.UTF8Encoding]::new($false))
$summary=[ordered]@{tests=$Results.Count;counts=@($Results | Group-Object status | ForEach-Object {[ordered]@{status=$_.Name;count=$_.Count}});actual_runtime_started=$false;real_process_stopped=$false;real_approvals_created=$false;python_executed=$false;network_calls=$false;mutex_and_file_tests='HARMLESS_STAGE03D2_FIXTURES_ONLY';operational_adapters='NOT_VERIFIED_OR_DISABLED'}
Save (Join-Path $EvidenceRoot 'test-summary.json') $summary
$summary | ConvertTo-Json -Depth 12
if(@($Results | Where-Object {$_.status -eq 'FAIL'}).Count){exit 1}
