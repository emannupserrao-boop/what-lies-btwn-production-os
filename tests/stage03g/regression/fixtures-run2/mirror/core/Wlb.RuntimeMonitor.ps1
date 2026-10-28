#requires -Version 7.4
# Pure resource evaluator and injected MOCK watchdog. No live GPU probe or process-stop adapter.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Wlb.Startup.ps1')

function Test-WlbResourceSample {
    param($Policy,$Baseline,$Sample,$NowMs,$StartedMs)
    $reasons=[Collections.Generic.List[string]]::new()
    try{
        Assert-WlbStartupPolicy $Policy -MockOnly
        Assert-WlbJsonType $NowMs Integer 'clock/now_ms';Assert-WlbJsonType $StartedMs Integer 'clock/started_ms'
        Assert-WlbCondition ($NowMs -ge $StartedMs -and $StartedMs -ge 0) 'Monotonic clock reversed'
        foreach($key in @('polling_cadence_ms','telemetry_freshness_ms','cpu_budget')){
            Assert-WlbCondition ($Policy.human_parameters[$key].status -ceq 'INJECTED_TEST_ONLY' -and $null -ne $Policy.human_parameters[$key].value) "HUMAN_PARAMETER_PENDING:$key"
        }
        $cadence=$Policy.human_parameters.polling_cadence_ms.value;$freshness=$Policy.human_parameters.telemetry_freshness_ms.value
        Assert-WlbJsonType $cadence Integer 'mock/polling_cadence_ms';Assert-WlbJsonType $freshness Integer 'mock/telemetry_freshness_ms'
        Assert-WlbCondition ($cadence -gt 0 -and $freshness -ge $cadence) 'Invalid mock telemetry cadence/freshness'
        Assert-WlbCondition ($Policy.human_parameters.cpu_budget.value -ceq 'OBSERVE_ONLY_TEST') 'CPU mock model unresolved; no numeric CPU policy invented'
        $contract=@{schema_version='String';source='String';clock_id='String';sampled_ms='Integer';available_ram_bytes='Integer';commit_headroom_bytes='Integer';total_commit_bytes='Integer';private_bytes='Integer';vram_bytes='Integer';aggregate_output_log_temp_bytes='Integer';foreign_gpu_jobs='Integer';heavy_processes_active='Boolean';attribution_known='Boolean'}
        foreach($s in @($Baseline,$Sample)){
            Assert-WlbObjectContract $s $contract 'telemetry'
            Assert-WlbCondition ($s.schema_version -ceq 'wlb-startup-telemetry/0.1' -and $s.source -ceq 'INJECTED_TEST_ONLY') 'Live or unknown telemetry source is not verified in Stage03D2'
            foreach($key in @('sampled_ms','available_ram_bytes','commit_headroom_bytes','total_commit_bytes','private_bytes','vram_bytes','aggregate_output_log_temp_bytes','foreign_gpu_jobs')){Assert-WlbCondition ($s[$key] -ge 0) "Negative metric: $key"}
            Assert-WlbCondition $s.attribution_known 'TELEMETRY_ATTRIBUTION_UNKNOWN'
        }
        Assert-WlbCondition ($Baseline.clock_id -ceq $Sample.clock_id -and -not [string]::IsNullOrWhiteSpace($Sample.clock_id)) 'Clock domain mismatch'
        Assert-WlbCondition ($Baseline.sampled_ms -eq $StartedMs -and $Sample.sampled_ms -ge $Baseline.sampled_ms -and $Sample.sampled_ms -le $NowMs) 'Telemetry timestamp inconsistent with startup baseline'
        if($NowMs - $Sample.sampled_ms -gt $freshness){$reasons.Add('TELEMETRY_STALE')}
        $caps=$Policy.budget
        if($NowMs - $StartedMs -ge $caps.startup_timeout_seconds*1000){$reasons.Add('STARTUP_DEADLINE_EXPIRED')}
        foreach($s in @($Baseline,$Sample)){
            if($s.available_ram_bytes -lt $caps.min_available_ram_gib*1GB){$reasons.Add('AVAILABLE_RAM_BELOW_8_GIB')}
            if($s.commit_headroom_bytes -lt $caps.min_commit_headroom_gib*1GB){$reasons.Add('COMMIT_HEADROOM_BELOW_10_GIB')}
            if($s.foreign_gpu_jobs -ne 0 -or $s.heavy_processes_active){$reasons.Add('FOREIGN_GPU_OR_HEAVY_WORKLOAD')}
        }
        $commitDelta=$Sample.total_commit_bytes-$Baseline.total_commit_bytes;$vramDelta=$Sample.vram_bytes-$Baseline.vram_bytes
        if($commitDelta -lt 0 -or $vramDelta -lt 0){$reasons.Add('COUNTER_REVERSED_OR_UNATTRIBUTABLE')}
        if($commitDelta -gt $caps.max_incremental_commit_gib*1GB){$reasons.Add('INCREMENTAL_COMMIT_OVER_4_GIB')}
        if($Sample.private_bytes -gt $caps.max_process_private_gib*1GB){$reasons.Add('PRIVATE_BYTES_OVER_4_GIB')}
        if($vramDelta -gt $caps.max_incremental_vram_gib*1GB){$reasons.Add('INCREMENTAL_VRAM_OVER_2_GIB')}
        if($Sample.aggregate_output_log_temp_bytes -gt $caps.output_log_cap_mib*1MB){$reasons.Add('AGGREGATE_FILES_OVER_256_MIB')}
    }catch{$reasons.Add($_.Exception.Message)}
    [pscustomobject]@{state=$(if($reasons.Count){'BLOCKED'}else{'CONTINUE_MOCK'});abort=($reasons.Count -gt 0);reasons=@($reasons | Select-Object -Unique);measurement_kind='INJECTED_TEST_ONLY';live_monitor_verified=$false;hard_caps_guaranteed=$false}
}

