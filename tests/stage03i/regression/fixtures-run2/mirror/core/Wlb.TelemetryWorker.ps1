#requires -Version 7.4
# Dedicated passive collector preparation. Caller may execute in a separate
# runspace for tests. No worker/process launch/stop, policy binding or runtime.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Wlb.Supervisor.ps1')
function New-WlbPreparedWorkerState {
 param([string]$WorkerIdentity,[string]$ClockId,[int]$ObservedProcessId,[long]$StartedMs,[int]$CandidateFastMs=500,[int]$CandidateSlowMs=1000)
 Assert-WlbCondition ($CandidateFastMs -eq 500 -and $CandidateSlowMs -eq 1000 -and $ObservedProcessId -gt 0 -and $StartedMs -ge 0) 'Only experimental worker candidates'
 $observed=Get-WlbPassiveProcessObservation $PID
 Assert-WlbCondition ((Get-WlbWorkerObservationFingerprint $observed) -ceq $WorkerIdentity) 'Worker observed identity mismatch'
 [pscustomobject]@{worker_identity=$WorkerIdentity;clock_id=$ClockId;observed_pid=$ObservedProcessId;fast_ms=$CandidateFastMs;slow_ms=$CandidateSlowMs;started_ms=$StartedMs;sequence=[long]0;slow_sequence=[long]0;heartbeat_sequence=[long]0;last_fast_ms=[long]0;slow_acquired_ms=[long]0;last_slow_started_ms=[long]0;slow_payload=$null;failed=$false;failure=$null;operational_parameters_bound=$false}
}
function Send-WlbPreparedHeartbeat {
 param($State,$Mailbox,[bool]$Failed=$false)
 $State.heartbeat_sequence++
 $Mailbox.TryHeartbeat([WlbSupervision.Heartbeat]::new($State.worker_identity,$State.clock_id,$State.heartbeat_sequence,(Get-WlbSupervisorMonotonicMs),$Failed))
}
function Invoke-WlbPreparedWorkerTick {
 param($State,$Mailbox)
 Assert-WlbCondition (-not $State.failed) 'Worker failed; automatic retry disabled'
 $start=Get-WlbSupervisorMonotonicMs
 $diagnostics=[ordered]@{}
 if($State.sequence -gt 0 -and $start-$State.last_fast_ms -lt $State.fast_ms){return [pscustomobject]@{collected=$false;reason='EXPERIMENTAL_FAST_NOT_DUE';authorized_to_execute=$false}}
 try{
  Assert-WlbCondition (Send-WlbPreparedHeartbeat $State $Mailbox) 'Heartbeat/mailbox rejected'
  $nowIdentity=Get-WlbPassiveProcessObservation $PID
  Assert-WlbCondition ((Get-WlbWorkerObservationFingerprint $nowIdentity) -ceq $State.worker_identity) 'Worker process identity lost'
  $hostReading=Get-WlbPassiveHostMemory;$process=Get-WlbPassiveProcessObservation $State.observed_pid;$port=Get-WlbPassivePortObservation
  $diagnostics.host=$hostReading.status;$diagnostics.process=$process.status;$diagnostics.port_known=$port.known
  $fastEnd=Get-WlbSupervisorMonotonicMs
  $refresh=($null -eq $State.slow_payload -or $start-$State.last_slow_started_ms -ge $State.slow_ms)
  if($refresh){
   $slowStart=Get-WlbSupervisorMonotonicMs
   $gpu=Get-WlbPassiveGpuObservation;$concurrency=Get-WlbPassiveConcurrencyObservation;$disk=Get-WlbPassiveDiskObservation
   $diagnostics.gpu=$gpu.status;$diagnostics.gpu_errors=$gpu.errors;$diagnostics.windows_gpu=$gpu.windows_status;$diagnostics.concurrency_known=$concurrency.known;$diagnostics.disk_known=$disk.known
   $actorRows=@($gpu.nv_processes|ForEach-Object {"$($_.process_id):$($_.image_name)"}|Sort-Object)
   $concurrency.actor_set_identity=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($actorRows -join '|')))).ToLowerInvariant()
   $concurrency.actor_identity_coverage='PARTIAL_PID_NAME_NOT_CREATION_OR_EXCLUSIVITY_PROOF'
   Assert-WlbCondition ($gpu.status -ceq 'AVAILABLE_GLOBAL' -and $gpu.errors.Count -eq 0 -and $concurrency.known -and $disk.known) 'Slow provider read unavailable; no retry'
   $State.slow_payload=@{gpu=$gpu;concurrency=$concurrency;disk=$disk};$State.slow_sequence++;$State.slow_acquired_ms=$slowStart;$State.last_slow_started_ms=$start
  }
  Assert-WlbCondition ($hostReading.status -ceq 'AVAILABLE_GLOBAL' -and $process.status -ceq 'AVAILABLE_PROCESS_ATTRIBUTED' -and $port.known) 'Fast provider read unavailable; no retry'
  $end=Get-WlbSupervisorMonotonicMs;$first=[Math]::Min($start,$State.slow_acquired_ms)
  $payload=[ordered]@{schema_version='wlb-passive-telemetry/0.1';source='PASSIVE_LOCAL_READ_ONLY';clock_id=$State.clock_id;start_ms=[long]$first;end_ms=$end;collection_ms=[long]($end-$first);measurement_interval_includes_cached_slow=($first -lt $start);host=$hostReading;processes=@($process);gpu=$State.slow_payload.gpu;port=$port;concurrency=$State.slow_payload.concurrency;disk=$State.slow_payload.disk;source_generation_freshness='NOT_VERIFIED';preparation_scope='G4_STARTUP_NO_MODELS';models_requested=$false;authorized_to_execute=$false}
  $State.sequence++
  $envelope=New-WlbPreparedEnvelope $State.worker_identity $State.clock_id 'PASSIVE_PREPARATION_ONLY' $State.sequence $State.slow_sequence $start $start $State.slow_acquired_ms $end $false $payload
  Assert-WlbCondition ($Mailbox.TryPublish($envelope)) 'Mailbox publish rejected; no retry'
  Assert-WlbCondition (Send-WlbPreparedHeartbeat $State $Mailbox) 'Completion heartbeat rejected'
  $State.last_fast_ms=$start
  [pscustomobject]@{collected=$true;sequence=$State.sequence;slow_refreshed=$refresh;fast_collection_ms=$fastEnd-$start;collection_ms=$end-$start;cached_slow_age_ms=$end-$State.slow_acquired_ms;envelope_bytes=$envelope.PayloadBytes;provider_age='UNKNOWN';authorized_to_execute=$false}
 }catch{
  $State.failed=$true;$State.failure=$_.Exception.Message;$null=Send-WlbPreparedHeartbeat $State $Mailbox -Failed $true
  [pscustomobject]@{collected=$false;failed=$true;reason=$State.failure;read_diagnostics=$diagnostics;automatic_retry=$false;authorized_to_execute=$false}
 }
}
