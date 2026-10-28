#requires -Version 7.4
# Stage03J owned benign helpers only. No auto-start, production lifecycle or G4.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Wlb.TelemetryWorker.ps1')
function Initialize-WlbJProcessTypes {
 if($null -ne ('WlbOwnedJ.Lifecycle' -as [type])){return}
 Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.IO.Pipes;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using Microsoft.Win32.SafeHandles;
namespace WlbOwnedJ {
 public static class Native {
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] internal struct StartupInfo {
   public uint cb;public string reserved,desktop,title;public uint x,y,xsize,ysize,xchars,ychars,fill,flags;public ushort show,reserved2;public IntPtr reservedPtr,input,output,error;
  }
  [StructLayout(LayoutKind.Sequential)] internal struct ProcessInfo {public IntPtr process,thread;public uint pid,tid;}
  [StructLayout(LayoutKind.Sequential)] struct SecurityAttributes {public int size;public IntPtr descriptor;[MarshalAs(UnmanagedType.Bool)]public bool inherit;}
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] internal static extern bool CreateProcessW(string app,StringBuilder command,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr environment,string directory,ref StartupInfo startup,out ProcessInfo info);
  [StructLayout(LayoutKind.Sequential)] internal struct Performance {
   public uint Size;public UIntPtr CommitTotal,CommitLimit,CommitPeak,PhysicalTotal,PhysicalAvailable;
   public UIntPtr SystemCache,KernelTotal,KernelPaged,KernelNonpaged,PageSize;public uint HandleCount,ProcessCount,ThreadCount;
  }
  [DllImport("psapi.dll",SetLastError=true)] [return: MarshalAs(UnmanagedType.Bool)] static extern bool GetPerformanceInfo(out Performance p,uint size);
  internal static long[] ReadHostResources(){
   Performance p;if(!GetPerformanceInfo(out p,(uint)Marshal.SizeOf<Performance>()))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
   long page=checked((long)p.PageSize.ToUInt64());
   return new long[]{checked((long)p.PhysicalAvailable.ToUInt64()*page),checked((long)p.PhysicalTotal.ToUInt64()*page),checked((long)p.CommitTotal.ToUInt64()*page),checked((long)p.CommitLimit.ToUInt64()*page),page};
  }
  [DllImport("kernel32.dll",SetLastError=true)] internal static extern bool CloseHandle(IntPtr handle);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetProcessTimes(SafeProcessHandle process,out long created,out long exited,out long kernel,out long user);
  [DllImport("kernel32.dll",SetLastError=true)] static extern uint GetProcessId(SafeProcessHandle process);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool QueryFullProcessImageNameW(SafeProcessHandle process,uint flags,StringBuilder path,ref uint size);
  [DllImport("kernel32.dll",SetLastError=true)] internal static extern bool TerminateProcess(SafeProcessHandle process,uint code);
  [DllImport("kernel32.dll",SetLastError=true)] internal static extern uint WaitForSingleObject(SafeProcessHandle process,uint milliseconds);
  [DllImport("kernel32.dll",SetLastError=true)] internal static extern bool GetExitCodeProcess(SafeProcessHandle process,out uint code);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafePipeHandle CreateNamedPipeW(string name,uint access,uint mode,uint instances,uint output,uint input,uint timeout,ref SecurityAttributes security);
  [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool ConvertStringSecurityDescriptorToSecurityDescriptorW(string sddl,uint revision,out IntPtr security,out uint size);
  [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr value);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetNamedPipeClientProcessId(SafePipeHandle pipe,out uint pid);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetNamedPipeServerProcessId(SafePipeHandle pipe,out uint pid);
  public static long Creation(SafeProcessHandle h){long c,e,k,u;if(!GetProcessTimes(h,out c,out e,out k,out u))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());return c;}
  public static int Pid(SafeProcessHandle h){uint p=GetProcessId(h);if(p==0)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());return checked((int)p);}
  public static string Image(SafeProcessHandle h){var b=new StringBuilder(32768);uint size=(uint)b.Capacity;if(!QueryFullProcessImageNameW(h,0,b,ref size))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());return b.ToString();}
  public static int ClientPid(PipeStream p){uint id;if(!GetNamedPipeClientProcessId(p.SafePipeHandle,out id))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());return checked((int)id);}
  public static int ServerPid(PipeStream p){uint id;if(!GetNamedPipeServerProcessId(p.SafePipeHandle,out id))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());return checked((int)id);}
  public static NamedPipeServerStream LocalPipe(string name,string sid){
   if(name==null||!name.StartsWith("WLB_STAGE03J_")||name.Length!=45||sid==null||!sid.StartsWith("S-1-"))throw new ArgumentException("LOCAL_PIPE_SCOPE");
   foreach(char c in name.Substring(13))if(!((c>='0'&&c<='9')||(c>='a'&&c<='f')))throw new ArgumentException("LOCAL_PIPE_NAME_HEX_ONLY");
   IntPtr descriptor;uint size;
   // DACL is set only on creation of this owned ephemeral pipe, never on host files/services.
   if(!ConvertStringSecurityDescriptorToSecurityDescriptorW("D:P(A;;GA;;;"+sid+")",1,out descriptor,out size))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
   try{
    var sa=new SecurityAttributes{size=Marshal.SizeOf<SecurityAttributes>(),descriptor=descriptor,inherit=false};
    var h=CreateNamedPipeW(@"\\.\pipe\"+name,0x40080003,8,1,65536,65536,0,ref sa); // ASYNC,FIRST_INSTANCE,DUPLEX; REJECT_REMOTE_CLIENTS.
    if(h.IsInvalid)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    try{return new NamedPipeServerStream(PipeDirection.InOut,true,false,h);}catch{h.Dispose();throw;}
   }finally{LocalFree(descriptor);}
  }
 }
 public sealed class Lease {
  internal SafeProcessHandle Handle;internal int Creator;internal string Nonce,ScriptHash;internal bool Closed;
  public string Scope=>"STAGE03J_OWNED_HELPER_TEST_ONLY";public string AttemptId {get;}
  public string Mode {get;} public int ProcessId {get;} public long CreationFileTime {get;}
  public string CreationTimeUtc=>DateTime.FromFileTimeUtc(CreationFileTime).ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'");
  public string ExecutablePath {get;} public string ExecutableSha256 {get;}
  public string HelperSha256=>ScriptHash;public string IdentityError {get;}public bool MetadataVerified=>IdentityError==null;
  public bool CreatedByThisAttempt=>true;public bool HeldCreationHandle=>!Closed&&!Handle.IsClosed;
  public bool HasExited=>!Closed&&Native.WaitForSingleObject(Handle,0)==0;
  public uint? ExitCode {get{uint v;return HasExited&&Native.GetExitCodeProcess(Handle,out v)?v:(uint?)null;}}
  internal Lease(SafeProcessHandle handle,string attempt,string nonce,string mode){Handle=handle;Creator=Process.GetCurrentProcess().Id;AttemptId=attempt;Nonce=nonce;Mode=mode;try{ProcessId=Native.Pid(handle);CreationFileTime=Native.Creation(handle);ExecutablePath=Native.Image(handle);ExecutableSha256=Lifecycle.Hash(ExecutablePath);ScriptHash=Lifecycle.Hash(Lifecycle.Helper);}catch(Exception e){IdentityError=e.GetType().Name+":"+e.Message;}}
  public void CloseExited(){if(!HasExited)throw new InvalidOperationException("LIVE_HELPER_HANDLE_MUST_BE_RECONCILED_NOT_DISCARDED");Handle.Dispose();Closed=true;}
 }
 public sealed class StopEvidence {
  public int ProcessId {get;}public long CreationFileTime {get;}public string Image {get;}public string ImageSha256 {get;}
  public StopEvidence(int pid,long created,string image,string sha){ProcessId=pid;CreationFileTime=created;Image=image;ImageSha256=sha;}
  public static StopEvidence FromLease(Lease l){return new StopEvidence(l.ProcessId,l.CreationFileTime,l.ExecutablePath,l.ExecutableSha256);}
 }
 public sealed class StopResult {public bool Allowed {get;}public bool TerminationRequested {get;}public string Reason {get;}public int? ProcessId {get;}public bool ProductionStopAuthority=>false;public StopResult(bool allowed,bool stopped,string reason,int? pid){Allowed=allowed;TerminationRequested=stopped;Reason=reason;ProcessId=pid;}}
 public static class Lifecycle {
  public const string Executable=@"C:\Users\user\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe";
  public const string ExecutableHash="362a356ce7f0940ec74f73a8fc2c990a2cc24a38a11c90bbd8eca947110ad139";
  public const string Helper=@"D:\WHAT-LIES-BTWN-PRODUCTION-OS\tests\stage03j\OwnedTelemetryWorker.ps1";
  static readonly Dictionary<Guid,Lease> created=new Dictionary<Guid,Lease>();static readonly HashSet<Guid> used=new HashSet<Guid>();static readonly object gate=new object();
  public static string Hash(string p){using(var s=File.OpenRead(p))return Convert.ToHexString(SHA256.HashData(s)).ToLowerInvariant();}
  static bool Hex(string v){if(v==null||v.Length!=64)return false;foreach(char c in v)if(!((c>='0'&&c<='9')||(c>='a'&&c<='f')))return false;return true;}
  public static void MarkAttemptRefused(string attempt){
   Guid a;if(!Guid.TryParseExact(attempt,"D",out a))throw new ArgumentException("OWNED_TEST_LAUNCH_CONTRACT");
   // Shared monotonic refusal for every entry point; never release or grant a launch.
   lock(gate){if(used.Count<32)used.Add(a);}
  }
  static void AssertHostResourcesForCreate(){
   try{
    var v=Native.ReadHostResources();
    if(v==null||v.Length!=5||v[0]<0||v[0]>v[1]||v[2]<0||v[2]>v[3]||v[4]<=0)throw new InvalidOperationException("HOST_READING_INCONSISTENT");
    if(v[0]<8L*1024*1024*1024)throw new InvalidOperationException("AVAILABLE_RAM_BELOW_8_GIB");
    if(v[3]-v[2]<10L*1024*1024*1024)throw new InvalidOperationException("COMMIT_HEADROOM_BELOW_10_GIB");
   }catch(Exception e){throw new InvalidOperationException("STAGE03J_RESOURCE_BLOCKED:"+e.Message,e);}
  }
  public static Lease Start(string attempt,string nonce,string mode,string scriptHash,string pipeName,string sessionId){
   Guid a,s;if(!Guid.TryParseExact(attempt,"D",out a)||!Guid.TryParseExact(sessionId,"D",out s)||!Hex(nonce)||!Hex(scriptHash)||pipeName!="WLB_STAGE03J_"+a.ToString("N"))throw new ArgumentException("OWNED_TEST_LAUNCH_CONTRACT");
   attempt=a.ToString("D");
   if(mode!="NORMAL_EXIT"&&mode!="FINITE_DELAY"&&mode!="SIMULATED_HANG"&&mode!="CONTROLLED_FAILURE"&&mode!="HEARTBEAT_INTERRUPTION")throw new ArgumentException("FIXED_HELPER_MODE_ONLY");
   lock(gate){int live=0;foreach(var l in created.Values)if(!l.Closed&&!l.HasExited)live++;if(live>=2||used.Count>=32||!used.Add(a))throw new InvalidOperationException("ATTEMPT_RESTART_OR_PROCESS_BOUND_DENIED");
   if(Hash(Executable)!=ExecutableHash||Hash(Helper)!=scriptHash)throw new InvalidOperationException("FIXED_HELPER_SOURCE_IDENTITY_DIVERGED");
   string directory=Path.GetDirectoryName(Helper),scratch=Path.Combine(directory,"scratch",a.ToString("N"));Directory.CreateDirectory(scratch);
   var env=new SortedDictionary<string,string>(StringComparer.OrdinalIgnoreCase);foreach(DictionaryEntry e in Environment.GetEnvironmentVariables())env[(string)e.Key]=(string)e.Value;
   env["TEMP"]=scratch;env["TMP"]=scratch;env["PSModuleAnalysisCachePath"]=Path.Combine(scratch,"ModuleAnalysisCache");
   var items=new List<string>();foreach(var kv in env)items.Add(kv.Key+"="+kv.Value);IntPtr block=Marshal.StringToHGlobalUni(String.Join("\0",items)+"\0\0");
   var startup=new Native.StartupInfo{cb=(uint)Marshal.SizeOf<Native.StartupInfo>()};Native.ProcessInfo info;
   string command="\""+Executable+"\" -NoLogo -NoProfile -NonInteractive -File \""+Helper+"\" -Mode "+mode+" -PipeName "+pipeName+" -AttemptId "+attempt+" -Nonce "+nonce+" -SessionId "+sessionId+" -SupervisorPid "+Process.GetCurrentProcess().Id;
   // Authoritative fresh admission is inside the creation lock, including direct callers.
   // used.Add already consumed this attempt; any refusal is terminal, with no restart.
   try{AssertHostResourcesForCreate();if(!Native.CreateProcessW(Executable,new StringBuilder(command),IntPtr.Zero,IntPtr.Zero,false,0x08000400,block,directory,ref startup,out info))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());}
   finally{Marshal.FreeHGlobal(block);}
   Native.CloseHandle(info.thread);var handle=new SafeProcessHandle(info.process,true);
   var lease=new Lease(handle,attempt,nonce,mode);created.Add(a,lease);return lease;}
  }
  public static StopResult ValidateStop(Lease lease,string attempt,string nonce,StopEvidence expected){
   if(lease==null||expected==null)return new StopResult(false,false,"SIMULATED_OR_NO_OWNED_LEASE",null);
   if(!lease.MetadataVerified)return new StopResult(false,false,"OWNERSHIP_UNCERTAIN_BLOCKED_RECONCILE",lease.ProcessId);
   Guid a;if(!Guid.TryParseExact(attempt,"D",out a))return new StopResult(false,false,"FOREIGN_ATTEMPT_OR_TOKEN_OR_HANDLE",lease.ProcessId);
   lock(gate){Lease registered;if(!created.TryGetValue(a,out registered)||!Object.ReferenceEquals(registered,lease)||lease.AttemptId!=a.ToString("D")||lease.Nonce!=nonce||lease.Creator!=Process.GetCurrentProcess().Id||lease.Closed)return new StopResult(false,false,"FOREIGN_ATTEMPT_OR_TOKEN_OR_HANDLE",lease.ProcessId);}
   try{
    if(!lease.HeldCreationHandle||Native.Pid(lease.Handle)!=expected.ProcessId||Native.Creation(lease.Handle)!=expected.CreationFileTime||lease.ProcessId!=expected.ProcessId||lease.CreationFileTime!=expected.CreationFileTime)return new StopResult(false,false,"PID_REUSED_OR_CREATION_OR_HANDLE_MISMATCH",lease.ProcessId);
    if(lease.HasExited)return new StopResult(true,false,"ALREADY_EXITED_HELD_TUPLE_NO_TERMINATION",lease.ProcessId);
    string image=Native.Image(lease.Handle);
    if(!image.Equals(Executable,StringComparison.OrdinalIgnoreCase)||!image.Equals(expected.Image,StringComparison.OrdinalIgnoreCase)||expected.ImageSha256!=lease.ExecutableSha256||Hash(image)!=ExecutableHash||Hash(Helper)!=lease.ScriptHash)return new StopResult(false,false,"IMAGE_OR_HASH_OR_HELPER_SOURCE_AMBIGUOUS",lease.ProcessId);
    return new StopResult(true,false,"EXACT_CREATED_HELPER_HELD_HANDLE_TUPLE",lease.ProcessId);
   }catch{return new StopResult(false,false,"OWNERSHIP_UNCERTAIN_BLOCKED_RECONCILE",lease.ProcessId);}
  }
  public static StopResult Stop(Lease lease,string attempt,string nonce,StopEvidence expected,string reason){
   if(reason!="TEST_TIMEOUT"&&reason!="TEST_HEARTBEAT_LOST"&&reason!="TEST_CHANNEL_CLOSED"&&reason!="TEST_CLEANUP")return new StopResult(false,false,"STOP_REASON_NOT_TEST_SCOPE",lease==null?(int?)null:lease.ProcessId);
   var authority=ValidateStop(lease,attempt,nonce,expected);if(!authority.Allowed)return authority;
   if(lease.HasExited)return new StopResult(true,false,"ALREADY_EXITED_NO_TERMINATION",lease.ProcessId);
   // The exact creation handle remains held; never OpenProcess by PID, name or tree.
   if(!Native.TerminateProcess(lease.Handle,197))return new StopResult(false,false,"OWNED_TERMINATION_FAILED_RECONCILE",lease.ProcessId);
   return new StopResult(true,true,"OWNED_STAGE03J_HELPER_TERMINATION_REQUESTED",lease.ProcessId);
  }
 }
 public static class Framing {
  public const int MaxBytes=65536;static readonly UTF8Encoding utf8=new UTF8Encoding(false,true);
  static async Task Exact(Stream stream,byte[] target){int read=0;while(read<target.Length){int n=await stream.ReadAsync(target,read,target.Length-read).ConfigureAwait(false);if(n==0)throw new EndOfStreamException(read==0?"CHANNEL_CLOSED":"TRUNCATED_MESSAGE");read+=n;}}
  public static async Task<string> ReadAsync(Stream stream){var header=new byte[4];await Exact(stream,header).ConfigureAwait(false);uint size=BitConverter.ToUInt32(header,0);if(size<2||size>MaxBytes)throw new InvalidDataException("IPC_MESSAGE_SIZE_BOUND");var bytes=new byte[size];try{await Exact(stream,bytes).ConfigureAwait(false);}catch(EndOfStreamException){throw new EndOfStreamException("TRUNCATED_MESSAGE");}return utf8.GetString(bytes);}
  public static async Task WriteAsync(Stream stream,string json){var b=utf8.GetBytes(json);if(b.Length<2||b.Length>MaxBytes)throw new InvalidDataException("IPC_MESSAGE_SIZE_BOUND");var h=BitConverter.GetBytes((uint)b.Length);await stream.WriteAsync(h,0,h.Length).ConfigureAwait(false);await stream.WriteAsync(b,0,b.Length).ConfigureAwait(false);await stream.FlushAsync().ConfigureAwait(false);}
  public static byte[] Encode(string text){var b=utf8.GetBytes(text);if(b.Length<2||b.Length>MaxBytes)throw new InvalidDataException("IPC_MESSAGE_SIZE_BOUND");var packet=new byte[b.Length+4];BitConverter.GetBytes((uint)b.Length).CopyTo(packet,0);b.CopyTo(packet,4);return packet;}
 }
}
'@
}
function Read-WlbJWireJson {
 param([string]$Raw)
 if([Text.Encoding]::UTF8.GetByteCount($Raw) -gt 65536){throw 'IPC_MESSAGE_SIZE_BOUND'}
 $doc=[System.Text.Json.JsonDocument]::Parse([string]$Raw);try{Assert-WlbJsonElement $doc.RootElement}finally{$doc.Dispose()}
 $options=@{AsHashtable=$true;Depth=64;NoEnumerate=$true};if((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')){$options.DateKind='String'}
 return ,($Raw|ConvertFrom-Json @options)
}
function New-WlbJAttempt {
 Initialize-WlbJProcessTypes
 $policy=Read-WlbJson (Join-Path $script:WlbRoot 'policy\startup-policy.json');Assert-WlbStartupPolicy $policy
 $null=Assert-WlbPath (Join-Path $script:WlbRoot 'tests\stage03j\OwnedTelemetryWorker.ps1') -MustExist -File
 $lock=Read-WlbJson (Join-Path $script:WlbRoot 'policy\runtime-lock.json')
 foreach($key in @('core\Wlb.WorkerProcess.ps1','tests\stage03j\OwnedTelemetryWorker.ps1')){Assert-WlbCondition ($lock.prepared_artifacts.Contains($key) -and (Get-WlbHash (Join-Path $script:WlbRoot $key)) -ceq $lock.prepared_artifacts[$key]) 'Prepared StageJ source pin missing/diverged'}
 $id=[guid]::NewGuid().ToString('D');$nonce=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
 [pscustomobject]@{scope='STAGE03J_OWNED_HELPER_TEST_ONLY';id=$id;nonce=$nonce;pipe_name=('WLB_STAGE03J_'+([guid]$id).ToString('N'));session_id=[guid]::NewGuid().ToString('D');helper_sha256=$lock.prepared_artifacts['tests\stage03j\OwnedTelemetryWorker.ps1'];created=$false;terminal=$false;reason=$null;lease=$null;runtime_authorized=$false}
}
function Start-WlbJOwnedHelper {
 param($Attempt,[ValidateSet('NORMAL_EXIT','FINITE_DELAY','SIMULATED_HANG','CONTROLLED_FAILURE','HEARTBEAT_INTERRUPTION')][string]$Mode)
 Assert-WlbCondition ($Attempt.scope -ceq 'STAGE03J_OWNED_HELPER_TEST_ONLY' -and -not $Attempt.created -and -not $Attempt.terminal) 'Attempt restart/foreign scope denied'
 try{
  $hostReading=Get-WlbPassiveHostMemory
  $readiness=Test-WlbJHelperResourceReadiness $hostReading
  Assert-WlbCondition $readiness.allowed_to_create_owned_test_helper ('STAGE03J_RESOURCE_BLOCKED:'+($readiness.reasons -join ';'))
  $Attempt.lease=[WlbOwnedJ.Lifecycle]::Start($Attempt.id,$Attempt.nonce,$Mode,$Attempt.helper_sha256,$Attempt.pipe_name,$Attempt.session_id)
  $Attempt.created=$true
  $Attempt.lease
 }catch{[WlbOwnedJ.Lifecycle]::MarkAttemptRefused($Attempt.id);$Attempt.terminal=$true;$Attempt.reason=$_.Exception.Message;throw}
}
function Test-WlbJHelperResourceReadiness {
 param($HostReading)
 $reasons=[Collections.Generic.List[string]]::new()
 try{
  Assert-WlbCondition ($HostReading.status -ceq 'AVAILABLE_GLOBAL') 'HOST_READING_UNAVAILABLE'
  foreach($key in @('available_ram_bytes','commit_total_bytes','commit_limit_bytes','commit_headroom_bytes')){Assert-WlbJsonType $HostReading[$key] Integer ('host/'+$key);Assert-WlbCondition ($HostReading[$key] -ge 0) 'HOST_NEGATIVE_METRIC'}
  Assert-WlbCondition ($HostReading.commit_limit_bytes-$HostReading.commit_total_bytes -eq $HostReading.commit_headroom_bytes) 'HOST_COMMIT_INCONSISTENT'
  if($HostReading.available_ram_bytes -lt 8GB){$reasons.Add('AVAILABLE_RAM_BELOW_8_GIB')}
  if($HostReading.commit_headroom_bytes -lt 10GB){$reasons.Add('COMMIT_HEADROOM_BELOW_10_GIB')}
 }catch{$reasons.Add($_.Exception.Message)}
 [pscustomobject]@{state='BLOCKED_NOT_AUTHORIZED';allowed_to_create_owned_test_helper=($reasons.Count -eq 0);reasons=@($reasons);production_start_authorized=$false;hard_os_cap=$false;resource_check_kind='POINT_IN_TIME_OWNED_HELPER_ADMISSION_ONLY'}
}
function New-WlbJProtocolState {
 param($Attempt)
 $lease=$Attempt.lease
 $observation=@{status='AVAILABLE_PROCESS_ATTRIBUTED';process_id=[int]$lease.ProcessId;creation_time_utc=$lease.CreationTimeUtc;image_path=$lease.ExecutablePath;image_sha256=$lease.ExecutableSha256}
 [pscustomobject]@{attempt_id=$Attempt.id;nonce=$Attempt.nonce;session_id=$Attempt.session_id;lease=$lease;worker_identity=(Get-WlbWorkerObservationFingerprint $observation);child_clock=$null;last_sequence=[long]0;last_produced_ms=[long]0;clock_verified=$false;clock_parent_start_ticks=[long]0;clock_challenge=$null;started_ms=(Get-WlbSupervisorMonotonicMs);last_tick_ms=[long]0;last_heartbeat_ms=$null;pending_sample=$null;last_acquired_ms=$null;last_fast_ms=$null;last_slow_ms=$null;slow_sequence=[long]0;sample_sequence=[long]0;terminal=$false;reason=$null;authorized_to_execute=$false}
}
function Assert-WlbJClockProof {
 param($Proof,$ParentStartedTicks,$ParentReceivedTicks,$Frequency,$Challenge,$SessionId)
 Assert-WlbObjectContract $Proof @{frequency='Integer';received_ticks='Integer';sent_ticks='Integer';challenge='String';session_id='String'} 'clock-proof'
 foreach($key in @('frequency','received_ticks','sent_ticks')){Assert-WlbJsonType $Proof[$key] Integer ('clock/'+$key)}
 Assert-WlbCondition ($Proof.challenge -ceq $Challenge -and $Proof.session_id -ceq $SessionId -and $Proof.frequency -eq $Frequency -and $Frequency -gt 0) 'CLOCK_NEGOTIATION_IDENTITY_OR_FREQUENCY'
 Assert-WlbCondition ($ParentReceivedTicks -ge $ParentStartedTicks -and ($ParentReceivedTicks-$ParentStartedTicks)*1000.0/$Frequency -le 500 -and $Proof.received_ticks -ge $ParentStartedTicks-1 -and $Proof.sent_ticks -ge $Proof.received_ticks -and $Proof.sent_ticks -le $ParentReceivedTicks+1) 'CLOCK_ROUNDTRIP_OR_EPOCH_NOT_VERIFIED'
}
function Receive-WlbJMessage {
 param($State,[string]$Raw,[long]$ReceivedMs,[long]$ReceivedTicks)
 if($State.terminal){throw ('TERMINAL_NO_RETRY:'+ $State.reason)}
 try{
  $m=Read-WlbJWireJson $Raw
  Assert-WlbKeys $m @('schema','attempt_id','nonce','worker_identity','sequence','kind','worker_clock_id','produced_ms','body') 'stage03j-wire'
  foreach($key in @('schema','attempt_id','nonce','worker_identity','kind','worker_clock_id')){Assert-WlbJsonType $m[$key] String ('wire/'+$key)}
  foreach($key in @('sequence','produced_ms')){Assert-WlbJsonType $m[$key] Integer ('wire/'+$key)}
  Assert-WlbCondition ($m.body -is [Collections.IDictionary]) 'IPC_BODY_OBJECT_REQUIRED'
  Assert-WlbCondition ($m.schema -ceq 'wlb-stage03j-ipc/0.1' -and $m.attempt_id -ceq $State.attempt_id -and $m.nonce -ceq $State.nonce -and $m.worker_identity -ceq $State.worker_identity) 'IPC_ATTEMPT_NONCE_OR_WORKER_IDENTITY'
  Assert-WlbCondition ($m.sequence -eq $State.last_sequence+1) 'IPC_DUPLICATE_REPLAY_OR_ORDER'
  Assert-WlbCondition ($m.produced_ms -ge 0 -and $m.produced_ms -le $ReceivedMs -and $m.produced_ms -ge $State.last_produced_ms) 'IPC_FUTURE_OR_REVERSED_TIMESTAMP'
  if($null -ne $State.child_clock){Assert-WlbCondition ($m.worker_clock_id -ceq $State.child_clock) 'IPC_CHILD_CLOCK_CHANGED'}
  switch($m.kind){
   'HELLO'{
    Assert-WlbCondition ($State.last_sequence -eq 0 -and $m.worker_clock_id -match '^[a-f0-9-]{36}$') 'IPC_HELLO_ORDER_OR_CLOCK'
    $b=$m.body;$l=$State.lease
    Assert-WlbCondition ($b.pid -is [long] -or $b.pid -is [int]) 'IPC_PID_TYPE'
    Assert-WlbObjectContract $b @{pid='Integer';creation_filetime='Integer';creation_time_utc='String';image_path='String';image_sha256='String';helper_sha256='String';mode='String';frequency='Integer'} 'hello'
    Assert-WlbCondition ($b.pid -eq $l.ProcessId -and $b.creation_filetime -eq $l.CreationFileTime -and $b.creation_time_utc -ceq $l.CreationTimeUtc -and $b.image_path.Equals($l.ExecutablePath,[StringComparison]::OrdinalIgnoreCase) -and $b.image_sha256 -ceq $l.ExecutableSha256 -and $b.helper_sha256 -ceq $State.lease.HelperSha256 -and $b.mode -ceq $l.Mode -and $b.frequency -eq [Diagnostics.Stopwatch]::Frequency) 'IPC_HELLO_NATIVE_IDENTITY_OR_SOURCE_DIVERGED'
    $State.child_clock=$m.worker_clock_id
   }
   'CLOCK_PROOF'{
    Assert-WlbCondition ($State.last_sequence -eq 1) 'CLOCK_PROOF_ORDER'
    Assert-WlbJClockProof $m.body $State.clock_parent_start_ticks $ReceivedTicks ([Diagnostics.Stopwatch]::Frequency) $State.clock_challenge $State.session_id
    $State.clock_verified=$true;$State.last_heartbeat_ms=$ReceivedMs
   }
   'HEARTBEAT'{Assert-WlbCondition $State.clock_verified 'CLOCK_NOT_NEGOTIATED';Assert-WlbKeys $m.body @() 'heartbeat-body';$State.last_heartbeat_ms=$m.produced_ms}
   'SAMPLE'{
    Assert-WlbCondition $State.clock_verified 'CLOCK_NOT_NEGOTIATED';Assert-WlbCondition ($null -eq $State.pending_sample) 'MAILBOX_FULL_ONE_SAMPLE_MAX'
    $e=$m.body
    Assert-WlbObjectContract $e @{ClockId='String';WorkerIdentity='String';Sequence='Integer';SlowSequence='Integer';RequestStartedMs='Integer';FastAcquiredMs='Integer';SlowAcquiredMs='Integer';CollectionCompletedMs='Integer';ProviderGenerationVerified='Boolean';EvidenceKind='String';PayloadJson='String'} 'envelope'
    Assert-WlbCondition ($e.ClockId -ceq $State.session_id -and $e.WorkerIdentity -ceq $State.worker_identity -and $e.Sequence -eq $State.sample_sequence+1 -and $e.ProviderGenerationVerified -is [bool] -and -not $e.ProviderGenerationVerified -and $e.EvidenceKind -ceq 'PASSIVE_PREPARATION_ONLY') 'IPC_ENVELOPE_IDENTITY_SEQUENCE_OR_GENERATION'
    foreach($key in @('RequestStartedMs','FastAcquiredMs','SlowAcquiredMs','CollectionCompletedMs','SlowSequence','Sequence')){Assert-WlbJsonType $e[$key] Integer ('ipc-envelope/'+$key)}
    Assert-WlbCondition ($e.RequestStartedMs -ge 0 -and $e.FastAcquiredMs -ge $e.RequestStartedMs -and $e.SlowAcquiredMs -ge 0 -and $e.CollectionCompletedMs -ge $e.FastAcquiredMs -and $e.CollectionCompletedMs -ge $e.SlowAcquiredMs -and $e.CollectionCompletedMs -le $ReceivedMs) 'IPC_ENVELOPE_ACQUISITION_OR_FUTURE'
    Assert-WlbCondition ($e.CollectionCompletedMs -le $m.produced_ms -and ($null -eq $State.last_fast_ms -or $e.FastAcquiredMs -ge $State.last_fast_ms)) 'IPC_COLLECTION_AFTER_PRODUCTION_OR_FAST_REVERSED'
    Assert-WlbCondition ($e.SlowSequence -gt 0 -and $e.SlowSequence -ge $State.slow_sequence -and $e.SlowSequence -le $State.slow_sequence+1 -and ($null -eq $State.last_slow_ms -or ($e.SlowSequence -eq $State.slow_sequence -and $e.SlowAcquiredMs -eq $State.last_slow_ms) -or ($e.SlowSequence -eq $State.slow_sequence+1 -and $e.SlowAcquiredMs -gt $State.last_slow_ms))) 'IPC_SLOW_CACHE_REWRITTEN_OR_REVERSED'
    $parsed=Read-WlbJWireJson $e.PayloadJson
    Assert-WlbCondition ($parsed.clock_id -ceq $State.session_id -and $parsed.start_ms -eq [Math]::Min($e.FastAcquiredMs,$e.SlowAcquiredMs) -and $parsed.end_ms -eq $e.CollectionCompletedMs -and $parsed.source_generation_freshness -ceq 'NOT_VERIFIED') 'IPC_PAYLOAD_CLOCK_ACQUISITION_OR_GENERATION'
    Assert-WlbCondition ($parsed.authorized_to_execute -is [bool] -and -not $parsed.authorized_to_execute) 'IPC_PAYLOAD_CANNOT_AUTHORIZE'
    $State.pending_sample=$e;$State.sample_sequence=$e.Sequence;$State.last_acquired_ms=[Math]::Min($e.FastAcquiredMs,$e.SlowAcquiredMs);$State.last_fast_ms=$e.FastAcquiredMs;$State.last_slow_ms=$e.SlowAcquiredMs;$State.slow_sequence=$e.SlowSequence
   }
   'BYE'{Assert-WlbCondition $State.clock_verified 'CLOCK_NOT_NEGOTIATED';Assert-WlbObjectContract $m.body @{mode='String';authorized_to_execute='Boolean'} 'bye';Assert-WlbCondition ($m.body.mode -ceq $State.lease.Mode -and -not $m.body.authorized_to_execute) 'BYE_IDENTITY_OR_AUTHORITY'}
   'FAIL'{throw 'WORKER_CONTROLLED_OR_READ_FAILURE'}
   default{throw 'IPC_MESSAGE_KIND_DENIED'}
  }
  $State.last_sequence=$m.sequence;$State.last_produced_ms=$m.produced_ms
  [pscustomobject]@{kind=$m.kind;sequence=$m.sequence;message=$m;state='BLOCKED_NOT_AUTHORIZED';received_ms=$ReceivedMs;authorized_to_execute=$false}
 }catch{$State.terminal=$true;$State.reason=$_.Exception.Message;throw}
}
function Get-WlbJWatchdogDecision {
 param($State,[long]$NowMs,[bool]$WorkerExited,[bool]$ChannelFailed,[long]$HelperTestTimeoutMs=0)
 if(-not $State.terminal){
  if($NowMs -lt $State.started_ms -or $NowMs -lt $State.last_tick_ms){$State.terminal=$true;$State.reason='SUPERVISOR_CLOCK_REVERSED'}
  elseif($NowMs-$State.started_ms -ge 120000){$State.terminal=$true;$State.reason='FUTURE_G4_DEADLINE_120S'}
  elseif($HelperTestTimeoutMs -gt 0 -and $NowMs-$State.started_ms -ge $HelperTestTimeoutMs){$State.terminal=$true;$State.reason='OWNED_HELPER_TEST_TIMEOUT_NOT_G4_BUDGET'}
  elseif($WorkerExited){$State.terminal=$true;$State.reason='WORKER_EXITED'}
  elseif($ChannelFailed){$State.terminal=$true;$State.reason='CHANNEL_CLOSED_OR_FAILED'}
  elseif($State.clock_verified -and ($null -eq $State.last_heartbeat_ms -or $NowMs-$State.last_heartbeat_ms -gt 2000)){$State.terminal=$true;$State.reason='WORKER_HEARTBEAT_ABSENT_OR_STALE'}
  elseif($null -ne $State.last_acquired_ms -and $NowMs-$State.last_acquired_ms -gt 2000){$State.terminal=$true;$State.reason='ACQUISITION_RECEIPT_AGE_EXCEEDED'}
 }
 $State.last_tick_ms=$NowMs
 [pscustomobject]@{state='BLOCKED_NOT_AUTHORIZED';terminal=$State.terminal;reason=$State.reason;now_ms=$NowMs;g4_deadline_ms=$State.started_ms+120000;helper_test_timeout_ms=$HelperTestTimeoutMs;authorized_to_execute=$false;restart_allowed=$false;provider_generation_age='UNKNOWN';process_stop_is_separate_owned_test_action=$true}
}