function Invoke-WlbInjectedWatchdog {
    param($Policy,$Baseline,$ExpectedProcess,$Consent,[scriptblock]$ReadSample,[scriptblock]$ReadClock,[scriptblock]$ReadProcess,[scriptblock]$StopMockOwned,[scriptblock]$AdvanceMockClock,[int]$MaxTicks=16)
    Assert-WlbCondition ($MaxTicks -gt 0 -and $MaxTicks -le 64) 'Bounded mock ticks required'
    $history=[Collections.Generic.List[object]]::new();$lastNow=$Baseline.sampled_ms
    for($tick=0;$tick -lt $MaxTicks;$tick++){
        try{
            $now=& $ReadClock
            Assert-WlbJsonType $now Integer 'injected-clock'
            Assert-WlbCondition ($now -ge $lastNow -and ($tick -eq 0 -or $now -gt $lastNow)) 'Mock clock not progressing'
            $lastNow=$now
            $sample=& $ReadSample
            $decision=Test-WlbResourceSample $Policy $Baseline $sample $now $Baseline.sampled_ms
            $observed=& $ReadProcess
            $ownership=Test-WlbProcessIdentity $ExpectedProcess $observed
            if(-not $ownership.owned){$decision=[pscustomobject]@{state='BLOCKED';abort=$true;reasons=@($decision.reasons)+@('OWNERSHIP_LOST_OR_UNKNOWN')}}
        }catch{$decision=[pscustomobject]@{state='BLOCKED';abort=$true;reasons=@('PROVIDER_OR_CLOCK_FAILURE:'+ $_.Exception.Message)}}
        $history.Add($decision)
        if($decision.abort){
            try{$observed=& $ReadProcess;$authority=Test-WlbMockStopAuthority $ExpectedProcess $observed $Consent -MockOnly}catch{$authority=[pscustomobject]@{allowed=$false;reason='OWNERSHIP_PROVIDER_FAILURE'}}
            if($authority.allowed){& $StopMockOwned $ExpectedProcess}
            return [pscustomobject]@{state='BLOCKED';history=@($history);mock_stop_callback_invoked=$authority.allowed;stop_authority_reason=$authority.reason;real_process_stopped=$false;restart_allowed=$false}
        }
        & $AdvanceMockClock $Policy.human_parameters.polling_cadence_ms.value
    }
    [pscustomobject]@{state='MOCK_WINDOW_COMPLETE';history=@($history);mock_stop_callback_invoked=$false;real_process_stopped=$false;restart_allowed=$false}
}

# Stage03G passive feasibility interfaces. They do not start/stop a runtime,
# submit jobs, create consent or apply policy. Legacy injected evaluator unchanged.
$script:WlbPassiveClockId=[guid]::NewGuid().ToString('D')
function Get-WlbPassiveClock {
    [pscustomobject]@{clock_id=$script:WlbPassiveClockId;monotonic_ms=[long]([Diagnostics.Stopwatch]::GetTimestamp()*1000.0/[Diagnostics.Stopwatch]::Frequency);utc=[DateTime]::UtcNow.ToString('o');frequency=[Diagnostics.Stopwatch]::Frequency}
}

