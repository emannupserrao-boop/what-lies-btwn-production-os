#requires -Version 7.4
param(
 [Parameter(Mandatory)][ValidateSet('NORMAL_EXIT','FINITE_DELAY','SIMULATED_HANG','CONTROLLED_FAILURE','HEARTBEAT_INTERRUPTION')][string]$Mode,
 [Parameter(Mandatory)][ValidatePattern('^WLB_STAGE03J_[a-f0-9]{32}$')][string]$PipeName,
 [Parameter(Mandatory)][guid]$AttemptId,
 [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$Nonce,
 [Parameter(Mandatory)][guid]$SessionId,
 [Parameter(Mandatory)][ValidateRange(1,2147483647)][int]$SupervisorPid
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. 'D:\WHAT-LIES-BTWN-PRODUCTION-OS\core\Wlb.WorkerProcess.ps1'
Initialize-WlbJProcessTypes
Initialize-WlbSupervisionTypes
if($PipeName -cne ('WLB_STAGE03J_'+$AttemptId.ToString('N'))){throw 'ATTEMPT_PIPE_MISMATCH'}
$self=[Diagnostics.Process]::GetCurrentProcess()
$creation=[WlbOwnedJ.Native]::Creation($self.SafeHandle)
$image=[WlbOwnedJ.Native]::Image($self.SafeHandle)
$observation=@{status='AVAILABLE_PROCESS_ATTRIBUTED';process_id=[int]$PID;creation_time_utc=[DateTime]::FromFileTimeUtc($creation).ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'");image_path=$image;image_sha256=[WlbOwnedJ.Lifecycle]::Hash($image)}
$workerIdentity=Get-WlbWorkerObservationFingerprint $observation
$childClock=[guid]::NewGuid().ToString('D');$script:wireSequence=[long]0
$client=[IO.Pipes.NamedPipeClientStream]::new('.',$PipeName,[IO.Pipes.PipeDirection]::InOut,[IO.Pipes.PipeOptions]::Asynchronous)
function Read-ParentBounded {
 $task=[WlbOwnedJ.Framing]::ReadAsync($client)
 if(-not $task.Wait(8000)){throw 'PARENT_ACK_TIMEOUT_TERMINAL'}
 $raw=$task.GetAwaiter().GetResult();Read-WlbJWireJson $raw
}
function Send-OwnedMessage([string]$Kind,$Body,[switch]$NoAck){
 $script:wireSequence++
 $message=@{schema='wlb-stage03j-ipc/0.1';attempt_id=$AttemptId.ToString('D');nonce=$Nonce;worker_identity=$workerIdentity;sequence=$script:wireSequence;kind=$Kind;worker_clock_id=$childClock;produced_ms=(Get-WlbSupervisorMonotonicMs);body=$Body}
 $json=ConvertTo-Json -InputObject $message -Depth 64 -Compress
 $write=[WlbOwnedJ.Framing]::WriteAsync($client,$json);if(-not $write.Wait(8000)){throw 'PARENT_WRITE_TIMEOUT_TERMINAL'};$write.GetAwaiter().GetResult()
 if(-not $NoAck){
  $ack=Read-ParentBounded
  Assert-WlbObjectContract $ack @{kind='String';attempt_id='String';nonce='String';session_id='String';sequence='Integer';authorized_to_execute='Boolean'} 'ack'
  Assert-WlbCondition ($ack.kind -ceq 'ACK' -and $ack.attempt_id -ceq $AttemptId.ToString('D') -and $ack.nonce -ceq $Nonce -and $ack.session_id -ceq $SessionId.ToString('D') -and $ack.sequence -eq $script:wireSequence -and -not $ack.authorized_to_execute) 'ACK_IDENTITY_OR_ORDER_DENIED'
 }
}
try{
 $client.Connect(8000)
 if([WlbOwnedJ.Native]::ServerPid($client) -ne $SupervisorPid){throw 'NATIVE_PIPE_SERVER_PID_MISMATCH'}
 Send-OwnedMessage HELLO @{pid=[int]$PID;creation_filetime=$creation;creation_time_utc=$observation.creation_time_utc;image_path=$image;image_sha256=$observation.image_sha256;helper_sha256=[WlbOwnedJ.Lifecycle]::Hash($PSCommandPath);mode=$Mode;frequency=[Diagnostics.Stopwatch]::Frequency} -NoAck
 $challenge=Read-ParentBounded;$receivedTicks=[Diagnostics.Stopwatch]::GetTimestamp()
 Assert-WlbObjectContract $challenge @{kind='String';attempt_id='String';nonce='String';session_id='String';challenge='String';parent_ticks='Integer';frequency='Integer';authorized_to_execute='Boolean'} 'challenge'
 Assert-WlbCondition ($challenge.kind -ceq 'CLOCK_CHALLENGE' -and $challenge.attempt_id -ceq $AttemptId.ToString('D') -and $challenge.nonce -ceq $Nonce -and $challenge.session_id -ceq $SessionId.ToString('D') -and $challenge.frequency -eq [Diagnostics.Stopwatch]::Frequency -and -not $challenge.authorized_to_execute) 'CLOCK_PARENT_IDENTITY_DENIED'
 Send-OwnedMessage CLOCK_PROOF @{challenge=$challenge.challenge;session_id=$SessionId.ToString('D');frequency=[Diagnostics.Stopwatch]::Frequency;received_ticks=$receivedTicks;sent_ticks=[Diagnostics.Stopwatch]::GetTimestamp()}
 Send-OwnedMessage HEARTBEAT @{}
 switch($Mode){
  'NORMAL_EXIT'{
   # Minimal real passive sample: no NVIDIA/CIM subprocesses on lifecycle tests.
   # Existing complete StageI collector remains unchanged and unintegrated.
   $start=Get-WlbSupervisorMonotonicMs
   $hostReading=Get-WlbPassiveHostMemory;$processReading=Get-WlbPassiveProcessObservation $PID
   $end=Get-WlbSupervisorMonotonicMs
   $payload=@{schema_version='wlb-stage03j-minimal-passive/0.1';clock_id=$SessionId.ToString('D');start_ms=$start;end_ms=$end;source='PASSIVE_LOCAL_READ_ONLY';source_generation_freshness='NOT_VERIFIED';host=$hostReading;process=$processReading;gpu='UNKNOWN_NOT_QUERIED';port='UNKNOWN_NOT_QUERIED';disk='UNKNOWN_NOT_QUERIED';concurrency='UNKNOWN_NOT_QUERIED';candidate_fast_ms=500;candidate_slow_ms=1000;candidate_freshness_ms=2000;full_resource_evaluation=$false;authorized_to_execute=$false}
   $envelope=New-WlbPreparedEnvelope $workerIdentity $SessionId.ToString('D') 'PASSIVE_PREPARATION_ONLY' 1 1 $start $start $start $end $false $payload
   $body=@{};foreach($key in @('ClockId','WorkerIdentity','Sequence','SlowSequence','RequestStartedMs','FastAcquiredMs','SlowAcquiredMs','CollectionCompletedMs','ProviderGenerationVerified','EvidenceKind','PayloadJson')){$body[$key]=$envelope.$key}
   Send-OwnedMessage SAMPLE $body
  }
  'FINITE_DELAY'{[Threading.Thread]::Sleep(1250)}
  'SIMULATED_HANG'{[Threading.Thread]::Sleep(30000)}
  'CONTROLLED_FAILURE'{exit 23}
  'HEARTBEAT_INTERRUPTION'{[Threading.Thread]::Sleep(3000)}
 }
 Send-OwnedMessage BYE @{mode=$Mode;authorized_to_execute=$false}
 exit 0
}catch{
 # No retry, no cleanup by PID/name/tree, no external writes.
 [Console]::Error.WriteLine('STAGE03J_HELPER_TERMINAL: '+$_.Exception.Message)
 exit 25
}finally{$client.Dispose();$self.Dispose()}
