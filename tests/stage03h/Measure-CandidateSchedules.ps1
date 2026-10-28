#requires -Version 7.6
# Finite timing experiment, candidate schedules only. Split reads remain sequential
# here: this does not implement a nonblocking operational supervisor or policy.
. (Join-Path $PSScriptRoot 'H.Common.ps1')
. (Join-Path $HRoot 'core\Wlb.RuntimeMonitor.ps1')
function CpuMs { $p=[Diagnostics.Process]::GetCurrentProcess();try{return $p.TotalProcessorTime.TotalMilliseconds}finally{$p.Dispose()} }
function Stamp { return (Get-WlbPassiveClock).monotonic_ms }
$identity=Get-WlbPassiveProcessObservation $PID
$c0=CpuMs;$cold=Get-WlbPassiveTelemetrySample -ObservedProcessIds @($PID);$coldCpu=(CpuMs)-$c0
Save-HNew 'cold-sample.json' @{sample=$cold;observer_cpu_ms=$coldCpu;identity=$identity;cold_first_full_sample_after_identity_read=$true}
$uniform=[Collections.Generic.List[object]]::new();$schedule=Stamp;$cpuBegin=CpuMs
for($i=0;$i -lt 12;$i++){
 $due=$schedule+$i*500;$wait=$due-(Stamp);if($wait -gt 0){Start-Sleep -Milliseconds $wait}
 $begin=Stamp;$cpu=CpuMs;$sample=Get-WlbPassiveTelemetrySample -ObservedProcessIds @($PID)
 $uniform.Add([ordered]@{index=$i;due_ms=$due;start_lateness_ms=$begin-$due;sample=$sample;observer_cpu_ms=(CpuMs)-$cpu;receipt_age_at_delivery_ms=(Stamp)-$sample.start_ms})
}
$uniformWindow=@{elapsed_ms=(Stamp)-$schedule;cpu_ms=(CpuMs)-$cpuBegin}
Save-HNew 'uniform-500-samples.json' @($uniform)
$split=[Collections.Generic.List[object]]::new();$schedule=Stamp;$cpuBegin=CpuMs;$slow=$null;$slowStart=[long]0;$slowEnd=[long]0
for($i=0;$i -lt 12;$i++){
 $due=$schedule+$i*500;$wait=$due-(Stamp);if($wait -gt 0){Start-Sleep -Milliseconds $wait}
 $begin=Stamp;$cpu=CpuMs;$fastStart=Stamp
 $hostReading=Get-WlbPassiveHostMemory;$process=Get-WlbPassiveProcessObservation $PID;$port=Get-WlbPassivePortObservation
 $fastEnd=Stamp;$fastCpu=(CpuMs)-$cpu;$refresh=($i%2 -eq 0);$slowCosts=[ordered]@{}
 if($refresh){
  $slowStart=Stamp;$t=Stamp;$gpu=Get-WlbPassiveGpuObservation;$slowCosts.gpu_ms=(Stamp)-$t
  $t=Stamp;$concurrency=Get-WlbPassiveConcurrencyObservation;$slowCosts.concurrency_ms=(Stamp)-$t
  $t=Stamp;$disk=Get-WlbPassiveDiskObservation;$slowCosts.disk_ms=(Stamp)-$t;$slowEnd=Stamp
  $slow=@{gpu=$gpu;concurrency=$concurrency;disk=$disk}
 }
 $end=Stamp
 $split.Add([ordered]@{index=$i;due_ms=$due;start_lateness_ms=$begin-$due;fast_start_ms=$fastStart;fast_end_ms=$fastEnd;fast_collection_ms=$fastEnd-$fastStart;fast_observer_cpu_ms=$fastCpu;total_tick_ms=$end-$begin;observer_cpu_ms=(CpuMs)-$cpu;host=$hostReading;process=$process;port=$port;slow_refresh=$refresh;slow_acquired_start_ms=$slowStart;slow_acquired_end_ms=$slowEnd;slow_receipt_age_at_delivery_ms=$end-$slowStart;slow_component_cost_ms=$slowCosts;slow=$slow;provider_generation_age='NOT_VERIFIED';schedule_is_operational=$false;cache_changes_canonical_source=$false})
}
$splitWindow=@{elapsed_ms=(Stamp)-$schedule;cpu_ms=(CpuMs)-$cpuBegin}
Save-HNew 'split-500-fast-1000-slow-samples.json' @($split)
function Stats($v){$a=@($v|Sort-Object);return [ordered]@{n=$a.Count;min_ms=$a[0];max_ms=$a[-1];mean_ms=($a|Measure-Object -Average).Average;p95_nearest_rank_ms=$a[[Math]::Ceiling($a.Count*0.95)-1];p95_is_short_sample_not_upper_bound=$true}}
$u=Read-HJson (Join-Path $HEvidence 'uniform-500-samples.json');$s=Read-HJson (Join-Path $HEvidence 'split-500-fast-1000-slow-samples.json')
$summary=[ordered]@{uniform=@{collection=(Stats @($u|ForEach-Object {$_.sample.collection_ms}));observer_cpu_per_tick=(Stats @($u|ForEach-Object {$_.observer_cpu_ms}));window=$uniformWindow;max_start_lateness_ms=($u.start_lateness_ms|Measure-Object -Maximum).Maximum;overruns=@($u|Where-Object {$_.sample.collection_ms -gt 500}).Count;gpu=(Stats @($u|ForEach-Object {$_.sample.component_cost_ms.gpu_ms}));process=(Stats @($u|ForEach-Object {$_.sample.component_cost_ms.process_ms}));port=(Stats @($u|ForEach-Object {$_.sample.component_cost_ms.port_ms}));disk=(Stats @($u|ForEach-Object {$_.sample.component_cost_ms.disk_ms}));concurrency=(Stats @($u|ForEach-Object {$_.sample.component_cost_ms.concurrency_ms}))};split=@{total_tick=(Stats $s.total_tick_ms);fast_collection=(Stats $s.fast_collection_ms);observer_cpu_per_tick=(Stats $s.observer_cpu_ms);window=$splitWindow;max_start_lateness_ms=($s.start_lateness_ms|Measure-Object -Maximum).Maximum;overruns=@($s|Where-Object {$_.total_tick_ms -gt 500}).Count;slow_refreshes=@($s|Where-Object slow_refresh).Count;max_slow_receipt_age_ms=($s.slow_receipt_age_at_delivery_ms|Measure-Object -Maximum).Maximum};ram_min_gib=(($u|ForEach-Object {$_.sample.host.available_ram_bytes/1GB})+@($s|ForEach-Object {$_.host.available_ram_bytes/1GB})|Measure-Object -Minimum).Minimum;ram_max_gib=(($u|ForEach-Object {$_.sample.host.available_ram_bytes/1GB})+@($s|ForEach-Object {$_.host.available_ram_bytes/1GB})|Measure-Object -Maximum).Maximum;canonical_monitor_sha256=(Get-FileHash -LiteralPath (Join-Path $HRoot 'core\Wlb.RuntimeMonitor.ps1')).Hash.ToLowerInvariant();uniform_full_samples=12;split_fast_samples=12;split_slow_samples=6;cold_samples=1;provider_generation_freshness='NOT_VERIFIED';real_runtime_watchdog=$false;cpu_excludes_nvidia_helpers_and_cim_provider=$true;sequential_split_can_still_block=$true;canonical_disk_paths_stage03g_unchanged=$true}
Save-HNew 'sampling-summary.json' $summary
$last=$u[-1].sample;$baseline=$u[0].sample
$decision=Test-WlbPassiveResourcePreflight (Read-WlbJson (Join-Path $HRoot 'policy\startup-policy.json')) $baseline $last $identity $last.end_ms 2000
Save-HNew 'real-preflight.json' @{decision=$decision;baseline_index=0;sample_index=11;observer_identity=$identity;now_ms=$last.end_ms;candidate_receipt_age_ms=2000;source='REAL_UNIFORM_PASSIVE_NOT_RUNTIME'}
$summary|ConvertTo-Json -Depth 12