function Initialize-WlbPassiveMemoryReader {
    if($null -eq ('WlbPassive.Memory' -as [type])){
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace WlbPassive {
 [StructLayout(LayoutKind.Sequential)] public struct Performance {
  public uint Size;
  public UIntPtr CommitTotal,CommitLimit,CommitPeak,PhysicalTotal,PhysicalAvailable;
  public UIntPtr SystemCache,KernelTotal,KernelPaged,KernelNonpaged,PageSize;
  public uint HandleCount,ProcessCount,ThreadCount;
 }
 public static class Memory {
  [DllImport("psapi.dll",SetLastError=true)]
  [return: MarshalAs(UnmanagedType.Bool)] static extern bool GetPerformanceInfo(out Performance p,uint size);
  public static long[] Read(){
   Performance p;uint size=(uint)Marshal.SizeOf<Performance>();
   if(!GetPerformanceInfo(out p,size))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
   long page=checked((long)p.PageSize.ToUInt64());
   return new long[]{checked((long)p.PhysicalAvailable.ToUInt64()*page),checked((long)p.PhysicalTotal.ToUInt64()*page),checked((long)p.CommitTotal.ToUInt64()*page),checked((long)p.CommitLimit.ToUInt64()*page),page};
  }
 }
}
'@
    }
}

function Get-WlbPassiveHostMemory {
    $clock=Get-WlbPassiveClock
    try{
        Initialize-WlbPassiveMemoryReader;$v=[WlbPassive.Memory]::Read()
        Assert-WlbCondition ($v[0] -ge 0 -and $v[0] -le $v[1] -and $v[2] -ge 0 -and $v[2] -le $v[3] -and $v[4] -gt 0) 'Inconsistent host memory counters'
        return [ordered]@{status='AVAILABLE_GLOBAL';source='WINDOWS_PSAPI_GETPERFORMANCEINFO';captured_ms=$clock.monotonic_ms;available_ram_bytes=$v[0];physical_total_bytes=$v[1];commit_total_bytes=$v[2];commit_limit_bytes=$v[3];commit_headroom_bytes=$v[3]-$v[2];granularity_bytes=$v[4];reason=$null}
    }catch{return [ordered]@{status='UNAVAILABLE';source='WINDOWS_PSAPI_GETPERFORMANCEINFO';captured_ms=$clock.monotonic_ms;reason=$_.Exception.Message}}
}

