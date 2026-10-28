#requires -Version 7.6
. (Join-Path $PSScriptRoot 'H.Common.ps1')
$smi=Join-Path $env:SystemRoot 'System32\nvidia-smi.exe';$measurements=[Collections.Generic.List[object]]::new()
foreach($iteration in 0..2){foreach($kind in @('NVIDIA_GLOBAL','NVIDIA_PROCESS','WDDM_PROCESS','WDDM_ADAPTER')){
 $timer=[Diagnostics.Stopwatch]::StartNew();$cpu=[Diagnostics.Process]::GetCurrentProcess();$before=$cpu.TotalProcessorTime.TotalMilliseconds;$errors=@();$data=@()
 try{
  switch($kind){
   'NVIDIA_GLOBAL' {$data=@(& $smi '--query-gpu=index,name,uuid,driver_version,memory.total,memory.used,memory.free,utilization.gpu' '--format=csv,noheader,nounits' 2>&1);if($LASTEXITCODE -ne 0){throw 'NVIDIA global failed'}}
   'NVIDIA_PROCESS' {$data=@(& $smi '--query-compute-apps=pid,process_name,used_gpu_memory' '--format=csv,noheader,nounits' 2>&1);if($LASTEXITCODE -ne 0){throw 'NVIDIA process failed'}}
   'WDDM_PROCESS' {$data=@(Get-CimInstance -ClassName Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory -OperationTimeoutSec 2|Select-Object Name,DedicatedUsage,SharedUsage,TotalCommitted,Timestamp_Sys100NS)}
   'WDDM_ADAPTER' {$data=@(Get-CimInstance -ClassName Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory -OperationTimeoutSec 2|Select-Object Name,DedicatedUsage,SharedUsage,Timestamp_Sys100NS)}
  }
 }catch{$errors+=@($_.Exception.Message)}
 $duration=$timer.Elapsed.TotalMilliseconds;$cpu.Refresh();$cpuDelta=$cpu.TotalProcessorTime.TotalMilliseconds-$before;$cpu.Dispose()
 $measurements.Add([pscustomobject]@{iteration=$iteration;kind=$kind;duration_ms=$duration;observer_cpu_ms=$cpuDelta;data=$data;errors=$errors;utc=[DateTime]::UtcNow.ToString('o');provider_generation_age_verified=$false})
}}
Save-HNew 'gpu-component-probes.json' @($measurements)
$engineErrors=@();$engines=@();try{$engines=@(Get-CimInstance -ClassName Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -OperationTimeoutSec 2|Where-Object {$_.UtilizationPercentage -gt 0}|Select-Object Name,UtilizationPercentage,Timestamp_Sys100NS)}catch{$engineErrors+=@($_.Exception.Message)}
Save-HNew 'gpu-engine-active-observation.json' @{utc=[DateTime]::UtcNow.ToString('o');positive_engine_rows=$engines;errors=$engineErrors;zero_engines_does_not_prove_no_activity=$true;sampling_window_unknown=$true;actor_identity_or_exclusivity_proof=$false}
$ram=Read-HJson (Join-Path $HEvidence 'ram-diagnosis.json')
$groups=@(foreach($g in $ram.image_groups){$g.sum_private_working_set_bytes=$null;$g.private_working_set_status='UNAVAILABLE_PRIOR_PROVIDER_TIMEOUT_NOT_ZERO';$g})
Save-HNew 'memory-groups-normalized.json' @{groups=$groups;original_empty_sum_was_not_measurement=$true;reclaimable_ram_bytes=$null;working_set_can_include_shared_pages=$true}
$measurements|Group-Object kind|ForEach-Object {[pscustomobject]@{kind=$_.Name;n=$_.Count;mean_ms=($_.Group.duration_ms|Measure-Object -Average).Average;max_ms=($_.Group.duration_ms|Measure-Object -Maximum).Maximum;errors=@($_.Group|Where-Object {$_.errors.Count}).Count}}|ConvertTo-Json
