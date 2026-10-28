#requires -Version 7.6
param([ValidatePattern('^[a-z0-9-]+$')][string]$RunLabel='run01')
. (Join-Path $PSScriptRoot 'J.Common.ps1')
. (Join-Path $JRoot 'core\Wlb.WorkerProcess.ps1')
Initialize-WlbJProcessTypes
Initialize-WlbSupervisionTypes
$script:results=[Collections.Generic.List[object]]::new()
function Invoke-JReal {
 param([string]$Case,[string]$Mode,[int]$ShortTimeout=0,[switch]$CloseChannel,[switch]$Denials)
 $attempt=New-WlbJAttempt;$lease=$null;$pipe=$null;$state=$null;$stop=$null;$failure=$null
 $messages=[Collections.Generic.List[object]]::new();$ticks=[Collections.Generic.List[object]]::new();$denied=[Collections.Generic.List[object]]::new()
 $rawSamples=[Collections.Generic.List[object]]::new();$strictDecision=$null;$clockProof=$null;$bye=$false;$channelFailed=$false;$testDeadline=[long]8000;$maxPrivate=[long]0;$maxCommit=[long]0;$proofReceipt=$null;$heartbeatReceipt=$null;$firstTerminal=$null
 $stopHistory=[Collections.Generic.List[object]]::new()
 $hostBefore=Get-WlbPassiveHostMemory
 try{
  $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $pipe=[WlbOwnedJ.Native]::LocalPipe($attempt.pipe_name,$sid)
  $connect=$pipe.WaitForConnectionAsync()
  $lease=Start-WlbJOwnedHelper $attempt $Mode
  if(-not $lease.MetadataVerified){throw ('OWNERSHIP_UNCERTAIN:'+ $lease.IdentityError)}
  $state=New-WlbJProtocolState $attempt;$readTask=$null;$writeTask=$null;$connected=$false;$closedOnce=$false
  $expected=[WlbOwnedJ.StopEvidence]::FromLease($lease)
  while($true){
   $now=Get-WlbSupervisorMonotonicMs
   if($connect.IsCompleted -and -not $connected){
    $connect.GetAwaiter().GetResult();$connected=$true
    if([WlbOwnedJ.Native]::ClientPid($pipe) -ne $lease.ProcessId){throw 'NATIVE_PIPE_CLIENT_PID_MISMATCH'}
    $readTask=[WlbOwnedJ.Framing]::ReadAsync($pipe)
   }
   if($null -ne $writeTask -and $writeTask.IsCompleted){$writeTask.GetAwaiter().GetResult();$writeTask=$null;if(-not $closedOnce){$readTask=[WlbOwnedJ.Framing]::ReadAsync($pipe)}}
   if($null -ne $readTask -and $readTask.IsCompleted){
    try{$raw=$readTask.GetAwaiter().GetResult()}catch{$channelFailed=$true;$raw=$null};$readTask=$null
    if($null -ne $raw){
     $receivedTicks=[Diagnostics.Stopwatch]::GetTimestamp();$receivedMs=Get-WlbSupervisorMonotonicMs
     $accepted=Receive-WlbJMessage $state $raw $receivedMs $receivedTicks
     $messages.Add(@{kind=$accepted.kind;sequence=$accepted.sequence;produced_ms=$accepted.message.produced_ms;received_ms=$receivedMs;bytes=[Text.Encoding]::UTF8.GetByteCount($raw)})
     if($accepted.kind -ceq 'HELLO'){
      $state.clock_challenge=[guid]::NewGuid().ToString('D');$state.clock_parent_start_ticks=[Diagnostics.Stopwatch]::GetTimestamp()
      $response=@{kind='CLOCK_CHALLENGE';attempt_id=$attempt.id;nonce=$attempt.nonce;session_id=$attempt.session_id;challenge=$state.clock_challenge;parent_ticks=$state.clock_parent_start_ticks;frequency=[Diagnostics.Stopwatch]::Frequency;authorized_to_execute=$false}
     }else{
      $response=@{kind='ACK';attempt_id=$attempt.id;nonce=$attempt.nonce;session_id=$attempt.session_id;sequence=$accepted.sequence;authorized_to_execute=$false}
     }
     if($accepted.kind -ceq 'CLOCK_PROOF'){
      $proofReceipt=$receivedMs;$clockProof=@{parent_started_ticks=$state.clock_parent_start_ticks;parent_received_ticks=$receivedTicks;proof=$accepted.message.body;frequency=[Diagnostics.Stopwatch]::Frequency;roundtrip_ms=($receivedTicks-$state.clock_parent_start_ticks)*1000.0/[Diagnostics.Stopwatch]::Frequency;verified=$state.clock_verified}
      if($ShortTimeout -gt 0){$testDeadline=$proofReceipt-$state.started_ms+$ShortTimeout}
     }
     if($accepted.kind -ceq 'HEARTBEAT'){
      $heartbeatReceipt=$receivedMs
      if($Denials){
       $foreignCaller=New-WlbJAttempt
       $denied.Add([WlbOwnedJ.Lifecycle]::Stop($lease,$foreignCaller.id,$foreignCaller.nonce,$expected,'TEST_CLEANUP'))
       $denied.Add([WlbOwnedJ.Lifecycle]::Stop($lease,$attempt.id,('0'*64),$expected,'TEST_CLEANUP'))
       $reused=[WlbOwnedJ.StopEvidence]::new($lease.ProcessId,$lease.CreationFileTime+1,$lease.ExecutablePath,$lease.ExecutableSha256)
       $denied.Add([WlbOwnedJ.Lifecycle]::Stop($lease,$attempt.id,$attempt.nonce,$reused,'TEST_CLEANUP'))
       $wrongPid=[WlbOwnedJ.StopEvidence]::new($PID,$lease.CreationFileTime,$lease.ExecutablePath,$lease.ExecutableSha256)
       $denied.Add([WlbOwnedJ.Lifecycle]::Stop($lease,$attempt.id,$attempt.nonce,$wrongPid,'TEST_CLEANUP'))
       $wrongHash=[WlbOwnedJ.StopEvidence]::new($lease.ProcessId,$lease.CreationFileTime,$lease.ExecutablePath,('f'*64))
       $denied.Add([WlbOwnedJ.Lifecycle]::Stop($lease,$attempt.id,$attempt.nonce,$wrongHash,'TEST_CLEANUP'))
       $denied.Add([WlbOwnedJ.Lifecycle]::Stop($null,$attempt.id,$attempt.nonce,$expected,'TEST_CLEANUP'))
       $denied.Add([WlbOwnedJ.Lifecycle]::Stop($lease,$attempt.id,$attempt.nonce,$expected,'PRODUCTION_STOP'))
       try{$null=Start-WlbJOwnedHelper $attempt $Mode;throw 'RESTART_UNEXPECTEDLY_ALLOWED'}catch{if($_.Exception.Message -eq 'RESTART_UNEXPECTEDLY_ALLOWED'){throw};$denied.Add(@{Allowed=$false;TerminationRequested=$false;Reason=$_.Exception.Message;ProcessId=$lease.ProcessId})}
       if(@($denied|Where-Object {$_.Allowed -or $_.TerminationRequested}).Count){throw 'DENIAL_TEST_CAUSED_TERMINATION'}
      }
     }
     if($accepted.kind -ceq 'SAMPLE'){
      $e=$state.pending_sample;$rawSamples.Add($e)
      $strict=New-WlbPreparedSupervisor $state.worker_identity $state.session_id 'PASSIVE_PREPARATION_ONLY' $state.started_ms
      $envelope=[WlbSupervision.Envelope]::new($e.WorkerIdentity,$e.ClockId,$e.EvidenceKind,$e.Sequence,$e.SlowSequence,$e.RequestStartedMs,$e.FastAcquiredMs,$e.SlowAcquiredMs,$e.CollectionCompletedMs,$e.ProviderGenerationVerified,$e.PayloadJson)
      $null=$strict.Mailbox.TryHeartbeat([WlbSupervision.Heartbeat]::new($state.worker_identity,$state.session_id,1,$receivedMs,$false));$null=$strict.Mailbox.TryPublish($envelope)
      $strictDecision=$strict.Tick($receivedMs);$state.pending_sample=$null
     }
     if($accepted.kind -ceq 'BYE'){$bye=$true}
     $writeTask=[WlbOwnedJ.Framing]::WriteAsync($pipe,(ConvertTo-Json -InputObject $response -Compress))
    }
   }
   if($CloseChannel -and $null -ne $heartbeatReceipt -and $null -eq $writeTask -and -not $closedOnce){$pipe.Dispose();$closedOnce=$true;$channelFailed=$true;$readTask=$null}
   $now=Get-WlbSupervisorMonotonicMs
   $decision=Get-WlbJWatchdogDecision $state $now $lease.HasExited $channelFailed $testDeadline
   $ticks.Add(@{now_ms=$now;terminal=$decision.terminal;reason=$decision.reason;worker_alive=(-not $lease.HasExited);authorized_to_execute=$decision.authorized_to_execute})
   if($ticks.Count -gt 2048){throw 'BOUNDED_TEST_TICK_HISTORY_EXCEEDED'}
   if($decision.terminal -and $null -eq $firstTerminal){$firstTerminal=$ticks[$ticks.Count-1]}
   if($decision.terminal -and -not $lease.HasExited -and $Mode -cne 'NORMAL_EXIT' -and $Mode -cne 'CONTROLLED_FAILURE' -and -not $bye -and ($null -eq $stop -or -not $stop.TerminationRequested)){
    $reason=if($ChannelFailed){'TEST_CHANNEL_CLOSED'}elseif($decision.reason -ceq 'WORKER_HEARTBEAT_ABSENT_OR_STALE'){'TEST_HEARTBEAT_LOST'}else{'TEST_TIMEOUT'}
    $stop=[WlbOwnedJ.Lifecycle]::Stop($lease,$attempt.id,$attempt.nonce,$expected,$reason)
    $stopHistory.Add(@{requested_ms=(Get-WlbSupervisorMonotonicMs);requested_reason=$reason;result=$stop})
    if(-not $stop.Allowed -and -not $lease.HasExited){throw ('STOP_DENIED_RECONCILE:'+ $stop.Reason)}
   }
   if($lease.HasExited -and ($bye -or $channelFailed -or $null -ne $stop)){break}
   if($now-$state.started_ms -gt 15000){throw 'BOUNDARY_TEST_RECONCILIATION_TIMEOUT'}
   # No passive provider calls on the supervisor tick path.
   [Threading.Thread]::Sleep(20)
  }
 }catch{
  $failure=$_.Exception.Message
  if($null -ne $lease -and -not $lease.HasExited -and ($null -eq $stop -or -not $stop.TerminationRequested)){$stop=[WlbOwnedJ.Lifecycle]::Stop($lease,$attempt.id,$attempt.nonce,[WlbOwnedJ.StopEvidence]::FromLease($lease),'TEST_CLEANUP');$stopHistory.Add(@{requested_ms=(Get-WlbSupervisorMonotonicMs);requested_reason='TEST_CLEANUP';result=$stop})}
 }finally{
  if($null -ne $lease){
   $waitUntil=(Get-WlbSupervisorMonotonicMs)+3000
   while(-not $lease.HasExited -and (Get-WlbSupervisorMonotonicMs) -lt $waitUntil){[Threading.Thread]::Sleep(20)}
   $leaseRecord=@{scope=$lease.Scope;attempt_id=$lease.AttemptId;mode=$lease.Mode;process_id=$lease.ProcessId;creation_filetime=$lease.CreationFileTime;creation_time_utc=$lease.CreationTimeUtc;image_path=$lease.ExecutablePath;image_sha256=$lease.ExecutableSha256;helper_sha256=$lease.HelperSha256;created_by_this_attempt=$lease.CreatedByThisAttempt;held_creation_handle=$lease.HeldCreationHandle;metadata_verified=$lease.MetadataVerified;identity_error=$lease.IdentityError;exited=$lease.HasExited;exit_code=$lease.ExitCode}
   if($lease.HasExited){$lease.CloseExited()}else{$failure='LIVE_HELPER_REQUIRES_HUMAN_RECONCILIATION: '+$failure}
  }else{$leaseRecord=$null}
  if($null -ne $pipe){$pipe.Dispose()}
  $hostAfter=Get-WlbPassiveHostMemory
  $result=@{case=$Case;run=$RunLabel;attempt_id=$attempt.id;attempt_nonce=$attempt.nonce;session_id=$attempt.session_id;supervisor_pid=$PID;lease=$leaseRecord;failure=$failure;stop=$stop;stop_history=@($stopHistory);first_terminal=$firstTerminal;clock_proof=$clockProof;proof_receipt_ms=$proofReceipt;heartbeat_receipt_ms=$heartbeatReceipt;bye_received=$bye;channel_failed=$channelFailed;helper_test_deadline_from_start_ms=$testDeadline;g4_deadline_budget_ms=120000;messages=@($messages);ticks=@($ticks);denials=@($denied);samples=@($rawSamples);strict_sample_decision=$strictDecision;host_before=$hostBefore;host_after=$hostAfter;authorized_to_execute=$false;production_watchdog_verified=$false}
  Save-JNew ($RunLabel+'-'+$Case+'-'+$attempt.id+'.json') $result
  $script:results.Add($result)
 }
 $result
}
$null=Invoke-JReal 'normal-passive' 'NORMAL_EXIT'
$null=Invoke-JReal 'finite-delay-and-denials' 'FINITE_DELAY' -Denials
$null=Invoke-JReal 'hang-short-timeout' 'SIMULATED_HANG' -ShortTimeout 750
$null=Invoke-JReal 'controlled-failure' 'CONTROLLED_FAILURE'
$null=Invoke-JReal 'heartbeat-interruption' 'HEARTBEAT_INTERRUPTION'
$null=Invoke-JReal 'channel-closed' 'FINITE_DELAY' -CloseChannel
Save-JNew ($RunLabel+'-real-index.json') @($script:results)
@($script:results)|ForEach-Object {[pscustomobject]@{case=$_.case;pid=$_.lease.process_id;exit=$_.lease.exit_code;failure=$_.failure;stop=$(if($null -ne $_.stop){$_.stop.Reason}else{$null});ticks=$_.ticks.Count;clock=$(if($null -ne $_.clock_proof){$_.clock_proof.verified}else{$false});samples=$_.samples.Count}}|ConvertTo-Json