function Get-WlbPassiveProcessObservation {
    param([int]$ObservedProcessId)
    $clock=Get-WlbPassiveClock
    if($ObservedProcessId -le 0){return [ordered]@{status='UNAVAILABLE';requested_pid=$ObservedProcessId;captured_ms=$clock.monotonic_ms;reason='Invalid PID'}}
    $p=$null
    try{
        $p=[Diagnostics.Process]::GetProcessById($ObservedProcessId);$p.Refresh()
        $created=$p.StartTime.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
        $image=$p.MainModule.FileName;$imageHash=(Get-FileHash -LiteralPath $image -Algorithm SHA256).Hash.ToLowerInvariant()
        $private=[long]$p.PrivateMemorySize64;$cpu=[long]$p.TotalProcessorTime.Ticks;$p.Refresh()
        Assert-WlbCondition ($p.Id -eq $ObservedProcessId -and $created -ceq $p.StartTime.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")) 'PID identity changed during read'
        return [ordered]@{status='AVAILABLE_PROCESS_ATTRIBUTED';requested_pid=$ObservedProcessId;process_id=$p.Id;creation_time_utc=$created;image_path=$image;image_sha256=$imageHash;private_bytes=$private;cpu_total_100ns=$cpu;cpu_scope='CUMULATIVE_KERNEL_PLUS_USER_TIME_NO_CAP';captured_ms=$clock.monotonic_ms;identity_match_is_launch_ownership=$false;reason=$null}
    }catch{return [ordered]@{status='UNAVAILABLE';requested_pid=$ObservedProcessId;captured_ms=$clock.monotonic_ms;reason=$_.Exception.Message}}
    finally{if($p){$p.Dispose()}}
}

function Get-WlbPassiveGpuObservation {
    $clock=Get-WlbPassiveClock
    $g=[ordered]@{status='UNAVAILABLE';source='NVIDIA_SMI_EXISTING_FIXED_READ_ONLY_QUERIES';captured_ms=$clock.monotonic_ms;global=$null;nv_process_status='UNAVAILABLE';nv_processes=@();windows_status='UNAVAILABLE';windows_processes=@();windows_adapters=@();rtx_process_attribution='NOT_VERIFIED';luid_to_nvidia_uuid_mapping='NOT_VERIFIED';provider_generation_age='UNKNOWN';errors=@()}
    $smi=Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
    if(Test-Path -LiteralPath $smi){
        try{
            # Two bounded, one-shot passive CLI queries. No loop, retry or lifecycle adapter.
            $text=@(& $smi '--query-gpu=index,name,uuid,driver_version,memory.total,memory.used,memory.free,utilization.gpu' '--format=csv,noheader,nounits' 2>&1)
            Assert-WlbCondition ($LASTEXITCODE -eq 0) 'NVIDIA global query failed'
            $values=@(($text -join "`n") | ConvertFrom-Csv -Header index,name,uuid,driver,total_mib,used_mib,free_mib,utilization_percent)
            Assert-WlbCondition ($values.Count -eq 1 -and $values[0].name.Trim() -ceq 'NVIDIA GeForce RTX 5080 Laptop GPU') 'Ambiguous/unsupported NVIDIA device'
            $v=$values[0];$total=[long]$v.total_mib.Trim()*1MB;$used=[long]$v.used_mib.Trim()*1MB;$free=[long]$v.free_mib.Trim()*1MB;$util=[int]$v.utilization_percent.Trim()
            Assert-WlbCondition ($used -ge 0 -and $free -ge 0 -and $used+$free -le $total -and $util -ge 0 -and $util -le 100) 'Inconsistent NVIDIA global counters'
            $g.global=[ordered]@{index=[int]$v.index.Trim();name=$v.name.Trim();uuid=$v.uuid.Trim();driver=$v.driver.Trim();total_bytes=$total;used_bytes=$used;free_bytes=$free;unclassified_total_minus_used_free_bytes=$total-$used-$free;utilization_percent=$util;granularity_bytes=1MB;scope='GLOBAL_DRIVER_REPORTED_NOT_PID_ATTRIBUTED'};$g.status='AVAILABLE_GLOBAL'
            $procText=@(& $smi '--query-compute-apps=pid,process_name,used_gpu_memory' '--format=csv,noheader,nounits' 2>&1)
            Assert-WlbCondition ($LASTEXITCODE -eq 0) 'NVIDIA process query failed'
            $procRows=@($procText | Where-Object {-not [string]::IsNullOrWhiteSpace([string]$_)} | ConvertFrom-Csv -Header pid,image_name,memory_mib)
            $g.nv_processes=@(foreach($row in $procRows){$raw=$row.memory_mib.Trim();$available=$raw -match '^\d+$';[ordered]@{process_id=[int]$row.pid.Trim();image_name=$row.image_name.Trim();vram_bytes=$(if($available){[long]$raw*1MB}else{$null});status=$(if($available){'DRIVER_REPORTED_PROCESS_BYTES'}else{'UNAVAILABLE_NA'});raw_memory=$raw}})
            $g.nv_process_status='QUERY_SUCCEEDED_NOT_COMPLETE_GPU_ACTOR_COVERAGE'
        }catch{$g.errors+=@($_.Exception.Message)}
    }else{$g.errors+=@('Existing NVIDIA CLI unavailable; no installation permitted')}
    try{
        $rows=@(Get-CimInstance -ClassName Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory -OperationTimeoutSec 2)
        $adapters=@(Get-CimInstance -ClassName Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory -OperationTimeoutSec 2)
        $g.windows_processes=@(foreach($row in $rows){if($row.Name -match '^pid_(\d+)_(luid_.+_phys_\d+)$'){[ordered]@{process_id=[int]$Matches[1];adapter_key=$Matches[2];dedicated_bytes=[long]$row.DedicatedUsage;shared_bytes=[long]$row.SharedUsage;committed_bytes=[long]$row.TotalCommitted;scope='WDDM_PID_LUID_ACCOUNTING_NOT_VALIDATED_RTX_RESIDENT_VRAM'}}})
        $g.windows_adapters=@($adapters | ForEach-Object {[ordered]@{adapter_key=$_.Name;dedicated_bytes=[long]$_.DedicatedUsage;shared_bytes=[long]$_.SharedUsage;scope='WDDM_ADAPTER_ACCOUNTING'}})
        $g.windows_status='AVAILABLE_WDDM_ACCOUNTING_UNMAPPED'
    }catch{$g.errors+=@($_.Exception.Message)}
    return $g
}

function Initialize-WlbPassiveTcpReader {
    if($null -eq ('WlbPassive.Tcp' -as [type])){
        Add-Type -TypeDefinition @'
using System;
using System.Net;
using System.Collections.Generic;
using System.Runtime.InteropServices;
namespace WlbPassive {
 public class Listener { public int ProcessId,Port; public string Address; }
 public static class Tcp {
  [DllImport("iphlpapi.dll",SetLastError=true)] static extern uint GetExtendedTcpTable(IntPtr table,ref int size,bool order,int family,int tableClass,uint reserved);
  public static int DecodePort(uint n){return (int)(((n&255)<<8)|((n>>8)&255));}
  public static Listener[] Decode(byte[] data,int family){
   if(data.Length<4)throw new InvalidOperationException("Truncated TCP table");
   uint count=BitConverter.ToUInt32(data,0);int row=family==2?24:family==23?56:0;
   if(row==0||count>8192||4L+(long)count*row>data.Length)throw new InvalidOperationException("Invalid TCP table shape");
   var found=new List<Listener>();
   for(int i=0;i<count;i++){
    int pos=4+i*row;int port=DecodePort(BitConverter.ToUInt32(data,pos+(family==2?8:20)));
    uint state=BitConverter.ToUInt32(data,pos+(family==2?0:48));if(port!=8189||state!=2)continue;
    string address;
    if(family==2){var b=new byte[4];Array.Copy(data,pos+4,b,0,4);address=new IPAddress(b).ToString();}
    else{var b=new byte[16];Array.Copy(data,pos,b,0,16);address=new IPAddress(b,(long)BitConverter.ToUInt32(data,pos+16)).ToString();}
    uint pid=BitConverter.ToUInt32(data,pos+(family==2?20:52));
    found.Add(new Listener{ProcessId=checked((int)pid),Port=port,Address=address});
   }
   return found.ToArray();
  }
  static Listener[] ReadFamily(int family){
   int size=0;uint first=GetExtendedTcpTable(IntPtr.Zero,ref size,true,family,3,0);
   if(first!=122&&first!=0)throw new System.ComponentModel.Win32Exception((int)first);
   if(size<4||size>8388608)throw new InvalidOperationException("Unbounded TCP table");
   IntPtr buffer=Marshal.AllocHGlobal(size);
   try{int capacity=size;uint result=GetExtendedTcpTable(buffer,ref size,true,family,3,0);
    // No automatic buffer-growth retry; racing inventory is unavailable.
    if(result!=0)throw new System.ComponentModel.Win32Exception((int)result);
    if(size>capacity||size<4)throw new InvalidOperationException("TCP table changed during read");
    var bytes=new byte[size];Marshal.Copy(buffer,bytes,0,size);return Decode(bytes,family);
   }finally{Marshal.FreeHGlobal(buffer);}
  }
  public static Listener[] Read(){var all=new List<Listener>();all.AddRange(ReadFamily(2));all.AddRange(ReadFamily(23));return all.ToArray();}
 }
}
'@
    }
}

function Get-WlbPassivePortObservation {
    $clock=Get-WlbPassiveClock
    try{
        Initialize-WlbPassiveTcpReader
        $rows=@([WlbPassive.Tcp]::Read())
        $listeners=@($rows | ForEach-Object {[ordered]@{process_id=$_.ProcessId;listen_address=$_.Address;port=$_.Port;state='LISTEN'}})
        return [ordered]@{known=$true;occupied=($listeners.Count -gt 0);listeners=$listeners;target_listener_records=$rows.Count;captured_ms=$clock.monotonic_ms;source='WINDOWS_GETEXTENDEDTCP_TABLE_IPV4_IPV6_PASSIVE_NO_CONNECT';ownership_verified=$false}
    }catch{return [ordered]@{known=$false;occupied=$null;listeners=@();captured_ms=$clock.monotonic_ms;reason=$_.Exception.Message;ownership_verified=$false}}
}

function Get-WlbPassiveDiskObservation {
    $clock=Get-WlbPassiveClock
    $paths=@('tests\stage03g\evidence','runtimes\core\state\output','runtimes\core\state\logs','runtimes\core\scratch\temp')
    $rows=@();$total=[long]0;$count=0
    try{
        foreach($relative in $paths){
            $path=Join-Path $script:WlbRoot $relative;$null=Assert-WlbPath $path
            if(-not(Test-Path -LiteralPath $path)){$rows+=@([ordered]@{path=$path;exists=$false;files=0;bytes=[long]0});continue}
            $items=@(Get-ChildItem -LiteralPath $path -Force -Recurse)
            Assert-WlbCondition ($items.Count -le 5000 -and @($items | Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0}).Count -eq 0) 'Unbounded or linked telemetry directory'
            $files=@($items | Where-Object {-not $_.PSIsContainer});$bytes=[long](($files | Measure-Object Length -Sum).Sum);$total+=$bytes;$count+=$files.Count
            $rows+=@([ordered]@{path=$path;exists=$true;files=$files.Count;bytes=$bytes})
        }
        return [ordered]@{known=$true;aggregate_bytes=$total;files=$count;directories=$rows;captured_ms=$clock.monotonic_ms;source='SCOPED_LOGICAL_FILE_LENGTH_ENUMERATION_NOT_ALLOCATION_OR_ATOMIC_SNAPSHOT'}
    }catch{return [ordered]@{known=$false;aggregate_bytes=$null;captured_ms=$clock.monotonic_ms;directories=$rows;reason=$_.Exception.Message}}
}

