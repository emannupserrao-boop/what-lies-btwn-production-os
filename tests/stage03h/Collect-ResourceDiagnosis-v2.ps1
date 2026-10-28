#requires -Version 7.6
# Finite read-only host observations. No lifecycle, configuration or GPU workload.
. (Join-Path $PSScriptRoot 'H.Common.ps1')
. (Join-Path $HRoot 'core\Wlb.RuntimeMonitor.ps1')
$started=Get-WlbPassiveClock
$memoryBefore=Get-WlbPassiveHostMemory
$token=[Security.Principal.WindowsIdentity]::GetCurrent()
try{$operator=[ordered]@{account=$token.Name;sid=$token.User.Value;human_confirmed=$false;bound=$false}}finally{$token.Dispose()}
$inventory=@(Get-CimInstance -ClassName Win32_Process -OperationTimeoutSec 2 | Select-Object ProcessId,ParentProcessId,Name,CreationDate,ExecutablePath,WorkingSetSize,PrivatePageCount)
$raw=@() # Prior raw-process counter attempt timed out; unavailable, no retry.
$rows=@(foreach($item in $inventory){
 $p=$null;$errors=@();$creation=$null;$image=$item.ExecutablePath;$identity='CIM_METADATA_ONLY';$ws=[long]$item.WorkingSetSize;$private=[long]$item.PrivatePageCount
 try{
  $p=[Diagnostics.Process]::GetProcessById([int]$item.ProcessId);$creation=$p.StartTime.ToUniversalTime().ToString('o');$image=$p.MainModule.FileName
  $p.Refresh();$ws=[long]$p.WorkingSet64;$private=[long]$p.PrivateMemorySize64
  if($creation -cne $p.StartTime.ToUniversalTime().ToString('o')){throw 'PID changed during metric read'}
  if($item.CreationDate -and [Math]::Abs(($item.CreationDate.ToUniversalTime()-[DateTime]::Parse($creation).ToUniversalTime()).TotalMilliseconds) -gt 1){throw 'CIM/native creation mismatch'}
  $identity='CIM_NATIVE_CREATION_IMAGE_MATCH_NOT_LAUNCH_OWNERSHIP'
 }catch{$errors+=@($_.Exception.Message);$identity='PARTIAL_OR_ACCESS_DENIED_NOT_TRUSTED_FOR_LIFECYCLE'}finally{if($p){$p.Dispose()}}
 $counters=@($raw|Where-Object {[int]$_.IDProcess -eq [int]$item.ProcessId -and $_.Name -ne '_Total'})
 [pscustomobject]@{process_id=[int]$item.ProcessId;parent_process_id=[int]$item.ParentProcessId;name=$item.Name;creation_time_utc=$creation;cim_creation_time_utc=$(if($item.CreationDate){$item.CreationDate.ToUniversalTime().ToString('o')}else{$null});image_path=$image;working_set_bytes=$ws;private_bytes=$private;private_working_set_bytes=$(if($counters.Count -eq 1){[long]$counters[0].WorkingSetPrivate}else{$null});private_ws_scope='PERF_RAW_ACCOUNTING_PID_JOIN_NONATOMIC_NO_CREATION_IN_COUNTER';identity_status=$identity;errors=$errors}
})
$byPid=@{};foreach($row in $rows){$byPid[$row.process_id]=$row}
$links=@(foreach($row in $rows){if($byPid.ContainsKey($row.parent_process_id)){
 $parent=$byPid[$row.parent_process_id]
 if($row.creation_time_utc -and $parent.creation_time_utc -and $row.image_path -and $parent.image_path -and $row.identity_status -like 'CIM_NATIVE*' -and $parent.identity_status -like 'CIM_NATIVE*' -and $row.image_path.Equals($parent.image_path,[StringComparison]::OrdinalIgnoreCase) -and [DateTime]::Parse($parent.creation_time_utc) -le [DateTime]::Parse($row.creation_time_utc)){
  [pscustomobject]@{child=$row.process_id;parent=$parent.process_id;image=$row.image_path;evidence='SAME_IMAGE_PARENT_ID_AND_EARLIER_CREATION_SNAPSHOT_NOT_HISTORICAL_PROOF'}
 }
}})
$groups=@($rows|Where-Object {$_.image_path -and $_.identity_status -like 'CIM_NATIVE*'}|Group-Object image_path|ForEach-Object {
 [pscustomobject]@{image_path=$_.Name;pids=@($_.Group.process_id);process_count=$_.Count;sum_working_set_bytes=[long](($_.Group|Measure-Object working_set_bytes -Sum).Sum);sum_private_bytes=[long](($_.Group|Measure-Object private_bytes -Sum).Sum);sum_private_working_set_bytes=[long](($_.Group|Measure-Object private_working_set_bytes -Sum).Sum);group_basis='EXACT_IMAGE_PATH_NOT_ALL_APP_DESCENDANTS_OR_LAUNCH_OWNERSHIP';reclaimable_ram_bytes=$null}
}|Sort-Object sum_working_set_bytes -Descending)
$memoryAfter=Get-WlbPassiveHostMemory
$gpu=Get-WlbPassiveGpuObservation
$rawGpuErrors=@();try{$rawGpu=@(Get-CimInstance -ClassName Win32_PerfRawData_GPUPerformanceCounters_GPUProcessMemory -OperationTimeoutSec 2|Select-Object Name,DedicatedUsage,SharedUsage,TotalCommitted,Timestamp_Sys100NS,Timestamp_PerfTime,Frequency_PerfTime)}catch{$rawGpu=@();$rawGpuErrors=@($_.Exception.Message)}
$video=@(Get-CimInstance -ClassName Win32_VideoController -OperationTimeoutSec 2|Select-Object Name,PNPDeviceID,AdapterCompatibility,DriverVersion)
Save-HNew 'ram-diagnosis.json' ([ordered]@{started=$started;completed=(Get-WlbPassiveClock);memory_before=$memoryBefore;memory_after=$memoryAfter;operator=$operator;process_rows=$rows;working_set_ranking=@($rows|Sort-Object working_set_bytes -Descending);image_groups=$groups;same_image_parent_links=$links;raw_process_counter_receipts=$raw;private_ws_provider_status='UNAVAILABLE_PRIOR_TIMEOUT_NO_RETRY';aggregation_is_reclaimable=$false;kernel_cache_and_shared_not_separately_attributed=$true;process_read_count=$rows.Count})
Save-HNew 'gpu-diagnosis.json' ([ordered]@{receipt=(Get-WlbPassiveClock);canonical_gpu=$gpu;raw_gpu_process_counters=$rawGpu;raw_gpu_errors=$rawGpuErrors;video_controllers=$video;provider_timestamp_is_metric_generation_proof=$false;runtime_or_device_context_created=$false})
[pscustomobject]@{ram_before_gib=[Math]::Round($memoryBefore.available_ram_bytes/1GB,3);ram_after_gib=[Math]::Round($memoryAfter.available_ram_bytes/1GB,3);commit_gib=[Math]::Round($memoryAfter.commit_total_bytes/1GB,3);headroom_gib=[Math]::Round($memoryAfter.commit_headroom_bytes/1GB,3);processes=$rows.Count;top=@($rows|Sort-Object working_set_bytes -Descending|Select-Object -First 12 process_id,name,working_set_bytes,private_bytes,private_working_set_bytes);gpu_status=$gpu.status;gpu_processes=$gpu.nv_processes.Count;gpu_na=@($gpu.nv_processes|Where-Object {$_.status -eq 'UNAVAILABLE_NA'}).Count}|ConvertTo-Json -Depth 8
