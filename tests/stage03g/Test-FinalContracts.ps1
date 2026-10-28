# Final-source type/readiness/owned-monitor checks; no real process.
#requires -Version 7.6
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
. (Join-Path $Root 'core\Wlb.RuntimeMonitor.ps1')
function Clone($v){return ,(ConvertTo-Json -InputObject $v -Depth 60 | ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
$rows=[Collections.Generic.List[object]]::new()
function Row([string]$id,$actual,[bool]$pass){$rows.Add([pscustomobject]@{id=$id;expectation='Strict static contract or owned mock monitoring; no execution';actual=$actual;status=$(if($pass){'PASS'}else{'FAIL'});evidence_kind='EXECUTED_FINAL_SOURCE_STATIC_OR_MOCK'})}
$policy=Read-WlbJson (Join-Path $Root 'policy\startup-policy.json');$identity=Read-WlbJson (Join-Path $Root 'policy\startup-identity.json')
$hash=(Get-FileHash -LiteralPath (Join-Path $Root 'policy\startup-policy.json') -Algorithm SHA256).Hash.ToLowerInvariant();$runtime=(Get-FileHash -LiteralPath (Join-Path $Root 'policy\runtime-lock.json') -Algorithm SHA256).Hash.ToLowerInvariant()
$plan=Get-WlbFixedStartupPlan $policy $identity $hash $runtime;Row 'FINAL-PLAN-STATIC' $plan (-not $plan.real_execution_enabled)
foreach($kind in @('ROOT_ARRAY','PATH_ARRAY','NO_HASH','EXTRA','BOOL_STRING')){
    $bad=Clone $identity
    switch($kind){'ROOT_ARRAY'{$bad=@($bad)};'PATH_ARRAY'{$bad.main_path=@($bad.main_path)};'NO_HASH'{$bad.python.sha256=''};'EXTRA'{$bad.unsafe_command='NOT_EXECUTED'};'BOOL_STRING'{$bad.snapshot.exists='false'}}
    try{$null=Get-WlbFixedStartupPlan $policy $bad $hash $runtime;Row ('FINAL-IDENTITY-'+$kind) 'UNEXPECTED_ACCEPT' $false}catch{Row ('FINAL-IDENTITY-'+$kind) $_.Exception.Message ($_.Exception.Message -match 'BLOCKED:')}
}
foreach($kind in @('BOOL_STRING','BUDGET_STRING','MISSING','EXTRA')){
    $bad=Clone $policy
    switch($kind){'BOOL_STRING'{$bad.real_startup_enabled='false'};'BUDGET_STRING'{$bad.budget.min_available_ram_gib='8'};'MISSING'{$null=$bad.Remove('required_gate')};'EXTRA'{$bad.shell='NOT_EXECUTED'}}
    try{Assert-WlbStartupPolicy $bad;Row ('FINAL-STARTUP-POLICY-'+$kind) 'UNEXPECTED_ACCEPT' $false}catch{Row ('FINAL-STARTUP-POLICY-'+$kind) $_.Exception.Message ($_.Exception.Message -match 'BLOCKED:')}
}
$mock=Clone $policy;foreach($key in $mock.human_parameters.Keys){$mock.human_parameters[$key].status='INJECTED_TEST_ONLY';$mock.human_parameters[$key].value='TEST_ONLY'};$mock.human_parameters.polling_cadence_ms.value=100;$mock.human_parameters.telemetry_freshness_ms.value=500;$mock.human_parameters.cpu_budget.value='OBSERVE_ONLY_TEST'
$expected=@{process_id=424242;creation_time_utc='2099-01-01T00:00:00.0000000Z';image_path=$plan.executable;image_sha256=$plan.python_sha256;owner_token='00000000-0000-4000-8000-000000000002'}
$sample=@{schema_version='wlb-startup-telemetry/0.1';source='INJECTED_TEST_ONLY';clock_id='final-mock';sampled_ms=0;available_ram_bytes=[long](10GB);commit_headroom_bytes=[long](12GB);total_commit_bytes=[long](16GB);private_bytes=[long]0;vram_bytes=[long](1GB);aggregate_output_log_temp_bytes=[long]0;foreign_gpu_jobs=0;heavy_processes_active=$false;attribution_known=$true}
$consent=@{kind='MOCK_ONLY';scope='G4_STARTUP_ONLY';policy_sha256=$hash;runtime_lock_sha256=$runtime;python_sha256=$plan.python_sha256;single_attempt=$true;stop_owned_allowed=$true;owner_token=$expected.owner_token}
$observed=Clone $expected;$observed.process_id=999999;$current=Clone $sample;$current.sampled_ms=100;$ctx=@{stops=0}
$out=Invoke-WlbInjectedWatchdog $mock $sample $expected $consent {$current} {100} {$observed} {param($p) $ctx.stops++} {param($ms)}
Row 'FINAL-OWNERSHIP-LOST-WITH-HEALTHY-RESOURCES' $out ($out.state -ceq 'BLOCKED' -and $ctx.stops -eq 0 -and $out.history[0].reasons -contains 'OWNERSHIP_LOST_OR_UNKNOWN')
$out=Invoke-WlbInjectedWatchdog $mock $sample $expected $consent {$current} {100} {$expected} {param($p) $ctx.stops++} {param($ms)} -MaxTicks 1
Row 'FINAL-OWNED-HEALTHY-MOCK-WINDOW' $out ($out.state -ceq 'MOCK_WINDOW_COMPLETE' -and -not $out.real_process_stopped)
$baseline=& (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode StaticReview;Row 'FINAL-DRAFT-BASELINE' $baseline (-not $baseline.executable)
$json=ConvertTo-Json -InputObject @($rows) -Depth 50
[IO.File]::WriteAllText((Join-Path $Root 'tests\stage03g\evidence\final-contract-results.json'),$json,[Text.UTF8Encoding]::new($false))
$rows | ConvertTo-Json -Depth 15
if(@($rows | Where-Object {$_.status -eq 'FAIL'}).Count){exit 1}
