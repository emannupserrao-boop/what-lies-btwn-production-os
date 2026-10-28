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
