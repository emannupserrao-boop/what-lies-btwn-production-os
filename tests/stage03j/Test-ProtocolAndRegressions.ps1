#requires -Version 7.6
param([ValidatePattern('^[a-z0-9-]+$')][string]$RunLabel='checks01',[ValidatePattern('^[a-z0-9-]+$')][string]$RealRun='run05')
. (Join-Path $PSScriptRoot 'J.Common.ps1')
. (Join-Path $JRoot 'core\Wlb.WorkerProcess.ps1')
Initialize-WlbJProcessTypes
$script:checks=[Collections.Generic.List[object]]::new()
function Check-J([string]$Case,[string]$Kind,[scriptblock]$Body){
 try{$value=& $Body;if($value -isnot [bool] -or -not $value){throw ('Expected true, got '+($value|ConvertTo-Json -Depth 4 -Compress))};$status='PASS';$detail='Expected behavior verified'}catch{$status='FAIL';$detail=$_.Exception.Message}
 $script:checks.Add(@{id=$Case;kind=$Kind;status=$status;detail=$detail})
}
$real=Read-JJson (Join-Path $JEvidence ($RealRun+'-real-index.json'))
$normal=@($real|Where-Object {$_.case -eq 'normal-passive'})[0]
foreach($r in $real){
 $caseName=$r.case
 Check-J ($caseName+'-separate-pid') REAL_OWNED_PROCESS { $r.lease.process_id -ne $r.supervisor_pid -and $r.lease.metadata_verified -and $r.lease.held_creation_handle -and $r.lease.created_by_this_attempt }
 Check-J ($caseName+'-clock-proof') REAL_OWNED_PROCESS { $r.clock_proof.verified -and $r.clock_proof.roundtrip_ms -le 500 }
 Check-J ($caseName+'-bounded-monotonic-ticks') REAL_OWNED_PROCESS {
  $previous=[long]0;$valid=$r.ticks.Count -gt 10 -and $r.ticks.Count -le 2048
  foreach($tick in $r.ticks){if($tick.now_ms -lt $previous -or $tick.authorized_to_execute){$valid=$false};$previous=$tick.now_ms};$valid
 }
 Check-J ($caseName+'-reconciled-exit') REAL_OWNED_PROCESS { $r.lease.exited -and $null -eq $r.failure }
 Check-J ($caseName+'-worker-or-channel-terminal') REAL_OWNED_PROCESS { $null -ne $r.first_terminal -and $r.first_terminal.terminal }
}
$finite=@($real|Where-Object {$_.case -eq 'finite-delay-and-denials'})[0]
$hang=@($real|Where-Object {$_.case -eq 'hang-short-timeout'})[0]
$hb=@($real|Where-Object {$_.case -eq 'heartbeat-interruption'})[0]
$crash=@($real|Where-Object {$_.case -eq 'controlled-failure'})[0]
$channel=@($real|Where-Object {$_.case -eq 'channel-closed'})[0]
Check-J 'normal-exit0-live-minimal-sample' REAL_OWNED_PROCESS { $normal.lease.exit_code -eq 0 -and $normal.samples.Count -eq 1 -and $normal.bye_received -and $null -eq $normal.stop }
Check-J 'live-provider-generation-remains-unknown' REAL_OWNED_PROCESS { $normal.strict_sample_decision.Reason -eq 'PROVIDER_GENERATION_AGE_UNKNOWN' -and -not $normal.strict_sample_decision.AuthorizedToExecute }
Check-J 'finite-exit0-without-termination' REAL_OWNED_PROCESS { $finite.lease.exit_code -eq 0 -and $null -eq $finite.stop -and $finite.bye_received }
foreach($denial in $finite.denials){Check-J ('actual-denial-'+($finite.denials.IndexOf($denial)+1)) REAL_DENIAL_ON_OWNED_HELPER { -not $denial.Allowed -and -not $denial.TerminationRequested }}
Check-J 'real-short-deadline-before-hang-completion' REAL_OWNED_PROCESS { $hang.first_terminal.reason -eq 'OWNED_HELPER_TEST_TIMEOUT_NOT_G4_BUDGET' -and $hang.first_terminal.worker_alive -and $hang.first_terminal.now_ms-$hang.proof_receipt_ms -ge 750 -and $hang.first_terminal.now_ms-$hang.proof_receipt_ms -lt 1500 -and $hang.stop.TerminationRequested -and $hang.lease.exit_code -eq 197 }
Check-J 'real-heartbeat-loss-before-worker-completion' REAL_OWNED_PROCESS { $hb.first_terminal.reason -eq 'WORKER_HEARTBEAT_ABSENT_OR_STALE' -and $hb.first_terminal.worker_alive -and $hb.stop.TerminationRequested -and $hb.lease.exit_code -eq 197 }
Check-J 'controlled-crash-exit23-without-kill' REAL_OWNED_PROCESS { $crash.lease.exit_code -eq 23 -and $null -eq $crash.stop -and $crash.channel_failed }
Check-J 'real-channel-loss-owned-termination' REAL_OWNED_PROCESS { $channel.channel_failed -and $channel.first_terminal.reason -eq 'CHANNEL_CLOSED_OR_FAILED' -and $channel.stop.TerminationRequested -and $channel.lease.exit_code -eq 197 }
Check-J 'partial-attempts-preserved-not-final-passes' STORED_STAGE03J_FAILURE { (Test-Path -LiteralPath (Join-Path $JEvidence 'run01-real-index.json')) -and (Test-Path -LiteralPath (Join-Path $JEvidence 'run02-real-index.json')) -and (Test-Path -LiteralPath (Join-Path $JEvidence 'source-run01-workerprocess.ps1')) }