function Get-WlbPassiveConcurrencyObservation {
    $clock=Get-WlbPassiveClock
    try{
        $rows=@();$all=[Diagnostics.Process]::GetProcesses()
        try{foreach($p in $all){$name=$p.ProcessName;if($name -match '^(python|LTX|Comfy)' -or $name -in @('blender','ffmpeg')){$rows+=@([ordered]@{process_id=$p.Id;name=$name})}}}finally{foreach($p in $all){$p.Dispose()}}
        return [ordered]@{known=$true;potential_heavy_processes=$rows;captured_ms=$clock.monotonic_ms;source='DOTNET_PROCESS_NAME_SNAPSHOT_POTENTIAL_COMPETITORS_NOT_RENDER_PROOF';exclusivity_proven=$false}
    }catch{return [ordered]@{known=$false;potential_heavy_processes=@();captured_ms=$clock.monotonic_ms;reason=$_.Exception.Message;exclusivity_proven=$false}}
}

function Get-WlbPassiveTelemetrySample {
    param([int[]]$ObservedProcessIds=@($PID))
    Assert-WlbCondition ($ObservedProcessIds.Count -ge 1 -and $ObservedProcessIds.Count -le 4) 'Bounded observed PID list required'
    $start=Get-WlbPassiveClock;$costs=[ordered]@{}
    $t=Get-WlbPassiveClock;$hostMemory=Get-WlbPassiveHostMemory;$costs.host_ms=(Get-WlbPassiveClock).monotonic_ms-$t.monotonic_ms
    $t=Get-WlbPassiveClock;$processes=@(foreach($id in $ObservedProcessIds){Get-WlbPassiveProcessObservation $id});$costs.process_ms=(Get-WlbPassiveClock).monotonic_ms-$t.monotonic_ms
    $t=Get-WlbPassiveClock;$gpu=Get-WlbPassiveGpuObservation;$costs.gpu_ms=(Get-WlbPassiveClock).monotonic_ms-$t.monotonic_ms
    $t=Get-WlbPassiveClock;$port=Get-WlbPassivePortObservation;$costs.port_ms=(Get-WlbPassiveClock).monotonic_ms-$t.monotonic_ms
    $t=Get-WlbPassiveClock;$concurrency=Get-WlbPassiveConcurrencyObservation;$costs.concurrency_ms=(Get-WlbPassiveClock).monotonic_ms-$t.monotonic_ms
    $t=Get-WlbPassiveClock;$disk=Get-WlbPassiveDiskObservation;$costs.disk_ms=(Get-WlbPassiveClock).monotonic_ms-$t.monotonic_ms
    $end=Get-WlbPassiveClock
    return [ordered]@{schema_version='wlb-passive-telemetry/0.1';source='PASSIVE_LOCAL_READ_ONLY';clock_id=$start.clock_id;start_ms=$start.monotonic_ms;end_ms=$end.monotonic_ms;collection_ms=$end.monotonic_ms-$start.monotonic_ms;utc=$end.utc;component_cost_ms=$costs;host=$hostMemory;processes=$processes;gpu=$gpu;port=$port;concurrency=$concurrency;disk=$disk;source_generation_freshness='NOT_VERIFIED';collection_is_runtime_watchdog=$false;authorized_to_execute=$false}
}

