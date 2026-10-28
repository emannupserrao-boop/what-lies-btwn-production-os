#requires -Version 7.6
param([ValidatePattern('^run[1-9][0-9]?$')][string]$Run='run2')
. (Join-Path $PSScriptRoot 'I.Common.ps1')
. (Join-Path $IRoot 'core\Wlb.TelemetryWorker.ps1')
Initialize-WlbSupervisionTypes
$results=[Collections.Generic.List[object]]::new();$experiments=[Collections.Generic.List[object]]::new()
function Row($id,$actual,$ok,$kind){$results.Add([pscustomobject]@{id=$id;status=$(if($ok){'PASS'}else{'FAIL'});actual=$actual;evidence_kind=$kind})}
$self=Get-WlbPassiveProcessObservation $PID;$identity=Get-WlbWorkerObservationFingerprint $self
foreach($delay in @(300,2800)){
 $clock=[guid]::NewGuid().ToString('D');$start=Get-WlbSupervisorMonotonicMs;$ctx=New-WlbPreparedSupervisor $identity $clock 'SIMULATED_TEST_ONLY' $start
 $helper=Join-Path $PSScriptRoot 'BenignDelayWorker.ps1';$runner=[Management.Automation.PowerShell]::Create()
 $null=$runner.AddScript((Get-Content -LiteralPath $helper -Raw)).AddArgument($ctx.Mailbox).AddArgument($identity).AddArgument($clock).AddArgument($delay)
 $async=$runner.BeginInvoke();$ticks=[Collections.Generic.List[object]]::new();$blockedBeforeCompletion=$false;$firstBlocked=$null
 while((Get-WlbSupervisorMonotonicMs)-$start -lt 6500){
  $t=[Diagnostics.Stopwatch]::StartNew();$decision=$ctx.Tick((Get-WlbSupervisorMonotonicMs));$cost=$t.Elapsed.TotalMilliseconds
  $ticks.Add([pscustomobject]@{elapsed_ms=(Get-WlbSupervisorMonotonicMs)-$start;tick_cost_ms=$cost;telemetry_state=$decision.TelemetryState;reason=$decision.Reason;worker_completed=$async.IsCompleted})
  if($decision.Terminal -and -not $async.IsCompleted){$blockedBeforeCompletion=$true;if($null -eq $firstBlocked){$firstBlocked=(Get-WlbSupervisorMonotonicMs)-$start}}
  if($async.IsCompleted){break};Start-Sleep -Milliseconds 20
 }
 $output=@();$errors=@();$natural=$false
 if($async.IsCompleted){$output=@($runner.EndInvoke($async));$errors=@($runner.Streams.Error|ForEach-Object {$_.ToString()});$natural=@($output|Where-Object {$_.PSObject.Properties.Name -contains 'completed_naturally' -and $_.completed_naturally}).Count -eq 1;$runner.Dispose()}
 $experiment=@{delay_ms=$delay;started_ms=$start;helper_path=$helper;helper_sha256=(Get-FileHash -LiteralPath $helper).Hash.ToLowerInvariant();worker_identity=$self;ticks=@($ticks);first_blocked_elapsed_ms=$firstBlocked;blocked_before_worker_completion=$blockedBeforeCompletion;completed_naturally=$natural;output=$output;errors=$errors;no_cancellation_or_kill=$true;real_query_hang_tested=$false;runtime_watchdog_verified=$false}
 $experiments.Add($experiment)
 Row ('ASYNC-FINITE-'+$delay+'-NATURAL-COMPLETION') @{natural=$natural;errors=$errors;ticks=$ticks.Count} ($natural -and $errors.Count -eq 0 -and $ticks.Count -gt 1) 'REAL_RUNSPACE_AND_QPC_SIMULATED_PROVIDER_DELAY'
 if($delay -eq 2800){Row 'ASYNC-BLOCK-DETECTED-BEFORE-SIMULATED-QUERY-FINISH' @{first_blocked_ms=$firstBlocked;before_finish=$blockedBeforeCompletion;max_tick_ms=($ticks.tick_cost_ms|Measure-Object -Maximum).Maximum} ($blockedBeforeCompletion -and $firstBlocked -lt 2800) 'REAL_ELAPSED_RUNSPACE_WITH_FINITE_HANG_FIXTURE'}
}
# One actual passive envelope through the independent supervisor. Unknown source
# age must block; no lifecycle or watchdog operation is inferred from this test.
$clock=[guid]::NewGuid().ToString('D');$start=Get-WlbSupervisorMonotonicMs;$ctx=New-WlbPreparedSupervisor $identity $clock 'PASSIVE_PREPARATION_ONLY' $start
$helper=Join-Path $PSScriptRoot 'PassiveWorkerHarness.ps1';$runner=[Management.Automation.PowerShell]::Create()
$null=$runner.AddScript((Get-Content -LiteralPath $helper -Raw)).AddArgument($ctx.Mailbox).AddArgument($identity).AddArgument($clock).AddArgument($start).AddArgument(1)
$async=$runner.BeginInvoke();$ticks=[Collections.Generic.List[object]]::new();$observedEnvelope=$null;$last=$null
while((Get-WlbSupervisorMonotonicMs)-$start -lt 6500){
 $timer=[Diagnostics.Stopwatch]::StartNew();$last=$ctx.Tick((Get-WlbSupervisorMonotonicMs));$cost=$timer.Elapsed.TotalMilliseconds
 if($last.ObservedEnvelope){$observedEnvelope=$last.ObservedEnvelope}
 $ticks.Add([pscustomobject]@{elapsed_ms=(Get-WlbSupervisorMonotonicMs)-$start;tick_cost_ms=$cost;state=$last.TelemetryState;reason=$last.Reason;worker_completed=$async.IsCompleted})
 if($async.IsCompleted -and $observedEnvelope){break};Start-Sleep -Milliseconds 20
}
$out=@();$errors=@();$natural=$false;if($async.IsCompleted){$out=@($runner.EndInvoke($async));$errors=@($runner.Streams.Error|ForEach-Object {$_.ToString()});$natural=@($out|Where-Object {$_.PSObject.Properties.Name -contains 'completed_naturally' -and $_.completed_naturally}).Count -eq 1;$runner.Dispose()}
Save-INew ('asynchronous-supervisor-passive-'+$Run+'.json') @{started_ms=$start;ticks=@($ticks);envelope=$observedEnvelope;decision=$last;worker_output=$out;worker_errors=$errors;completed_naturally=$natural;runtime_watchdog_verified=$false;real_process_control=$false}
$failedOutput=@($out|Where-Object {$_.PSObject.Properties.Name -contains 'failed' -and $_.failed})
Row 'REAL-PASSIVE-WORKER-NATURAL-FINISH' @{natural=$natural;errors=$errors;output=$out;sample_available=($null -ne $observedEnvelope)} ($natural -and $errors.Count -eq 0 -and ($null -ne $observedEnvelope -or $failedOutput.Count -gt 0)) 'REAL_PASSIVE_RUNSPACE_NO_RUNTIME'
Row 'REAL-PASSIVE-DECISION-FAIL-CLOSED' $last ($last.Terminal -and $last.Reason -in @('PROVIDER_GENERATION_AGE_UNKNOWN','TELEMETRY_MISSING','WORKER_READ_FAILED','WORKER_HEARTBEAT_EXPIRED','WORKER_HEARTBEAT_MISSING') -and -not $last.AuthorizedToExecute) 'REAL_PASSIVE_NO_G4_AUTHORITY'
# Four finite passive samples with a neutral bounded consumer for timing only.
# No metadata/proxy exception is used to make the supervisor accept these samples.
$clock=[guid]::NewGuid().ToString('D');$start=Get-WlbSupervisorMonotonicMs;$box=[WlbSupervision.Mailbox]::new($identity,$clock);$runner=[Management.Automation.PowerShell]::Create()
$null=$runner.AddScript((Get-Content -LiteralPath $helper -Raw)).AddArgument($box).AddArgument($identity).AddArgument($clock).AddArgument($start).AddArgument(4)
$cpu=[Diagnostics.Process]::GetCurrentProcess();$cpuStart=$cpu.TotalProcessorTime.TotalMilliseconds
$async=$runner.BeginInvoke();$receipts=[Collections.Generic.List[object]]::new();$pollCosts=[Collections.Generic.List[double]]::new()
while((Get-WlbSupervisorMonotonicMs)-$start -lt 6500){
 $env=$null;$beat=$null;$timer=[Diagnostics.Stopwatch]::StartNew();$ok=$box.TryRead([ref]$env,[ref]$beat);$pollCosts.Add($timer.Elapsed.TotalMilliseconds)
 if($env){$receipts.Add(@{supervisor_received_ms=(Get-WlbSupervisorMonotonicMs);envelope=$env})}
 if($async.IsCompleted -and ($receipts.Count -eq 4 -or $box.Fault)){break};Start-Sleep -Milliseconds 20
}
$out=@();$errors=@();$natural=$false;if($async.IsCompleted){$out=@($runner.EndInvoke($async));$errors=@($runner.Streams.Error|ForEach-Object {$_.ToString()});$natural=@($out|Where-Object {$_.PSObject.Properties.Name -contains 'completed_naturally' -and $_.completed_naturally}).Count -eq 1;$runner.Dispose()}
$cpu.Refresh();$cpuDelta=$cpu.TotalProcessorTime.TotalMilliseconds-$cpuStart;$cpu.Dispose()
Save-INew ('passive-worker-sampling-'+$Run+'.json') @{started_ms=$start;elapsed_ms=(Get-WlbSupervisorMonotonicMs)-$start;worker_output=$out;worker_errors=$errors;receipts=@($receipts);consumer_poll_cost_ms=@($pollCosts);process_cpu_ms=$cpuDelta;cpu_scope='COMBINED_PARENT_AND_WORKER_SAME_PROCESS_EXCLUDES_NVIDIA_AND_CIM_HELPERS';mailbox_fault=$box.Fault;completed_naturally=$natural;neutral_consumer_not_operational_supervision=$true;generation_age='UNKNOWN';runtime_started=$false;candidate_fast_ms=500;candidate_slow_ms=1000;parameters_bound=$false}
Row 'REAL-PASSIVE-SCHEDULE-FOUR-BOUNDED-ENVELOPES' @{receipts=$receipts.Count;natural=$natural;errors=$errors;mailbox_fault=$box.Fault} ($natural -and $errors.Count -eq 0 -and $receipts.Count -eq 4 -and $null -eq $box.Fault) 'REAL_PASSIVE_TIMING_NEUTRAL_CONSUMER'
$preserved=@($receipts|Where-Object {$_.envelope.SlowSequence -eq 1}|ForEach-Object {$_.envelope.SlowAcquiredMs}|Select-Object -Unique)
Row 'REAL-CACHED-SLOW-ORIGINAL-ACQUISITION-PRESERVED' @{first_slow_acquisition_unique=$preserved.Count;slow_sequences=@($receipts|ForEach-Object {$_.envelope.SlowSequence})} ($preserved.Count -eq 1) 'REAL_PASSIVE_CACHE_TIMESTAMP_EVIDENCE'
if($receipts.Count){
 $newctx=New-WlbPreparedSupervisor $identity $clock 'PASSIVE_PREPARATION_ONLY' $start
 $null=$newctx.Mailbox.TryHeartbeat([WlbSupervision.Heartbeat]::new($identity,$clock,1,(Get-WlbSupervisorMonotonicMs),$false))
 $null=$newctx.Mailbox.TryPublish($receipts[0].envelope);$decision=$newctx.Tick((Get-WlbSupervisorMonotonicMs))
 Row 'REAL-STORED-PASSIVE-ENVELOPE-UNKNOWN-AGE-RECHECK' $decision ($decision.Reason -ceq 'PROVIDER_GENERATION_AGE_UNKNOWN' -and -not $decision.AuthorizedToExecute) 'RECHECK_STORED_MEASUREMENT_THIS_EXPERIMENT_NO_NEW_QUERY'
}
Save-INew ('async-delay-experiments-'+$Run+'.json') @($experiments)
Save-INew ('async-results-'+$Run+'.json') @($results)
$summary=@{tests=$results.Count;pass=@($results|Where-Object status -eq PASS).Count;fail=@($results|Where-Object status -eq FAIL).Count;runspaces_created=4;runspaces_natural_only=$true;subprocess_test_helpers_created=0;real_startup_or_kill=$false;comfy_watchdog_verified=$false}
Save-INew ('async-summary-'+$Run+'.json') $summary;$summary|ConvertTo-Json
if($summary.fail){$results|Where-Object status -eq FAIL|ConvertTo-Json -Depth 6;exit 1}
