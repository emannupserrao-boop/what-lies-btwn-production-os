#requires -Version 7.4
# Stage03I preparation only. No runtime/lifecycle/consent/REST integration.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Wlb.RuntimeMonitor.ps1')
function Initialize-WlbSupervisionTypes {
 if($null -ne ('WlbSupervision.Envelope' -as [type])){return}
 Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Threading;
namespace WlbSupervision {
 static class Frame {
  public static void Identity(string identity,string clock){
   if(identity==null||identity.Length!=64||String.IsNullOrWhiteSpace(clock)||clock.Length>128)throw new ArgumentException("BOUNDED_IDENTITY_OR_CLOCK");
   foreach(char c in identity)if(!((c>='0'&&c<='9')||(c>='a'&&c<='f')))throw new ArgumentException("IDENTITY_FINGERPRINT_SHAPE");
  }
 }
 public sealed class Envelope {
  public string WorkerIdentity {get;} public string ClockId {get;} public string EvidenceKind {get;}
  public long Sequence {get;} public long SlowSequence {get;}
  public long RequestStartedMs {get;} public long FastAcquiredMs {get;} public long SlowAcquiredMs {get;}
  public long CollectionCompletedMs {get;} public long AcquisitionStartedMs => Math.Min(FastAcquiredMs,SlowAcquiredMs);
  public long CollectionDurationMs => CollectionCompletedMs-RequestStartedMs;
  public bool ProviderGenerationVerified {get;} public string PayloadJson {get;}
  public int PayloadBytes {get;}
  public Envelope(string identity,string clock,string kind,long sequence,long slowSequence,long request,long fast,long slow,long completed,bool providerVerified,string payload){
   Frame.Identity(identity,clock);
   if(kind!="SIMULATED_TEST_ONLY"&&kind!="PASSIVE_PREPARATION_ONLY")throw new ArgumentException("EVIDENCE_KIND_DENIED");
   if(sequence<=0||slowSequence<=0||request<0||fast<0||slow<0||completed<request||completed<fast||completed<slow||fast<request)throw new ArgumentException("INVALID_SEQUENCE_OR_TIMESTAMPS");
   if(payload==null)throw new ArgumentException("PAYLOAD_MISSING");int bytes=Encoding.UTF8.GetByteCount(payload);
   if(bytes>65536||bytes<2)throw new ArgumentException("PAYLOAD_BYTE_BOUND");
   WorkerIdentity=identity;ClockId=clock;EvidenceKind=kind;Sequence=sequence;SlowSequence=slowSequence;
   RequestStartedMs=request;FastAcquiredMs=fast;SlowAcquiredMs=slow;CollectionCompletedMs=completed;
   ProviderGenerationVerified=kind=="SIMULATED_TEST_ONLY"&&providerVerified;
   PayloadJson=payload;PayloadBytes=bytes;
  }
 }
 public sealed class Heartbeat {
  public string WorkerIdentity {get;} public string ClockId {get;} public long Sequence {get;}
  public long ProducedMs {get;} public bool Failed {get;}
  public Heartbeat(string identity,string clock,long sequence,long produced,bool failed){
   Frame.Identity(identity,clock);if(sequence<=0||produced<0)throw new ArgumentException("HEARTBEAT_SHAPE");
   WorkerIdentity=identity;ClockId=clock;Sequence=sequence;ProducedMs=produced;Failed=failed;
  }
 }
 public sealed class Mailbox {
  readonly object gate=new object();readonly string identity,clock;
  Envelope pending;Heartbeat heartbeat;long published,heartbeatPublished;int fault;
  public int Capacity=>1;public string Fault=>Volatile.Read(ref fault)==0?null:Reason(Volatile.Read(ref fault));
  static string Reason(int f){switch(f){case 1:return "MAILBOX_FULL";case 2:return "MAILBOX_BUSY";case 3:return "IDENTITY_OR_CLOCK_MISMATCH";case 4:return "ENVELOPE_SEQUENCE_INVALID";case 5:return "HEARTBEAT_SEQUENCE_INVALID";case 6:return "WORKER_READ_FAILED";default:return "MAILBOX_FAULT";}}
  void Fail(int f){Interlocked.CompareExchange(ref fault,f,0);}
  public Mailbox(string expectedIdentity,string clockId){Frame.Identity(expectedIdentity,clockId);identity=expectedIdentity;clock=clockId;}
  public bool TryPublish(Envelope e){
   if(e==null){Fail(4);return false;}if(Fault!=null)return false;
   if(!Monitor.TryEnter(gate)){Fail(2);return false;}
   try{
    if(e.WorkerIdentity!=identity||e.ClockId!=clock){Fail(3);return false;}
    if(e.Sequence!=published+1){Fail(4);return false;}
    if(pending!=null){Fail(1);return false;}
    pending=e;published=e.Sequence;return true;
   }finally{Monitor.Exit(gate);}
  }
  public bool TryHeartbeat(Heartbeat h){
   if(h==null){Fail(5);return false;}if(Fault!=null)return false;
   if(!Monitor.TryEnter(gate)){Fail(2);return false;}
   try{
    if(h.WorkerIdentity!=identity||h.ClockId!=clock){Fail(3);return false;}
    if(h.Sequence!=heartbeatPublished+1){Fail(5);return false;}
    if(heartbeat!=null&&h.ProducedMs<heartbeat.ProducedMs){Fail(5);return false;}
    heartbeat=h;heartbeatPublished=h.Sequence;if(h.Failed)Fail(6);return true;
   }finally{Monitor.Exit(gate);}
  }
  public bool TryRead(out Envelope envelope,out Heartbeat beat){
   envelope=null;beat=null;if(Fault!=null)return false;
   if(!Monitor.TryEnter(gate)){Fail(2);return false;}
   try{envelope=pending;pending=null;beat=heartbeat;return true;}finally{Monitor.Exit(gate);}
  }
 }
 public sealed class Decision {
  public string State=>"BLOCKED_NOT_AUTHORIZED";public string TelemetryState {get;} public string Reason {get;}
  public bool AuthorizedToExecute=>false;public bool OperationalParametersBound=>false;public bool RuntimeWatchdogVerified=>false;
  public bool Terminal {get;} public long NowMs {get;} public long? SupervisorReceivedMs {get;}
  public long? AcquisitionAgeMs {get;} public long? ReceiptAgeMs {get;} public Envelope LastEnvelope {get;} public Envelope ObservedEnvelope {get;}
  public Decision(string state,string reason,bool terminal,long now,long? received,Envelope last,Envelope observed){TelemetryState=state;Reason=reason;Terminal=terminal;NowMs=now;SupervisorReceivedMs=received;LastEnvelope=last;ObservedEnvelope=observed;AcquisitionAgeMs=last==null?(long?)null:now-last.AcquisitionStartedMs;ReceiptAgeMs=received.HasValue?now-received.Value:(long?)null;}
 }
 public sealed class Supervisor {
  readonly Mailbox mailbox;readonly string kind;readonly long started;readonly long freshness;
  long previousNow,sequence,slowSequence,lastFast,lastSlow;string terminalReason;Envelope last,observed;long? received;
  public Mailbox Mailbox=>mailbox;public string EvidenceKind=>kind;public long StartedMs=>started;
  public long DeadlineMs {get;} public long ExperimentalFreshnessMs=>freshness;
  public Supervisor(Mailbox box,string evidenceKind,long start,long candidateFreshness){
   if(box==null||start<0||candidateFreshness!=2000||(evidenceKind!="SIMULATED_TEST_ONLY"&&evidenceKind!="PASSIVE_PREPARATION_ONLY"))throw new ArgumentException("PREPARATION_CONTEXT_ONLY");
   mailbox=box;kind=evidenceKind;started=start;previousNow=start;freshness=candidateFreshness;DeadlineMs=checked(start+120000);
  }
  public void Block(string reason){if(terminalReason==null)terminalReason=String.IsNullOrWhiteSpace(reason)?"UNSPECIFIED_FAILURE":reason;}
  public Decision Tick(long now){
   if(now<previousNow)Block("SUPERVISOR_CLOCK_REVERSED");previousNow=now;
   if(now>=DeadlineMs)Block("STARTUP_DEADLINE_120S");
   if(mailbox.Fault!=null)Block(mailbox.Fault);
   if(terminalReason!=null)return Result("BLOCKED",terminalReason,now);
   Envelope envelope;Heartbeat beat;
   if(!mailbox.TryRead(out envelope,out beat)){Block(mailbox.Fault);return Result("BLOCKED",terminalReason,now);}
   if(beat==null){if(now-started>freshness)Block("WORKER_HEARTBEAT_MISSING");}
   else if(beat.ProducedMs>now||beat.ProducedMs<started)Block("HEARTBEAT_CLOCK_INVALID");
   else if(beat.Failed)Block("WORKER_READ_FAILED");
   else if(now-beat.ProducedMs>freshness)Block("WORKER_HEARTBEAT_EXPIRED");
   if(envelope!=null){
    observed=envelope;
    if(envelope.EvidenceKind!=kind)Block("EVIDENCE_KIND_MISMATCH");
    if(envelope.Sequence!=sequence+1)Block("SUPERVISOR_SEQUENCE_INVALID");
    if(envelope.CollectionCompletedMs>now||envelope.RequestStartedMs<started||envelope.AcquisitionStartedMs<started)Block("ENVELOPE_FUTURE_OR_CLOCK_INVALID");
    if(sequence>0&&(envelope.FastAcquiredMs<lastFast||envelope.SlowAcquiredMs<lastSlow))Block("ACQUISITION_CLOCK_REVERSED");
    if(sequence>0&&(envelope.SlowSequence<slowSequence||envelope.SlowSequence>slowSequence+1||(envelope.SlowSequence==slowSequence&&envelope.SlowAcquiredMs!=lastSlow)))Block("CACHE_TIMESTAMP_OR_SEQUENCE_REWRITTEN");
    if(sequence==0&&envelope.SlowSequence!=1)Block("SLOW_SEQUENCE_INVALID");
    if(!envelope.ProviderGenerationVerified)Block("PROVIDER_GENERATION_AGE_UNKNOWN");
    if(terminalReason==null){last=envelope;received=now;sequence=envelope.Sequence;slowSequence=envelope.SlowSequence;lastFast=envelope.FastAcquiredMs;lastSlow=envelope.SlowAcquiredMs;}
   }
   if(last==null){if(now-started>freshness)Block("TELEMETRY_MISSING");}
   else if(now-last.AcquisitionStartedMs>freshness)Block("ACQUISITION_RECEIPT_FRESHNESS_EXCEEDED");
   if(terminalReason!=null)return Result("BLOCKED",terminalReason,now);
   if(last==null||beat==null)return Result("WAITING_FOR_TELEMETRY","NO_EXECUTION_TELEMETRY_PENDING",now);
   return Result("METADATA_VALID_PREPARATION_ONLY","RESOURCE_VALIDATION_REQUIRED_NO_AUTHORITY",now);
  }
  Decision Result(string state,string reason,long now){return new Decision(state,reason,terminalReason!=null,now,received,last,observed);}
 }
}
'@
}
function Get-WlbSupervisorMonotonicMs { [long]([Diagnostics.Stopwatch]::GetTimestamp()*1000.0/[Diagnostics.Stopwatch]::Frequency) }
function Get-WlbWorkerObservationFingerprint {
 param($Observation)
 foreach($key in @('status','creation_time_utc','image_path','image_sha256')){if($Observation[$key] -isnot [string]){throw 'Typed worker observation required'}}
 if($Observation.status -cne 'AVAILABLE_PROCESS_ATTRIBUTED' -or $Observation.process_id -isnot [int] -or $Observation.process_id -le 0 -or $Observation.image_sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'Worker identity unavailable'}
 $value=ConvertTo-Json -InputObject @($Observation.process_id,$Observation.creation_time_utc,$Observation.image_path,$Observation.image_sha256) -Compress
 [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($value))).ToLowerInvariant()
}
function New-WlbPreparedSupervisor {
 param([string]$WorkerIdentity,[string]$ClockId,[ValidateSet('SIMULATED_TEST_ONLY','PASSIVE_PREPARATION_ONLY')][string]$EvidenceKind,[long]$StartedMs,[long]$CandidateFreshnessMs=2000)
 Initialize-WlbSupervisionTypes
 [WlbSupervision.Supervisor]::new([WlbSupervision.Mailbox]::new($WorkerIdentity,$ClockId),$EvidenceKind,$StartedMs,$CandidateFreshnessMs)
}
function New-WlbPreparedEnvelope {
 param([string]$WorkerIdentity,[string]$ClockId,[ValidateSet('SIMULATED_TEST_ONLY','PASSIVE_PREPARATION_ONLY')][string]$EvidenceKind,[long]$Sequence,[long]$SlowSequence,[long]$RequestStartedMs,[long]$FastAcquiredMs,[long]$SlowAcquiredMs,[long]$CollectionCompletedMs,[bool]$ProviderGenerationVerified,$Payload)
 Initialize-WlbSupervisionTypes
 if($Payload -isnot [Collections.IDictionary]){throw 'Typed payload object required'}
 $json=ConvertTo-Json -InputObject $Payload -Depth 50 -Compress -WarningAction Stop
 $document=[System.Text.Json.JsonDocument]::Parse([string]$json)
 try{Assert-WlbJsonElement $document.RootElement}finally{$document.Dispose()}
 [WlbSupervision.Envelope]::new($WorkerIdentity,$ClockId,$EvidenceKind,$Sequence,$SlowSequence,$RequestStartedMs,$FastAcquiredMs,$SlowAcquiredMs,$CollectionCompletedMs,$ProviderGenerationVerified,$json)
}
function Test-WlbPreparedGpuProxy {
 # Interface/preflight only; never enabled in policy or strict evaluator.
 param($Policy,$Baseline,$Sample,$StartedMs,$NowMs)
 $reasons=[Collections.Generic.List[string]]::new()
 try{
  Assert-WlbStartupPolicy $Policy
  Assert-WlbJsonType $StartedMs Integer 'proxy/startup-start';Assert-WlbJsonType $NowMs Integer 'proxy/now'
  Assert-WlbCondition ($StartedMs -ge 0 -and $NowMs -ge $StartedMs) 'PROXY_CLOCK_INVALID'
  foreach($s in @($Baseline,$Sample)){
   Assert-WlbCondition ($s -is [Collections.IDictionary] -and $s.gpu.status -ceq 'AVAILABLE_GLOBAL') 'GPU_GLOBAL_UNAVAILABLE'
   Assert-WlbCondition ($s.preparation_scope -ceq 'G4_STARTUP_NO_MODELS' -and $s.models_requested -is [bool] -and -not $s.models_requested) 'PROXY_SCOPE_DENIED_G5_ALPHA_INFERENCE'
   $g=$s.gpu.global
   foreach($key in @('used_bytes','free_bytes','total_bytes','index')){Assert-WlbJsonType $g[$key] Integer ('gpu/'+$key);Assert-WlbCondition ($g[$key] -ge 0) 'GPU_GLOBAL_NEGATIVE'}
   Assert-WlbCondition ($g.used_bytes+$g.free_bytes -le $g.total_bytes) 'GPU_GLOBAL_INCONSISTENT'
   Assert-WlbCondition ($g.name -ceq 'NVIDIA GeForce RTX 5080 Laptop GPU' -and $g.uuid -cmatch '^GPU-[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$' -and $g.driver -is [string] -and -not [string]::IsNullOrWhiteSpace($g.driver)) 'RTX_BASELINE_IDENTITY_UNVERIFIED'
   foreach($key in @('start_ms','end_ms')){Assert-WlbJsonType $s[$key] Integer ('proxy/'+$key)}
   Assert-WlbCondition ($s.start_ms -ge $StartedMs -and $s.end_ms -ge $s.start_ms -and $s.end_ms -le $NowMs) 'PROXY_ACQUISITION_CLOCK_INVALID'
   Assert-WlbCondition ($s.source_generation_freshness -ceq 'VERIFIED') 'PROXY_PROVIDER_GENERATION_AGE_UNKNOWN'
   Assert-WlbCondition ($s.concurrency.known -is [bool] -and $s.concurrency.known -and $s.concurrency.exclusivity_proven -is [bool] -and $s.concurrency.exclusivity_proven -and $s.concurrency.potential_heavy_processes.Count -eq 0 -and $s.concurrency.actor_set_identity -cmatch '^[a-f0-9]{64}$') 'GPU_CONTENTION_OR_ACTORS_UNKNOWN'
  }
  foreach($key in @('name','uuid','driver','index','total_bytes')){Assert-WlbCondition ($Baseline.gpu.global[$key] -ceq $Sample.gpu.global[$key]) 'RTX_GLOBAL_IDENTITY_CHANGED'}
  Assert-WlbCondition ($Baseline.concurrency.actor_set_identity -ceq $Sample.concurrency.actor_set_identity) 'BACKGROUND_GPU_ACTORS_CHANGED'
  Assert-WlbCondition ($Baseline.start_ms -eq $StartedMs -and $Baseline.end_ms-$StartedMs -le 2000) 'IMMEDIATE_VALID_BASELINE_REQUIRED'
  if($NowMs-$Sample.start_ms -gt 2000){$reasons.Add('PROXY_ACQUISITION_RECEIPT_STALE')}
  if($NowMs-$StartedMs -ge 120000){$reasons.Add('PROXY_STARTUP_DEADLINE_120S')}
  $delta=$Sample.gpu.global.used_bytes-$Baseline.gpu.global.used_bytes
  Assert-WlbCondition ($delta -ge 0) 'GLOBAL_GPU_MOVEMENT_UNATTRIBUTABLE'
  if($delta -gt 2GB){$reasons.Add('GLOBAL_GPU_DELTA_OVER_2_GIB')}
 }catch{$reasons.Add($_.Exception.Message)}
 [pscustomobject]@{state='BLOCKED_NOT_AUTHORIZED';threshold_state=$(if($reasons.Count){'BLOCKED'}else{'PREPARATION_THRESHOLDS_ONLY'});reasons=@($reasons);global_delta_is_pid_attribution=$false;enabled_in_policy=$false;operational_control_approved=$false;authorized_to_execute=$false;automatic_retry=$false}
}
function Get-WlbPreparedSupervisorDecision {
 param($Supervisor,$Policy,$Baseline,$ExpectedProcess,[long]$NowMs,[switch]$SimulatedOwnershipLost)
 $metadata=$Supervisor.Tick($NowMs);$resource=$null
 if($metadata.TelemetryState -ceq 'METADATA_VALID_PREPARATION_ONLY'){
  try{
   $raw=$metadata.LastEnvelope.PayloadJson;$document=[System.Text.Json.JsonDocument]::Parse([string]$raw)
   try{Assert-WlbJsonElement $document.RootElement}finally{$document.Dispose()}
   $parseOptions=@{AsHashtable=$true;Depth=64;NoEnumerate=$true}
   if((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')){$parseOptions.DateKind='String'}
   $sample=$raw|ConvertFrom-Json @parseOptions
   if($SimulatedOwnershipLost){throw 'SIMULATED_OWNERSHIP_LOST'}
   $resource=Test-WlbPassiveResourcePreflight $Policy $Baseline $sample $ExpectedProcess $NowMs 2000
   if($resource.state -ceq 'BLOCKED'){$Supervisor.Block('RESOURCE_FAIL_CLOSED:'+($resource.reasons -join '|'))}
  }catch{$Supervisor.Block('PAYLOAD_OR_IDENTITY_INVALID:'+ $_.Exception.Message)}
  if($Supervisor.Tick($NowMs).Terminal){$metadata=$Supervisor.Tick($NowMs)}
 }
 [pscustomobject]@{state='BLOCKED_NOT_AUTHORIZED';metadata=$metadata;resource=$resource;authorized_to_execute=$false;runtime_started=$false;real_process_stopped=$false;restart_allowed=$false}
}