function Test-WlbPassiveProcessMatch {
    param($Expected,$Observed)
    try{
        foreach($o in @($Expected,$Observed)){
            Assert-WlbCondition ($o -is [Collections.IDictionary] -and $o.status -ceq 'AVAILABLE_PROCESS_ATTRIBUTED') 'Process observation unavailable'
            Assert-WlbJsonType $o.process_id Integer 'passive/process_id'
            foreach($key in @('creation_time_utc','image_path','image_sha256')){Assert-WlbJsonType $o[$key] String ('passive/'+$key)}
            Assert-WlbCondition ($o.image_sha256 -cmatch '^[a-f0-9]{64}$') 'Missing image fingerprint'
        }
        $match=$Expected.process_id -eq $Observed.process_id -and $Expected.creation_time_utc -ceq $Observed.creation_time_utc -and $Expected.image_path -ceq $Observed.image_path -and $Expected.image_sha256 -ceq $Observed.image_sha256
        return [ordered]@{identity_match=$match;launch_ownership_verified=$false;stop_authorized=$false;reason=$(if($match){'EXACT_OBSERVED_TUPLE_NOT_LIFECYCLE_AUTHORITY'}else{'PROCESS_IDENTITY_MISMATCH_OR_PID_REUSE'})}
    }catch{return [ordered]@{identity_match=$false;launch_ownership_verified=$false;stop_authorized=$false;reason=$_.Exception.Message}}
}

