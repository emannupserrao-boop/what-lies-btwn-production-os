#requires -Version 7.6
param([ValidatePattern('^run[1-9][0-9]?$')][string]$Run='run1')
. (Join-Path $PSScriptRoot 'I.Common.ps1')
. (Join-Path $IRoot 'core\Wlb.TelemetryWorker.ps1')
Initialize-WlbSupervisionTypes
$rows=[Collections.Generic.List[object]]::new()
function Check([string]$id,$actual,[bool]$ok,[string]$kind='EXECUTED_ISOLATED_FIXTURE'){$rows.Add([pscustomobject]@{id=$id;status=$(if($ok){'PASS'}else{'FAIL'});actual=$actual;evidence_kind=$kind})}
function Reject([string]$id,[scriptblock]$action,[string]$match){try{$null=& $action;Check $id 'UNEXPECTED_ACCEPT' $false}catch{Check $id $_.Exception.Message ($_.Exception.Message -match $match)}}
$TestWorkerIdentity='1'*64;$clock='SIMULATED_CLOCK_I';$policy=Read-WlbJson (Join-Path $IRoot 'policy\startup-policy.json')
$p=@{status='AVAILABLE_PROCESS_ATTRIBUTED';requested_pid=424242;process_id=424242;creation_time_utc='2099-01-01T00:00:00.0000000Z';image_path='D:\SIMULATED\python.exe';image_sha256=('2'*64);private_bytes=[long](1GB);cpu_total_100ns=[long]0;captured_ms=[long]0}
$base=@{schema_version='wlb-passive-telemetry/0.1';source='PASSIVE_LOCAL_READ_ONLY';clock_id=$clock;start_ms=[long]0;end_ms=[long]10;collection_ms=[long]10;host=@{status='AVAILABLE_GLOBAL';available_ram_bytes=[long](10GB);commit_total_bytes=[long](16GB);commit_limit_bytes=[long](32GB);commit_headroom_bytes=[long](16GB)};processes=@($p);gpu=@{status='AVAILABLE_GLOBAL';global=@{index=0;name='NVIDIA GeForce RTX 5080 Laptop GPU';uuid='GPU-00000000-0000-0000-0000-000000000001';driver='FIXTURE_DRIVER';used_bytes=[long](1GB);free_bytes=[long](15GB);total_bytes=[long](16GB)};rtx_process_attribution='VERIFIED_RTX_PROCESS_RESIDENCY'};port=@{known=$true;occupied=$false};concurrency=@{known=$true;exclusivity_proven=$true;potential_heavy_processes=@();actor_set_identity=('3'*64)};disk=@{known=$true;aggregate_bytes=[long]0};source_generation_freshness='VERIFIED';preparation_scope='G4_STARTUP_NO_MODELS';models_requested=$false}
$sample=Copy-IObject $base;$sample.start_ms=[long]100;$sample.end_ms=[long]110
function Context {New-WlbPreparedSupervisor $TestWorkerIdentity $clock 'SIMULATED_TEST_ONLY' 0}
function Env($value=$sample,[long]$seq=1,[long]$slowSeq=1,[long]$request=100,[long]$fast=100,[long]$slow=100,[long]$end=110,[bool]$generation=$true,[string]$kind='SIMULATED_TEST_ONLY',[string]$worker=$TestWorkerIdentity,[string]$domain=$clock){New-WlbPreparedEnvelope $worker $domain $kind $seq $slowSeq $request $fast $slow $end $generation $value}
function Beat($ctx,[long]$seq=1,[long]$at=190,[bool]$failed=$false){$ctx.Mailbox.TryHeartbeat([WlbSupervision.Heartbeat]::new($TestWorkerIdentity,$clock,$seq,$at,$failed))}
function Deliver($ctx,$env,[long]$now=200){$null=Beat $ctx 1 ($now-1);$null=$ctx.Mailbox.TryPublish($env);$ctx.Tick($now)}
$ctx=Context;$e=Env;$out=Deliver $ctx $e
Check 'METADATA-FIXTURE-VALID-NEVER-STARTUP' $out ($out.TelemetryState -ceq 'METADATA_VALID_PREPARATION_ONLY' -and $out.State -ceq 'BLOCKED_NOT_AUTHORIZED' -and -not $out.AuthorizedToExecute)
$decision=Get-WlbPreparedSupervisorDecision $ctx $policy $base $p 200
Check 'INTEGRATED-G-RESOURCE-FIXTURE-NO-AUTHORITY' $decision ($decision.resource.state -ceq 'FEASIBILITY_THRESHOLDS_ONLY' -and -not $decision.authorized_to_execute)
$mutable=Copy-IObject $sample;$immutable=Env $mutable;$mutable.host.available_ram_bytes=0
$read=$immutable.PayloadJson|ConvertFrom-Json -AsHashtable
Check 'IMMUTABLE-PAYLOAD-DEEP-SNAPSHOT' $read.host.available_ram_bytes ($read.host.available_ram_bytes -eq 10GB)
Reject 'IMMUTABLE-PROPERTY-NO-SETTER' {$immutable.PayloadJson='changed'} 'read.?only|cannot be set|Somente|set|definir'
Reject 'UTF8-PAYLOAD-64K-BOUND' {Env @{padding=('é'*40000)}} 'PAYLOAD_BYTE_BOUND'
Reject 'ZERO-SEQUENCE-REJECTED' {Env $sample 0} 'INVALID_SEQUENCE'
Reject 'NEGATIVE-TIMESTAMP-REJECTED' {Env $sample 1 1 -1} 'INVALID_SEQUENCE_OR_TIMESTAMPS'
Reject 'COLLECTION-END-BEFORE-ACQUISITION' {Env $sample 1 1 100 100 100 99} 'INVALID_SEQUENCE_OR_TIMESTAMPS'
Reject 'WORKER-IDENTITY-BOUNDED' {[WlbSupervision.Mailbox]::new('x'*1024,$clock)} 'BOUNDED_IDENTITY'
Reject 'CLOCK-ID-BOUNDED' {[WlbSupervision.Mailbox]::new($TestWorkerIdentity,('x'*129))} 'BOUNDED_IDENTITY'
Reject 'CANDIDATE-FRESHNESS-NOT-POLICY' {New-WlbPreparedSupervisor $TestWorkerIdentity $clock 'SIMULATED_TEST_ONLY' 0 1000} 'PREPARATION_CONTEXT_ONLY'
$ctx=Context;$out=Deliver $ctx (Env $sample 1 1 100 100 100 2501) 2501
Check 'SLOW-SAMPLER-STALE-COMPLETION' $out ($out.Terminal -and $out.Reason -ceq 'ACQUISITION_RECEIPT_FRESHNESS_EXCEEDED')
$ctx=Context;$out=$ctx.Tick(2001);Check 'WORKER-NO-HEARTBEAT' $out ($out.Terminal -and $out.Reason -ceq 'WORKER_HEARTBEAT_MISSING')
$ctx=Context;$null=Beat $ctx 1 2001;$out=$ctx.Tick(2001);Check 'TELEMETRY-ABSENT-WITH-HEARTBEAT' $out ($out.Terminal -and $out.Reason -ceq 'TELEMETRY_MISSING')
$ctx=Context;$null=Deliver $ctx (Env);$null=Beat $ctx 2 2101;$out=$ctx.Tick(2101)
Check 'HEARTBEAT-DOES-NOT-RENEW-MEASUREMENT' $out ($out.Terminal -and $out.Reason -ceq 'ACQUISITION_RECEIPT_FRESHNESS_EXCEEDED')
$ctx=Context;$null=Beat $ctx 1 0;$out=$ctx.Tick(2001);Check 'WORKER-HEARTBEAT-EXPIRED' $out ($out.Reason -ceq 'WORKER_HEARTBEAT_EXPIRED')
$ctx=Context;$null=Beat $ctx 1 199 $true;$null=Beat $ctx 2 200 $false;$out=$ctx.Tick(200)
Check 'FAILED-WORKER-LATCH-NO-HEARTBEAT-RECOVERY' $out ($out.Terminal -and $out.Reason -ceq 'WORKER_READ_FAILED')
$ctx=Context;$out=Deliver $ctx (Env -generation $false);Check 'PROVIDER-GENERATION-UNKNOWN' $out ($out.Terminal -and $out.Reason -ceq 'PROVIDER_GENERATION_AGE_UNKNOWN' -and $out.ObservedReceivedMs -eq 200 -and $null -eq $out.SupervisorReceivedMs)
$passive=Env -generation $true -kind 'PASSIVE_PREPARATION_ONLY'
Check 'PASSIVE-CANNOT-PROMOTE-GENERATION-VERIFIED' $passive.ProviderGenerationVerified (-not $passive.ProviderGenerationVerified)
$ctx=Context;$out=Deliver $ctx $passive;Check 'FIXTURE-PASSIVE-MODE-MISMATCH' $out ($out.Reason -ceq 'EVIDENCE_KIND_MISMATCH')
$ctx=Context;$out=Deliver $ctx (Env -worker ('4'*64));Check 'WORKER-IDENTITY-MISMATCH' $out ($out.Reason -ceq 'IDENTITY_OR_CLOCK_MISMATCH')
$ctx=Context;$out=Deliver $ctx (Env -domain 'FOREIGN_CLOCK');Check 'CLOCK-MISMATCH' $out ($out.Reason -ceq 'IDENTITY_OR_CLOCK_MISMATCH')
$ctx=Context;$null=Beat $ctx 1 201;$out=$ctx.Tick(200);Check 'FUTURE-HEARTBEAT' $out ($out.Reason -ceq 'HEARTBEAT_CLOCK_INVALID')
$ctx=Context;$out=Deliver $ctx (Env -end 201);Check 'FUTURE-ENVELOPE' $out ($out.Reason -ceq 'ENVELOPE_FUTURE_OR_CLOCK_INVALID')
$ctx=Context;$null=Deliver $ctx (Env);$out=$ctx.Tick(199);Check 'SUPERVISOR-CLOCK-REVERSAL' $out ($out.Reason -ceq 'SUPERVISOR_CLOCK_REVERSED')
$ctx=Context;$null=Deliver $ctx (Env);$null=$ctx.Mailbox.TryPublish((Env));$out=$ctx.Tick(201)
Check 'DUPLICATE-ENVELOPE' $out ($out.Reason -ceq 'ENVELOPE_SEQUENCE_INVALID')
$ctx=Context;$out=Deliver $ctx (Env -seq 2);Check 'OUT-OF-ORDER-SEQUENCE-GAP' $out ($out.Reason -ceq 'ENVELOPE_SEQUENCE_INVALID')
$ctx=Context;$null=$ctx.Mailbox.TryPublish((Env));$accepted=$ctx.Mailbox.TryPublish((Env -seq 2 -request 300 -fast 300 -end 310));$out=$ctx.Tick(400)
Check 'MAILBOX-CAPACITY1-FULL-FAIL-CLOSED' @{accepted=$accepted;capacity=$ctx.Mailbox.Capacity;decision=$out} (-not $accepted -and $ctx.Mailbox.Capacity -eq 1 -and $out.Reason -ceq 'MAILBOX_FULL')
$ctx=Context;$null=Deliver $ctx (Env);$null=Beat $ctx 2 399;$null=$ctx.Mailbox.TryPublish((Env -seq 2 -request 300 -fast 300 -slow 101 -end 310));$out=$ctx.Tick(400)
Check 'CACHED-SLOW-TIMESTAMP-CANNOT-BE-REWRITTEN' $out ($out.Reason -ceq 'CACHE_TIMESTAMP_OR_SEQUENCE_REWRITTEN')
$ctx=Context;$null=Deliver $ctx (Env);$null=Beat $ctx 2 399;$null=$ctx.Mailbox.TryPublish((Env -seq 2 -request 300 -fast 300 -slow 100 -end 310));$out=$ctx.Tick(400)
Check 'CACHED-SLOW-PRESERVES-ORIGINAL-AGE' $out ($out.TelemetryState -ceq 'METADATA_VALID_PREPARATION_ONLY' -and $out.AcquisitionAgeMs -eq 300 -and $out.LastEnvelope.CollectionDurationMs -eq 10)
$ctx=Context;$null=Deliver $ctx (Env);$null=Beat $ctx 2 2100;$out=$ctx.Tick(2100)
Check 'ACQUISITION-FRESHNESS-2000-EXACT' $out ($out.TelemetryState -ceq 'METADATA_VALID_PREPARATION_ONLY')
$ctx=Context;$null=Beat $ctx 1 119999;$null=$ctx.Mailbox.TryPublish((Env -request 119900 -fast 119900 -slow 119900 -end 119910));$out=$ctx.Tick(120000)
Check 'ABSOLUTE-DEADLINE-120S-EXACT-SIMULATION' $out ($out.Reason -ceq 'STARTUP_DEADLINE_120S')
$ctx=Context;$null=$ctx.Tick(120000);$out=$ctx.Tick(120001);Check 'BLOCKED-IS-TERMINAL-NO-RESTART' $out ($out.Terminal -and -not $out.AuthorizedToExecute)
foreach($scenario in @('GPU_UNAVAILABLE','UNATTRIBUTABLE_CONCURRENCY','PROCESS_IDENTITY_LOST','OWNERSHIP_LOST','RAM_BELOW','MISSING_FIELD','WRONG_TYPE')){
 $value=Copy-IObject $sample
 switch($scenario){'GPU_UNAVAILABLE'{$value.gpu.status='UNAVAILABLE'};'UNATTRIBUTABLE_CONCURRENCY'{$value.concurrency.exclusivity_proven=$false};'PROCESS_IDENTITY_LOST'{$value.processes[0].creation_time_utc='2099-01-01T00:00:01.0000000Z'};'RAM_BELOW'{$value.host.available_ram_bytes=[long](8GB-1)};'MISSING_FIELD'{$value.host.Remove('available_ram_bytes')};'WRONG_TYPE'{$value.host.available_ram_bytes='10737418240'}}
 $ctx=Context;$null=Deliver $ctx (Env $value);$out=Get-WlbPreparedSupervisorDecision $ctx $policy $base $p 200 -SimulatedOwnershipLost:($scenario -eq 'OWNERSHIP_LOST')
 Check ('INTEGRATED-'+$scenario) $out ($out.metadata.Terminal -and -not $out.authorized_to_execute)
}
$ctx=Context;$bad=[WlbSupervision.Envelope]::new($TestWorkerIdentity,$clock,'SIMULATED_TEST_ONLY',1,1,100,100,100,110,$true,'{bad}')
$null=Deliver $ctx $bad;$out=Get-WlbPreparedSupervisorDecision $ctx $policy $base $p 200
Check 'MALFORMED-PAYLOAD-PARSER-FAIL-CLOSED' $out ($out.metadata.Terminal -and $out.metadata.Reason -match 'PAYLOAD_OR_IDENTITY_INVALID')
$ctx=Context;$duplicate=[WlbSupervision.Envelope]::new($TestWorkerIdentity,$clock,'SIMULATED_TEST_ONLY',1,1,100,100,100,110,$true,'{"host":{},"HOST":{}}')
$null=Deliver $ctx $duplicate;$out=Get-WlbPreparedSupervisorDecision $ctx $policy $base $p 200
Check 'DUPLICATE-JSON-KEY-FAIL-CLOSED' $out ($out.metadata.Terminal -and $out.metadata.Reason -match 'Duplicate/case-colliding')
foreach($case in @('CLOCK','ACQUISITION')){
 $value=Copy-IObject $sample
 if($case -eq 'CLOCK'){$value.clock_id='FOREIGN_PAYLOAD_CLOCK'}else{$value.start_ms=[long]101;$value.collection_ms=[long]9}
 $ctx=Context;$null=Deliver $ctx (Env $value);$out=Get-WlbPreparedSupervisorDecision $ctx $policy $base $p 200
 Check ('ENVELOPE-PAYLOAD-'+$case+'-COUPLING') $out ($out.metadata.Terminal -and $out.metadata.Reason -match ('ENVELOPE_PAYLOAD_'+$case+'_MISMATCH'))
}
Reject 'FAILED-WORKER-CANNOT-RETRY' {Invoke-WlbPreparedWorkerTick ([pscustomobject]@{failed=$true}) $null} 'automatic retry disabled'
Reject 'WORKER-CADENCE-NOT-AUTHORIZED-OTHER-VALUE' {New-WlbPreparedWorkerState $TestWorkerIdentity $clock 424242 0 501 1000} 'Only experimental worker candidates'
$skip=Invoke-WlbPreparedWorkerTick ([pscustomobject]@{failed=$false;sequence=[long]1;last_fast_ms=(Get-WlbSupervisorMonotonicMs);fast_ms=500}) $null
Check 'WORKER-NOT-DUE-NO-PROVIDER-CALL' $skip (-not $skip.collected -and $skip.reason -ceq 'EXPERIMENTAL_FAST_NOT_DUE')
$exact=Copy-IObject $sample;$exact.gpu.global.used_bytes=[long](3GB);$exact.gpu.global.free_bytes=[long](13GB)
$out=Test-WlbPreparedGpuProxy $policy $base $exact 0 200
Check 'PROXY-2GIB-EXACT-PREPARATION-ONLY' $out ($out.threshold_state -ceq 'PREPARATION_THRESHOLDS_ONLY' -and -not $out.enabled_in_policy -and -not $out.authorized_to_execute -and -not $out.global_delta_is_pid_attribution)
$proxyCases=[ordered]@{
 'VRAM-OVER2'={param($s)$s.gpu.global.used_bytes=[long](3GB+1);$s.gpu.global.free_bytes=[long](13GB-1)}
 'G5'={param($s)$s.preparation_scope='G5'}
 'ALPHA'={param($s)$s.preparation_scope='ALPHA'}
 'MODELS'={param($s)$s.models_requested=$true}
 'RTX-UUID-CHANGED'={param($s)$s.gpu.global.uuid='GPU-00000000-0000-0000-0000-000000000002'}
 'RTX-NAME-CHANGED'={param($s)$s.gpu.global.name='FOREIGN_GPU'}
 'UNKNOWN-CONTENTION'={param($s)$s.concurrency.exclusivity_proven=$false}
 'ACTORS-CHANGED'={param($s)$s.concurrency.actor_set_identity='4'*64}
 'GPU-UNAVAILABLE'={param($s)$s.gpu.status='UNAVAILABLE'}
 'GPU-INCONSISTENT'={param($s)$s.gpu.global.free_bytes=[long](16GB)}
 'GPU-NONINTEGER'={param($s)$s.gpu.global.used_bytes='1073741824'}
 'PROVIDER-UNKNOWN'={param($s)$s.source_generation_freshness='NOT_VERIFIED'}
 'GPU-COUNTER-DECREASE'={param($s)$s.gpu.global.used_bytes=[long]0}
}
foreach($entry in $proxyCases.GetEnumerator()){$value=Copy-IObject $sample;& $entry.Value $value;$out=Test-WlbPreparedGpuProxy $policy $base $value 0 200;Check ('PROXY-'+$entry.Key) $out ($out.threshold_state -ceq 'BLOCKED' -and -not $out.authorized_to_execute)}
$out=Test-WlbPreparedGpuProxy $policy $base $sample 0 2101;Check 'PROXY-STALE-RECEIPT' $out ($out.reasons -contains 'PROXY_ACQUISITION_RECEIPT_STALE')
$late=Copy-IObject $sample;$late.start_ms=[long]119900;$late.end_ms=[long]119910
$out=Test-WlbPreparedGpuProxy $policy $base $late 0 120000;Check 'PROXY-120S-DEADLINE' $out ($out.reasons -contains 'PROXY_STARTUP_DEADLINE_120S')
$wrongBase=Copy-IObject $base;$wrongBase.start_ms=[long]1;$out=Test-WlbPreparedGpuProxy $policy $wrongBase $sample 0 200
Check 'PROXY-HISTORICAL-BASELINE-NOT-IMMEDIATE' $out ($out.threshold_state -ceq 'BLOCKED')
Save-INew ('contracts-'+$Run+'.json') @($rows)
$summary=@{tests=$rows.Count;pass=@($rows|Where-Object status -eq PASS).Count;fail=@($rows|Where-Object status -eq FAIL).Count;all_cases_authorize_startup=$false;real_process_started=$false;real_process_killed=$false;real_consent=$false}
Save-INew ('contracts-'+$Run+'-summary.json') $summary;$summary|ConvertTo-Json
if($summary.fail){$rows|Where-Object status -eq FAIL|ConvertTo-Json -Depth 8;exit 1}