function New-FixtureState {
 $l=$normal.lease
 $lease=[pscustomobject]@{ProcessId=[int]$l.process_id;CreationFileTime=[long]$l.creation_filetime;CreationTimeUtc=$l.creation_time_utc;ExecutablePath=$l.image_path;ExecutableSha256=$l.image_sha256;HelperSha256=$l.helper_sha256;Mode='NORMAL_EXIT'}
 $attempt=[pscustomobject]@{id=[guid]::NewGuid().ToString('D');nonce=('a'*64);session_id=[guid]::NewGuid().ToString('D');lease=$lease}
 $state=New-WlbJProtocolState $attempt
 $state.started_ms=[long]1000;$state.child_clock=[guid]::NewGuid().ToString('D');$state.last_sequence=[long]2;$state.last_produced_ms=[long]1000;$state.clock_verified=$true;$state.last_heartbeat_ms=[long]1000
 $state
}
function New-FixtureMessage($State,[string]$Kind='SAMPLE'){
 $payload=@{clock_id=$State.session_id;start_ms=[long]1000;end_ms=[long]1100;source_generation_freshness='NOT_VERIFIED';authorized_to_execute=$false}
 $body=if($Kind -eq 'SAMPLE'){@{ClockId=$State.session_id;WorkerIdentity=$State.worker_identity;Sequence=[long]1;SlowSequence=[long]1;RequestStartedMs=[long]1000;FastAcquiredMs=[long]1000;SlowAcquiredMs=[long]1000;CollectionCompletedMs=[long]1100;ProviderGenerationVerified=$false;EvidenceKind='PASSIVE_PREPARATION_ONLY';PayloadJson=ConvertTo-Json -InputObject $payload -Compress}}else{@{}}
 @{schema='wlb-stage03j-ipc/0.1';attempt_id=$State.attempt_id;nonce=$State.nonce;worker_identity=$State.worker_identity;sequence=[long]3;kind=$Kind;worker_clock_id=$State.child_clock;produced_ms=[long]1100;body=$body}
}
function Reject-Fixture([string]$Case,[scriptblock]$Mutate,[string]$Pattern){
 Check-J $Case SIMULATED_IPC {
  $state=New-FixtureState;$message=New-FixtureMessage $state
  & $Mutate $state $message
  try{$null=Receive-WlbJMessage $state (ConvertTo-Json -InputObject $message -Depth 20 -Compress) 1200 12000000;return $false}catch{$first=$_.Exception.Message}
  $latched=$false;try{$null=Receive-WlbJMessage $state '{}' 1201 12010000}catch{$latched=$_.Exception.Message -match 'TERMINAL_NO_RETRY'}
  $state.terminal -and $first -match $Pattern -and $latched -and -not $state.authorized_to_execute
 }
}
Check-J 'sim-valid-sample-original-acquisition' SIMULATED_IPC {$s=New-FixtureState;$m=New-FixtureMessage $s;$a=Receive-WlbJMessage $s (ConvertTo-Json $m -Depth 20 -Compress) 1200 12000000;$s.pending_sample.Sequence -eq 1 -and $s.last_acquired_ms -eq 1000 -and $a.received_ms -eq 1200 -and -not $a.authorized_to_execute}
Reject-Fixture 'wrong-attempt' {$args[1].attempt_id=[guid]::NewGuid().ToString('D')} 'ATTEMPT_NONCE'
Reject-Fixture 'wrong-nonce' {$args[1].nonce='b'*64} 'ATTEMPT_NONCE'
Reject-Fixture 'wrong-worker' {$args[1].worker_identity='b'*64} 'WORKER_IDENTITY'
Reject-Fixture 'duplicate-sequence' {$args[1].sequence=[long]2} 'DUPLICATE_REPLAY_OR_ORDER'
Reject-Fixture 'out-of-order-sequence' {$args[1].sequence=[long]4} 'DUPLICATE_REPLAY_OR_ORDER'
Reject-Fixture 'sequence-string' {$args[1].sequence='3'} 'Expected JSON Integer'
Reject-Fixture 'future-message' {$args[1].produced_ms=[long]1201} 'FUTURE_OR_REVERSED'
Reject-Fixture 'reversed-message' {$args[1].produced_ms=[long]999} 'FUTURE_OR_REVERSED'
Reject-Fixture 'worker-clock-changed' {$args[1].worker_clock_id=[guid]::NewGuid().ToString('D')} 'CHILD_CLOCK_CHANGED'
Reject-Fixture 'sample-before-clock-negotiation' {$args[0].clock_verified=$false} 'CLOCK_NOT_NEGOTIATED'
Reject-Fixture 'envelope-clock-changed' {$args[1].body.ClockId=[guid]::NewGuid().ToString('D')} 'ENVELOPE_IDENTITY'
Reject-Fixture 'provider-verification-forged' {$args[1].body.ProviderGenerationVerified=$true} 'GENERATION'
Reject-Fixture 'simulated-as-live' {$args[1].body.EvidenceKind='SIMULATED_TEST_ONLY'} 'GENERATION'
Reject-Fixture 'future-collection' {$args[1].body.CollectionCompletedMs=[long]1300} 'ACQUISITION_OR_FUTURE'
Reject-Fixture 'collection-after-production' {$args[1].body.CollectionCompletedMs=[long]1150} 'COLLECTION_AFTER_PRODUCTION'
Reject-Fixture 'fast-before-request' {$args[1].body.FastAcquiredMs=[long]999} 'ACQUISITION_OR_FUTURE'
Reject-Fixture 'envelope-sequence-gap' {$args[1].body.Sequence=[long]2} 'ENVELOPE_IDENTITY_SEQUENCE'
Reject-Fixture 'slow-sequence-gap' {$args[1].body.SlowSequence=[long]2} 'SLOW_CACHE'
Reject-Fixture 'unexpected-wire-property' {$args[1].extra=$false} 'Unexpected|keys|shape|Unknown'
Reject-Fixture 'unexpected-envelope-property' {$args[1].body.extra=$false} 'Unexpected|keys|shape|Unknown'
Reject-Fixture 'wrong-kind' {$args[1].kind='START_RUNTIME'} 'KIND_DENIED'
Reject-Fixture 'payload-clock-mismatch' {$p=Read-WlbJWireJson $args[1].body.PayloadJson;$p.clock_id='unnegotiated';$args[1].body.PayloadJson=ConvertTo-Json $p -Compress} 'PAYLOAD_CLOCK'
Reject-Fixture 'payload-generation-age-fabricated' {$p=Read-WlbJWireJson $args[1].body.PayloadJson;$p.source_generation_freshness='VERIFIED';$args[1].body.PayloadJson=ConvertTo-Json $p -Compress} 'PAYLOAD_CLOCK_ACQUISITION_OR_GENERATION'
Reject-Fixture 'payload-authority-forged' {$p=Read-WlbJWireJson $args[1].body.PayloadJson;$p.authorized_to_execute=$true;$args[1].body.PayloadJson=ConvertTo-Json $p -Compress} 'CANNOT_AUTHORIZE'
Reject-Fixture 'mailbox-second-sample-rejected' {$s=$args[0];$m=$args[1];$null=Receive-WlbJMessage $s (ConvertTo-Json $m -Depth 20 -Compress) 1200 12000000;$m.sequence=[long]4;$m.body.Sequence=[long]2} 'ONE_SAMPLE_MAX'
Reject-Fixture 'slow-cache-timestamp-rewritten' {$s=$args[0];$m=$args[1];$null=Receive-WlbJMessage $s (ConvertTo-Json $m -Depth 20 -Compress) 1200 12000000;$s.pending_sample=$null;$m.sequence=[long]4;$m.body.Sequence=[long]2;$m.body.SlowAcquiredMs=[long]1001} 'SLOW_CACHE'
Reject-Fixture 'fast-clock-reversed' {$s=$args[0];$s.last_fast_ms=[long]1001} 'FAST_REVERSED'
Check-J 'cached-slow-age-retained' SIMULATED_IPC {
 $s=New-FixtureState;$m=New-FixtureMessage $s;$null=Receive-WlbJMessage $s (ConvertTo-Json $m -Depth 20 -Compress) 1200 12000000;$s.pending_sample=$null
 $m.sequence=[long]4;$m.produced_ms=[long]1300;$m.body.Sequence=[long]2;$m.body.RequestStartedMs=[long]1200;$m.body.FastAcquiredMs=[long]1200;$m.body.CollectionCompletedMs=[long]1300
 $p=Read-WlbJWireJson $m.body.PayloadJson;$p.end_ms=[long]1300;$m.body.PayloadJson=ConvertTo-Json $p -Compress
 $null=Receive-WlbJMessage $s (ConvertTo-Json $m -Depth 20 -Compress) 1400 14000000;$s.last_acquired_ms -eq 1000 -and $s.last_slow_ms -eq 1000 -and $s.slow_sequence -eq 1
}
foreach($badJson in @('{"nonce":"a","nonce":"b"}','{"Nonce":"a","nonce":"b"}','{"x":{"q":1,"q":2}}','{"x":')){Check-J ('json-reject-'+($badJson.GetHashCode().ToString())) SIMULATED_IPC {try{$null=Read-WlbJWireJson $badJson;$false}catch{$true}}}
function Read-FixtureBytes([byte[]]$Bytes){$stream=[IO.MemoryStream]::new($Bytes,$false);try{$task=[WlbOwnedJ.Framing]::ReadAsync($stream);$task.GetAwaiter().GetResult()}finally{$stream.Dispose()}}
Check-J 'framing-valid-roundtrip' SIMULATED_BYTES {(Read-FixtureBytes ([WlbOwnedJ.Framing]::Encode('{"ok":true}'))) -ceq '{"ok":true}'}
foreach($pair in @(@('truncated-header',[byte[]]@(2,0)),@('truncated-body',[byte[]]@(5,0,0,0,123,125)),@('empty-body',[byte[]]@(2,0,0,0)),@('zero-length',[byte[]]@(0,0,0,0)),@('oversized-header',[BitConverter]::GetBytes([uint32]65537)),@('invalid-utf8',[byte[]]@(2,0,0,0,255,255)),@('eof',[byte[]]@()))){Check-J ('framing-'+$pair[0]) SIMULATED_BYTES {try{$null=Read-FixtureBytes $pair[1];$false}catch{$true}}}
Check-J 'framing-write-size-bound' SIMULATED_BYTES {try{$null=[WlbOwnedJ.Framing]::Encode('x'*65537);$false}catch{$true}}
Check-J 'framing-read-one-leaves-next-pending' SIMULATED_BYTES {$a=[WlbOwnedJ.Framing]::Encode('{}');$stream=[IO.MemoryStream]::new([byte[]]($a+$a));try{$first=[WlbOwnedJ.Framing]::ReadAsync($stream).GetAwaiter().GetResult();$first -ceq '{}' -and $stream.Position -eq $a.Length}finally{$stream.Dispose()}}
$frequency=[Diagnostics.Stopwatch]::Frequency;$challenge='fixture-challenge';$session=[guid]::NewGuid().ToString('D')
$proof=@{frequency=[long]$frequency;received_ticks=[long]100100;sent_ticks=[long]100200;challenge=$challenge;session_id=$session}
Check-J 'clock-proof-valid-independent-session' SIMULATED_CLOCK {Assert-WlbJClockProof $proof 100000 100300 $frequency $challenge $session;$true}
foreach($entry in @(@('frequency-mismatch','frequency',[long]($frequency+1)),@('epoch-before-parent','received_ticks',[long]90000),@('epoch-after-parent','sent_ticks',[long]100400),@('reversed-child','sent_ticks',[long]100000),@('challenge-mismatch','challenge','wrong'),@('session-mismatch','session_id','wrong'))){Check-J ('clock-'+$entry[0]) SIMULATED_CLOCK {$p=Copy-JObject $proof;$p[$entry[1]]=$entry[2];try{Assert-WlbJClockProof $p 100000 100300 $frequency $challenge $session;$false}catch{$true}}}
Check-J 'clock-roundtrip-over500ms' SIMULATED_CLOCK {try{Assert-WlbJClockProof $proof 100000 (100000+$frequency) $frequency $challenge $session;$false}catch{$true}}
Check-J 'clock-1tick-cross-thread-tolerance' SIMULATED_CLOCK {$p=Copy-JObject $proof;$p.received_ticks=[long]99999;$p.sent_ticks=[long]100301;Assert-WlbJClockProof $p 100000 100300 $frequency $challenge $session;$true}
Check-J 'injected-deadline-exact120s' SIMULATED_CLOCK {$s=New-FixtureState;$s.clock_verified=$false;$before=Get-WlbJWatchdogDecision $s 120999 $false $false;$after=Get-WlbJWatchdogDecision $s 121000 $false $false; -not $before.terminal -and $after.reason -ceq 'FUTURE_G4_DEADLINE_120S' -and $after.g4_deadline_ms -eq 121000 -and -not $after.authorized_to_execute}
Check-J 'injected-short-timeout-keeps-g4-budget' SIMULATED_CLOCK {$s=New-FixtureState;$d=Get-WlbJWatchdogDecision $s 1750 $false $false 750;$d.terminal -and $d.reason -eq 'OWNED_HELPER_TEST_TIMEOUT_NOT_G4_BUDGET' -and $d.g4_deadline_ms -eq 121000}
Check-J 'heartbeat-does-not-renew-consumed-acquisition' SIMULATED_IPC {$s=New-FixtureState;$m=New-FixtureMessage $s;$null=Receive-WlbJMessage $s (ConvertTo-Json $m -Depth 20 -Compress) 1200 12000000;$s.pending_sample=$null;$s.last_heartbeat_ms=[long]3101;$d=Get-WlbJWatchdogDecision $s 3101 $false $false;$d.reason -eq 'ACQUISITION_RECEIPT_AGE_EXCEEDED' -and $d.provider_generation_age -eq 'UNKNOWN'}
Check-J 'supervisor-clock-reversal-terminal' SIMULATED_CLOCK {$s=New-FixtureState;$null=Get-WlbJWatchdogDecision $s 1100 $false $false;$d=Get-WlbJWatchdogDecision $s 1099 $false $false;$d.reason -eq 'SUPERVISOR_CLOCK_REVERSED'}
Check-J 'terminal-latched-no-retry' SIMULATED_IPC {$s=New-FixtureState;$d=Get-WlbJWatchdogDecision $s 1100 $true $false;$e=Get-WlbJWatchdogDecision $s 1101 $false $false;$e.terminal -and $e.reason -eq 'WORKER_EXITED' -and -not $e.restart_allowed}
Check-J 'simulated-lease-cannot-stop' SIMULATED_LIFECYCLE {$d=[WlbOwnedJ.Lifecycle]::Stop($null,[guid]::NewGuid().ToString('D'),('a'*64),$null,'TEST_TIMEOUT');-not $d.Allowed -and -not $d.TerminationRequested -and -not $d.ProductionStopAuthority}
Check-J 'invalid-launch-mode-refused-before-create' SIMULATED_LIFECYCLE {try{$null=[WlbOwnedJ.Lifecycle]::Start([guid]::NewGuid().ToString('D'),('a'*64),'ARBITRARY_COMMAND',('a'*64),'wrong',[guid]::NewGuid().ToString('D'));$false}catch{$true}}
$policy=Read-WlbJson (Join-Path $JRoot 'policy\startup-policy.json');$lock=Read-WlbJson (Join-Path $JRoot 'policy\runtime-lock.json');$manifest=Read-WlbJson (Join-Path $JRoot 'manifests\draft\POC0-CALIBRATION-001.json');$executor=Read-WlbJson (Join-Path $JRoot 'policy\executor-policy.json')
Check-J '21-prepared-pins-match' RELEVANT_REGRESSION {$valid=$lock.prepared_artifacts.Count -eq 21;foreach($entry in $lock.prepared_artifacts.GetEnumerator()){if((Get-WlbHash (Join-Path $JRoot $entry.Key)) -cne $entry.Value){$valid=$false}};$valid}
Check-J 'four-human-parameters-still-unknown-null' RELEVANT_REGRESSION {$valid=$policy.human_parameters.Count -eq 4;foreach($p in $policy.human_parameters.Values){if($p.status -cne 'UNKNOWN' -or $null -ne $p.value){$valid=$false}};$valid}
Check-J 'policy-gates-false-and-consent-absent' RELEVANT_REGRESSION {-not $policy.real_startup_enabled -and -not $policy.gpu_jobs_enabled -and -not $policy.auto_retry -and -not $executor.execution_enabled -and $policy.consent_status -eq 'ABSENT' -and $manifest.state -eq 'DRAFT' -and -not $manifest.approval_contract.record_created}
Check-J 'static-review-pass-not-executable' RELEVANT_REGRESSION {$r=& (Join-Path $JRoot 'core\Test-WlbManifest.ps1') -Mode StaticReview;$r.review -eq 'STATIC_CONTRACT_CHECK_ONLY' -and -not $r.executable}
Check-J 'execution-eligibility-refused' RELEVANT_REGRESSION {try{$null=& (Join-Path $JRoot 'core\Test-WlbManifest.ps1') -Mode ExecutionEligibility;$false}catch{$_.Exception.Message -match 'BLOCKED'}}
Check-J 'g4-plan-snapshot619-staged-not-started' RELEVANT_REGRESSION {$p=& (Join-Path $JRoot 'core\Start-WlbRuntime.ps1') -Mode Plan;Save-JNew ($RunLabel+'-g4-plan.json') $p;$p.snapshot_state -eq 'STAGED_NOT_ACTIVATED' -and -not $p.startup_performed -and $p.state -match 'BLOCKED'}
Check-J 'g4-admission-refused' RELEVANT_REGRESSION {try{$null=& (Join-Path $JRoot 'core\Start-WlbRuntime.ps1') -Mode Admission;$false}catch{$_.Exception.Message -match 'BLOCKED'}}
Check-J 'g5-empty-approval-refused-no-record' RELEVANT_REGRESSION {try{$null=& (Join-Path $JRoot 'core\Invoke-WlbJob.ps1') -ApprovalId ([guid]::Empty);$false}catch{$_.Exception.Message -match 'Existing human approval required'}}
$caps=@{min_available_ram_gib=8;min_commit_headroom_gib=10;max_incremental_commit_gib=4;max_process_private_gib=4;max_incremental_vram_gib=2;startup_timeout_seconds=120;job_timeout_seconds=30;output_log_cap_mib=256}
Check-J 'unchanged-eight-resource-budget-values' RELEVANT_REGRESSION {$valid=$true;foreach($key in $caps.Keys){if($policy.budget[$key] -ne $caps[$key] -or $manifest.budget[$key] -ne $caps[$key]){$valid=$false}};$valid}
Check-J 'new-process-components-not-in-g4-entrypoint' RELEVANT_REGRESSION {$source=Get-Content -LiteralPath (Join-Path $JRoot 'core\Start-WlbRuntime.ps1') -Raw;$source -notmatch 'Wlb.WorkerProcess|Start-WlbJ|OwnedTelemetryWorker'}
$counts=@{pass=@($script:checks|Where-Object {$_.status -eq 'PASS'}).Count;fail=@($script:checks|Where-Object {$_.status -eq 'FAIL'}).Count}
Save-JNew ($RunLabel+'-checks.json') @($script:checks)
$counts|ConvertTo-Json
@($script:checks|Where-Object {$_.status -eq 'FAIL'})|ConvertTo-Json
if($counts.fail){exit 1}