function Test-WlbPassiveResourcePreflight {
    # Feasibility only; strict attributed VRAM mode. No global-VRAM exception enabled.
    param($Policy,$Baseline,$Sample,$ExpectedProcess,$NowMs,$CandidateFreshnessMs)
    $reasons=[Collections.Generic.List[string]]::new()
    try{
        Assert-WlbStartupPolicy $Policy
        Assert-WlbJsonType $NowMs Integer 'passive/now_ms';Assert-WlbJsonType $CandidateFreshnessMs Integer 'candidate/freshness_ms'
        Assert-WlbCondition ($CandidateFreshnessMs -in @(1000,2000)) 'Only declared experimental freshness candidates'
        foreach($s in @($Baseline,$Sample)){
            Assert-WlbCondition ($s -is [Collections.IDictionary] -and $s.schema_version -ceq 'wlb-passive-telemetry/0.1' -and $s.source -ceq 'PASSIVE_LOCAL_READ_ONLY') 'Untrusted telemetry shape/source'
            Assert-WlbJsonType $s.clock_id String 'passive/clock_id';Assert-WlbCondition (-not [string]::IsNullOrWhiteSpace($s.clock_id)) 'Missing clock identity'
            foreach($key in @('start_ms','end_ms','collection_ms')){Assert-WlbJsonType $s[$key] Integer ('passive/'+$key);Assert-WlbCondition ($s[$key] -ge 0) 'Negative monotonic clock'}
            Assert-WlbCondition ($s.end_ms -ge $s.start_ms -and $s.collection_ms -eq $s.end_ms-$s.start_ms) 'Inconsistent collection clock'
            Assert-WlbCondition ($s.host.status -ceq 'AVAILABLE_GLOBAL') 'Host measurement missing'
            foreach($key in @('available_ram_bytes','commit_total_bytes','commit_limit_bytes','commit_headroom_bytes')){Assert-WlbJsonType $s.host[$key] Integer ('host/'+$key);Assert-WlbCondition ($s.host[$key] -ge 0) 'Negative host metric'}
            Assert-WlbCondition ($s.host.commit_limit_bytes-$s.host.commit_total_bytes -eq $s.host.commit_headroom_bytes) 'Inconsistent commit readings'
            if($s.host.available_ram_bytes -lt 8GB){$reasons.Add('AVAILABLE_RAM_BELOW_8_GIB')};if($s.host.commit_headroom_bytes -lt 10GB){$reasons.Add('COMMIT_HEADROOM_BELOW_10_GIB')}
            Assert-WlbCondition ($s.gpu.status -ceq 'AVAILABLE_GLOBAL') 'Global GPU measurement unavailable'
            foreach($key in @('used_bytes','free_bytes','total_bytes')){Assert-WlbJsonType $s.gpu.global[$key] Integer ('gpu/'+$key);Assert-WlbCondition ($s.gpu.global[$key] -ge 0) 'Negative GPU metric'}
            Assert-WlbCondition ($s.gpu.global.used_bytes+$s.gpu.global.free_bytes -le $s.gpu.global.total_bytes) 'Inconsistent global GPU counters'
            if($s.gpu.rtx_process_attribution -cne 'VERIFIED_RTX_PROCESS_RESIDENCY'){$reasons.Add('RTX_PROCESS_VRAM_ATTRIBUTION_NOT_VERIFIED')}
            Assert-WlbCondition ($s.port.known -is [bool] -and $s.port.known) 'Port state unknown'
            Assert-WlbCondition ($s.port.occupied -is [bool]) 'Port occupied type invalid'
            if($s.port.occupied){$reasons.Add('PORT_OCCUPIED')}
            Assert-WlbCondition ($s.concurrency.known -is [bool] -and $s.concurrency.known) 'Concurrency measurement unavailable'
            Assert-WlbJsonType $s.concurrency.exclusivity_proven Boolean 'concurrency/exclusivity'
            if($s.concurrency.potential_heavy_processes.Count -gt 0){$reasons.Add('POTENTIAL_HEAVY_PROCESS_REVIEW_REQUIRED')}
            if(-not $s.concurrency.exclusivity_proven){$reasons.Add('GPU_EXCLUSIVITY_NOT_PROVEN')}
            Assert-WlbCondition ($s.disk.known -is [bool] -and $s.disk.known) 'Disk measurement unavailable'
            Assert-WlbJsonType $s.disk.aggregate_bytes Integer 'disk/bytes';Assert-WlbCondition ($s.disk.aggregate_bytes -ge 0) 'Negative disk metric';if($s.disk.aggregate_bytes -gt 256MB){$reasons.Add('OUTPUT_LOG_TEMP_OVER_256_MIB')}
        }
        Assert-WlbCondition ($Baseline.clock_id -ceq $Sample.clock_id -and $Sample.start_ms -ge $Baseline.start_ms -and $NowMs -ge $Sample.end_ms) 'Clock domain/reversal error'
        if($NowMs-$Sample.start_ms -gt $CandidateFreshnessMs){$reasons.Add('TELEMETRY_RECEIPT_AGE_EXCEEDED')}
        if($Sample.source_generation_freshness -cne 'VERIFIED'){$reasons.Add('PROVIDER_GENERATION_FRESHNESS_NOT_VERIFIED')}
        if($NowMs-$Baseline.start_ms -ge 120000){$reasons.Add('STARTUP_DEADLINE_EXPIRED')}
        $proc=@($Sample.processes | Where-Object {$_.requested_pid -eq $ExpectedProcess.process_id})
        Assert-WlbCondition ($proc.Count -eq 1) 'Process metric unavailable or ambiguous'
        $match=Test-WlbPassiveProcessMatch $ExpectedProcess $proc[0];Assert-WlbCondition $match.identity_match 'Process ownership/identity lost'
        Assert-WlbJsonType $proc[0].private_bytes Integer 'process/private_bytes';Assert-WlbCondition ($proc[0].private_bytes -ge 0) 'Negative process metric';if($proc[0].private_bytes -gt 4GB){$reasons.Add('PROCESS_PRIVATE_OVER_4_GIB')}
        $commitDelta=$Sample.host.commit_total_bytes-$Baseline.host.commit_total_bytes;$vramDelta=$Sample.gpu.global.used_bytes-$Baseline.gpu.global.used_bytes
        if($commitDelta -lt 0 -or $vramDelta -lt 0){$reasons.Add('GLOBAL_COUNTER_REVERSED_OR_UNATTRIBUTABLE')}
        if($commitDelta -gt 4GB){$reasons.Add('GLOBAL_INCREMENTAL_COMMIT_OVER_4_GIB')};if($vramDelta -gt 2GB){$reasons.Add('GLOBAL_INCREMENTAL_VRAM_OVER_2_GIB')}
    }catch{$reasons.Add($_.Exception.Message)}
    return [ordered]@{state=$(if($reasons.Count){'BLOCKED'}else{'FEASIBILITY_THRESHOLDS_ONLY'});reasons=@($reasons | Select-Object -Unique);authorized_to_execute=$false;operational_parameters_bound=$false;candidate_freshness_ms=$CandidateFreshnessMs;global_delta_is_pid_attribution=$false;runtime_watchdog_verified=$false}
}

