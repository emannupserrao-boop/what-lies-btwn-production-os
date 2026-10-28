#requires -Version 7.6
. (Join-Path $PSScriptRoot 'H.Common.ps1')
. (Join-Path $PSScriptRoot 'Review-DesignModels.ps1')
$rows=[Collections.Generic.List[object]]::new()
function Check([string]$id,$actual,[bool]$ok){$rows.Add([pscustomobject]@{id=$id;status=$(if($ok){'PASS'}else{'FAIL'});evidence_kind='SIMULATED_TEST_ONLY_NOT_RUNTIME';actual=$actual})}
$f=@{kind='SIMULATED_TEST_ONLY';scope='G4_STARTUP_NO_MODELS';model_or_job_requested=$false;now_ms=[long]1000;baseline_acquired_ms=[long]0;sample_acquired_ms=[long]900;available_ram_bytes=[long](8GB);commit_headroom_bytes=[long](10GB);baseline_commit_bytes=[long](16GB);sample_commit_bytes=[long](20GB);private_bytes=[long](4GB);baseline_vram_bytes=[long](1GB);sample_vram_bytes=[long](3GB);aggregate_bytes=[long](256MB);valid_global_baseline=$true;data_consistent=$true;provider_proxy_explicitly_assumed_for_simulation=$true;actor_inventory_known=$true;activity_classified=$true;heavy_gpu_work=$false;actors_changed=$false;process_identity_matches=$true;port_identity_known=$true}
$result=Test-HProxyReviewModel $f;Check 'PROPOSED-PROXY-EXACT-CAPS-NO-AUTHORITY' $result ($result.state -ceq 'SIMULATED_THRESHOLDS_ONLY' -and -not $result.authorized_to_execute -and -not $result.global_proxy_enabled)
$mutations=[ordered]@{
 'PROXY-REAL-INPUT-DENIED'={param($x)$x.kind='PASSIVE_LOCAL_READ_ONLY'}
 'PROXY-G5-DENIED'={param($x)$x.scope='G5'}
 'PROXY-ALPHA-DENIED'={param($x)$x.scope='ALPHA'}
 'PROXY-MODEL-DENIED'={param($x)$x.model_or_job_requested=$true}
 'PROXY-NO-BASELINE'={param($x)$x.valid_global_baseline=$false}
 'PROXY-INCONSISTENT'={param($x)$x.data_consistent=$false}
 'PROXY-VRAM-2GIB-PLUS1'={param($x)$x.sample_vram_bytes++}
 'PROXY-UNKNOWN-ACTORS'={param($x)$x.actor_inventory_known=$false}
 'PROXY-UNKNOWN-ACTIVITY'={param($x)$x.activity_classified=$false}
 'PROXY-FOREIGN-GPU-WORK'={param($x)$x.heavy_gpu_work=$true}
 'PROXY-BACKGROUND-ACTOR-CHANGE'={param($x)$x.actors_changed=$true}
 'PROXY-NO-PROVIDER-AGE-DECISION'={param($x)$x.provider_proxy_explicitly_assumed_for_simulation=$false}
 'PROXY-STALE'={param($x)$x.now_ms=[long]2901}
 'PROXY-COUNTER-DECREASE'={param($x)$x.sample_vram_bytes=[long]0}
 'PROXY-RAM-BELOW'={param($x)$x.available_ram_bytes--}
 'PROXY-COMMIT-HEADROOM-BELOW'={param($x)$x.commit_headroom_bytes--}
 'PROXY-COMMIT-OVER'={param($x)$x.sample_commit_bytes++}
 'PROXY-PRIVATE-OVER'={param($x)$x.private_bytes++}
 'PROXY-DISK-OVER'={param($x)$x.aggregate_bytes++}
 'PROXY-PORT-UNKNOWN'={param($x)$x.port_identity_known=$false}
 'PROXY-PID-REUSED'={param($x)$x.process_identity_matches=$false}
 'PROXY-NONINTEGER'={param($x)$x.available_ram_bytes='8589934592'}
 'PROXY-MISSING'={param($x)$x.Remove('sample_vram_bytes')}
}
foreach($entry in $mutations.GetEnumerator()){$x=Copy-HObject $f;& $entry.Value $x;$result=Test-HProxyReviewModel $x;Check $entry.Key $result ($result.state -ceq 'BLOCKED_SIMULATION' -and -not $result.authorized_to_execute)}
$x=Copy-HObject $f;$x.now_ms=[long]2900;$result=Test-HProxyReviewModel $x;Check 'PROXY-2000MS-EXACT' $result ($result.state -ceq 'SIMULATED_THRESHOLDS_ONLY')
$x=Copy-HObject $f;$x.now_ms=[long]120000;$x.sample_acquired_ms=[long]119900;$result=Test-HProxyReviewModel $x;Check 'PROXY-120S-EXACT' $result ($result.reasons -contains 'DEADLINE')
$w=@{kind='SIMULATED_TEST_ONLY';now_ms=[long]1000;previous_now_ms=[long]980;startup_started_ms=[long]0;last_acquired_ms=[long]900;sampler_failed=$false;queue_length=1;sequence=2;previous_sequence=1}
$result=Test-HSupervisorReviewModel $w;Check 'SUPERVISOR-HEALTHY-SIM' $result ($result.state -ceq 'OBSERVE_SIMULATION')
foreach($scenario in @('HUNG','FAILED','DEADLINE','CACHE_RECEIPT_REWRITE','QUEUE','SEQUENCE','CLOCK')){
 $x=Copy-HObject $w
 switch($scenario){
  'HUNG'{$x.now_ms=[long]2901}
  'FAILED'{$x.sampler_failed=$true}
  'DEADLINE'{$x.now_ms=[long]120000;$x.last_acquired_ms=[long]119900}
  'CACHE_RECEIPT_REWRITE'{$x.now_ms=[long]5000;$x.last_acquired_ms=[long]900}
  'QUEUE'{$x.queue_length=2}
  'SEQUENCE'{$x.sequence=1}
  'CLOCK'{$x.now_ms=[long]970}
 }
 $result=Test-HSupervisorReviewModel $x;Check ('SUPERVISOR-'+$scenario) $result ($result.state -ceq 'BLOCKED_SIMULATION' -and -not $result.real_sampler_called -and -not $result.real_process_killed)
}
$firstStale=$null
foreach($now in 0..101){$x=Copy-HObject $w;$x.now_ms=[long]($now*20);$x.previous_now_ms=[long]0;$x.last_acquired_ms=[long]0;$result=Test-HSupervisorReviewModel $x;if($result.state -ceq 'BLOCKED_SIMULATION'){$firstStale=$x.now_ms;break}}
Check 'HUNG-SAMPLER-SIM-FIRST-STALE-2020MS' @{first_stale_ms=$firstStale;step_ms=20;real_time_elapsed_ms=$null;sampler_invocations=0} ($firstStale -eq 2020)
Save-HNew 'review-design-results.json' @($rows)
$summary=@{tests=$rows.Count;pass=@($rows|Where-Object status -eq PASS).Count;fail=@($rows|Where-Object status -eq FAIL).Count;proposal_only=$true;real_startup=$false;real_kill=$false;g4_consent=$false}
Save-HNew 'review-design-summary.json' $summary;$summary|ConvertTo-Json
if($summary.fail){exit 1}
