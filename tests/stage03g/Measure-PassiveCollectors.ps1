#requires -Version 7.6
# Two finite sampling experiments only. No runtime, process lifecycle, network or retries.
[CmdletBinding()]
param([ValidateSet('initial','native')][string]$Run='initial')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS';$Evidence=Join-Path $Root 'tests\stage03g\evidence'
if($Run -ceq 'native'){$Evidence=Join-Path $Evidence 'native';if(Test-Path -LiteralPath $Evidence){throw 'Fresh native measurement namespace required'};$null=New-Item -ItemType Directory -Path $Evidence}
. (Join-Path $Root 'core\Wlb.RuntimeMonitor.ps1')
function WriteNew([string]$name,$value){$p=Join-Path $Evidence $name;$s=[IO.File]::Open($p,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write([Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject $value -Depth 50)));$s.Flush($true)}finally{$s.Dispose()}}
function Stats($values){$sorted=@($values | Sort-Object);if(-not $sorted.Count){return $null};[ordered]@{count=$sorted.Count;min=$sorted[0];mean=($sorted | Measure-Object -Average).Average;p50=$sorted[[Math]::Ceiling($sorted.Count*0.5)-1];p95=$sorted[[Math]::Ceiling($sorted.Count*0.95)-1];max=$sorted[-1]}}
$account=[Security.Principal.WindowsIdentity]::GetCurrent()
WriteNew 'observed-session.json' ([ordered]@{account=$account.Name;sid=$account.User.Value;observer_pid=$PID;source='CURRENT_WINDOWS_TOKEN_READ_ONLY';human_confirmation='ABSENT';independent_authentication=$false;operational_identity_bound=$false})
$cold=Get-WlbPassiveTelemetrySample @($PID)
WriteNew 'cold-sample.json' $cold
if($cold.host.status -cne 'AVAILABLE_GLOBAL' -or $cold.gpu.status -cne 'AVAILABLE_GLOBAL' -or -not $cold.port.known -or -not $cold.disk.known -or -not $cold.concurrency.known){throw 'BLOCKED: Cold collector unavailable; evidence retained; no retry'}
$summaries=@();$samples=[Collections.Generic.List[object]]::new()
foreach($interval in @(250,500)){
    $group=[Collections.Generic.List[object]]::new();$origin=(Get-WlbPassiveClock).monotonic_ms
    for($i=0;$i -lt 12;$i++){
        $due=$origin+$i*$interval;$remaining=$due-(Get-WlbPassiveClock).monotonic_ms
        if($remaining -gt 0){[Threading.Thread]::Sleep([int]$remaining)}
        $observer=[Diagnostics.Process]::GetCurrentProcess();$cpuBefore=$observer.TotalProcessorTime.Ticks;$observer.Dispose()
        $sample=Get-WlbPassiveTelemetrySample @($PID)
        $observer=[Diagnostics.Process]::GetCurrentProcess();$cpuAfter=$observer.TotalProcessorTime.Ticks;$observer.Dispose()
        $row=[ordered]@{sample_id=('{0}-{1:D2}' -f $interval,$i);candidate_interval_ms=$interval;scheduled_ms=$due;start_lateness_ms=[Math]::Max(0,$sample.start_ms-$due);collection_over_interval=($sample.collection_ms -gt $interval);age_from_first_read_at_completion_ms=$sample.collection_ms;receipt_within_1000_ms=($sample.collection_ms -le 1000);receipt_within_2000_ms=($sample.collection_ms -le 2000);source_generation_age_verified=$false;observer_cpu_ms=($cpuAfter-$cpuBefore)/10000.0;sample=$sample}
        $group.Add($row);$samples.Add($row)
        if($sample.host.status -cne 'AVAILABLE_GLOBAL' -or $sample.gpu.status -cne 'AVAILABLE_GLOBAL' -or -not $sample.port.known -or -not $sample.disk.known -or -not $sample.concurrency.known){WriteNew ('partial-'+$interval+'.json') @($group);throw 'BLOCKED: Collector failure during finite experiment; no retry'}
    }
    $cost=[ordered]@{};foreach($key in @('host_ms','process_ms','gpu_ms','port_ms','concurrency_ms','disk_ms')){$cost[$key]=Stats @($group | ForEach-Object {$_.sample.component_cost_ms[$key]})}
    $cpu=Compare-WlbPassiveProcessCpu $group[0].sample.processes[0] $group[-1].sample.processes[0]
    $summaries+=@([ordered]@{candidate_interval_ms=$interval;samples=12;collection_ms=Stats @($group | ForEach-Object {$_.sample.collection_ms});start_lateness_ms=Stats @($group | ForEach-Object {$_.start_lateness_ms});observer_cpu_ms=Stats @($group | ForEach-Object {$_.observer_cpu_ms});component_cost_ms=$cost;overrun_samples=@($group | Where-Object {$_.collection_over_interval}).Count;receipt_age_over_1000_ms=@($group | Where-Object {-not $_.receipt_within_1000_ms}).Count;receipt_age_over_2000_ms=@($group | Where-Object {-not $_.receipt_within_2000_ms}).Count;ram_available_bytes=Stats @($group | ForEach-Object {$_.sample.host.available_ram_bytes});commit_headroom_bytes=Stats @($group | ForEach-Object {$_.sample.host.commit_headroom_bytes});gpu_used_bytes=Stats @($group | ForEach-Object {$_.sample.gpu.global.used_bytes});cpu_observation=$cpu;provider_generation_freshness='NOT_VERIFIED';watchdog_applied_to_real_process=$false;operational_interval_chosen=$false})
    WriteNew ('samples-'+$interval+'.json') @($group)
}
$policy=Read-WlbJson (Join-Path $Root 'policy\startup-policy.json')
$last=$samples[-1].sample;$strict=Test-WlbPassiveResourcePreflight $policy $cold $last $cold.processes[0] (Get-WlbPassiveClock).monotonic_ms 2000
WriteNew 'live-preflight.json' $strict
WriteNew 'sampling-summary.json' ([ordered]@{collector_source_sha256=(Get-FileHash -LiteralPath (Join-Path $Root 'core\Wlb.RuntimeMonitor.ps1')).Hash.ToLowerInvariant();experiment_version=$Run;cold_collection_ms=$cold.collection_ms;experiments=$summaries;total_samples=24;physical_memory_source='PSAPI';operator_parameters_unchanged=$true;gpu_attribution='NOT_VERIFIED';runtime_started=$false;python_executed=$false;gpu_jobs=$false;no_retry=$true})
$summaries | ConvertTo-Json -Depth 12
$strict | ConvertTo-Json -Depth 8