function Get-WlbMockOwnedStopRequest {
    param($Expected,$Observed,$Consent,[switch]$MockOnly)
    $authority=Test-WlbMockStopAuthority $Expected $Observed $Consent -MockOnly:$MockOnly
    return [ordered]@{request=$(if($authority.allowed){'MOCK_OWNED_STOP_REQUEST_ONLY'}else{'DENIED'});process_id=$Expected.process_id;reason=$authority.reason;real_stop_enabled=$false;process_killed=$false}
}

function Compare-WlbPassiveProcessCpu {
    param($Before,$After)
    try{
        $match=Test-WlbPassiveProcessMatch $Before $After
        Assert-WlbCondition $match.identity_match 'CPU delta cannot cross process identities'
        foreach($o in @($Before,$After)){Assert-WlbJsonType $o.cpu_total_100ns Integer 'cpu/cumulative_ticks';Assert-WlbJsonType $o.captured_ms Integer 'cpu/receipt_clock'}
        $elapsed=$After.captured_ms-$Before.captured_ms;$delta=$After.cpu_total_100ns-$Before.cpu_total_100ns
        Assert-WlbCondition ($elapsed -gt 0 -and $delta -ge 0) 'CPU counter/clock reset or insufficient interval'
        return [ordered]@{status='OBSERVED_CPU_DELTA_WITH_RATIO_ESTIMATE';cpu_seconds_delta=$delta/10000000.0;elapsed_ms=$elapsed;estimated_percent_of_one_core=($delta/10000.0/$elapsed)*100;cpu_cap=$null;precision='100NS_REPRESENTATION_NOT_PROVEN_SCHEDULER_RESOLUTION';includes_child_or_cim_provider_cpu=$false;operational_cpu_policy=$false}
    }catch{return [ordered]@{status='UNAVAILABLE';reason=$_.Exception.Message;cpu_cap=$null;operational_cpu_policy=$false}}
}
