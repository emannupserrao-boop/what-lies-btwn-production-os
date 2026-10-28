#requires -Version 7.6
. (Join-Path $PSScriptRoot 'I.Common.ps1')
. (Join-Path $IRoot 'core\Wlb.TelemetryWorker.ps1')
$rows=[Collections.Generic.List[object]]::new()
function Row($id,$actual,$ok,$kind='EXECUTED_FINAL_STATIC_CONTRACT'){$rows.Add([pscustomobject]@{id=$id;status=$(if($ok){'PASS'}else{'FAIL'});actual=$actual;evidence_kind=$kind})}
function Reject($id,[scriptblock]$action,[string]$pattern){try{$null=& $action;Row $id 'UNEXPECTED_ACCEPT' $false}catch{Row $id $_.Exception.Message ($_.Exception.Message -match $pattern)}}
$policy=Read-WlbJson (Join-Path $IRoot 'policy\startup-policy.json');Assert-WlbStartupPolicy $policy
$executor=Read-WlbJson (Join-Path $IRoot 'policy\executor-policy.json')
Row 'FINAL-FOUR-UNKNOWN-BOUNDARY-AND-AUTHORITY-FLAGS' @{human=$policy.human_parameters;boundary=$policy.boundary_mode;consent=$policy.consent_status;startup=$policy.real_startup_enabled;jobs=$policy.gpu_jobs_enabled;execution=$executor.execution_enabled} (@($policy.human_parameters.Values|Where-Object {$_.status -cne 'UNKNOWN' -or $null -ne $_.value}).Count -eq 0 -and -not $policy.real_startup_enabled -and -not $policy.gpu_jobs_enabled -and -not $executor.execution_enabled -and $policy.consent_status -ceq 'ABSENT' -and $policy.boundary_mode -ceq 'SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0')
$identity=Read-WlbJson (Join-Path $IRoot 'policy\startup-identity.json');$snapshot=Test-WlbStagedSnapshotContent $identity
Row 'FINAL-SNAPSHOT619-INVENTORY-CONTENT-NO-ACTIVATION' $snapshot ($snapshot.files -eq 619 -and $snapshot.bytes -eq 9533695 -and $snapshot.content_verified -and -not $snapshot.authorized_to_execute -and $snapshot.snapshot_state -ceq 'STAGED_NOT_ACTIVATED') 'REAL_READ_ONLY_BYTES_IDS_INVENTORY_NOT_RUNTIME'
$lock=Read-WlbJson (Join-Path $IRoot 'policy\runtime-lock.json');$bindings=@(foreach($key in $lock.prepared_artifacts.Keys){@{path=$key;match=((Get-WlbHash (Join-Path $IRoot $key)) -ceq $lock.prepared_artifacts[$key])}})
Row 'FINAL-PINNED19-ARTIFACTS' $bindings ($bindings.Count -eq 19 -and @($bindings|Where-Object {-not $_.match}).Count -eq 0)
$static=& (Join-Path $IRoot 'core\Test-WlbManifest.ps1') -Mode StaticReview
Row 'FINAL-MANIFEST-DRAFT-LOCK-BINDING-NO-AUTHORITY' $static (-not $static.executable)
Reject 'FINAL-G4-ADMISSION-REFUSED' {& (Join-Path $IRoot 'core\Start-WlbRuntime.ps1') -Mode Admission} 'BLOCKED:'
Reject 'FINAL-G5-LAUNCHER-REFUSED' {& (Join-Path $IRoot 'core\Invoke-WlbJob.ps1') -ApprovalId ([guid]::Empty)} 'Existing human approval required'
. (Join-Path $IRoot 'tests\stage03h\Review-DesignModels.ps1')
$f=@{kind='SIMULATED_TEST_ONLY';scope='G4_STARTUP_NO_MODELS';model_or_job_requested=$false;now_ms=[long]1000;baseline_acquired_ms=[long]0;sample_acquired_ms=[long]900;available_ram_bytes=[long](8GB);commit_headroom_bytes=[long](10GB);baseline_commit_bytes=[long](16GB);sample_commit_bytes=[long](20GB);private_bytes=[long](4GB);baseline_vram_bytes=[long](1GB);sample_vram_bytes=[long](3GB);aggregate_bytes=[long](256MB);valid_global_baseline=$true;data_consistent=$true;provider_proxy_explicitly_assumed_for_simulation=$true;actor_inventory_known=$true;activity_classified=$true;heavy_gpu_work=$false;actors_changed=$false;process_identity_matches=$true;port_identity_known=$true}
$h1=Test-HProxyReviewModel $f;$f.sample_vram_bytes++;$h2=Test-HProxyReviewModel $f;$f.sample_vram_bytes--;$f.activity_classified=$false;$h3=Test-HProxyReviewModel $f
Row 'H-RESOURCE-PROPOSAL-COMPATIBILITY-EXACT-OVER-UNKNOWN' @($h1,$h2,$h3) ($h1.state -ceq 'SIMULATED_THRESHOLDS_ONLY' -and $h2.state -ceq 'BLOCKED_SIMULATION' -and $h3.state -ceq 'BLOCKED_SIMULATION' -and -not $h1.authorized_to_execute) 'FRESH_LEGACY_H_MODEL_FIXTURES_NOT_LIVE_WATCHDOG'
$astChecks=@(foreach($rel in @('core\Wlb.Supervisor.ps1','core\Wlb.TelemetryWorker.ps1','core\Start-WlbRuntime.ps1','core\Invoke-WlbJob.ps1')){
 $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $IRoot $rel),[ref]$tokens,[ref]$errors)
 $commands=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -in @('Start-Process','Stop-Process','Invoke-RestMethod','Invoke-WebRequest','Invoke-Expression','python','pip','git')},$true))
 $methods=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Member.Extent.Text -in @('Start','Kill','Connect','Bind','Listen')},$true))
 @{relative_path=$rel;parse_errors=@($errors).Count;lifecycle_commands=$commands.Count;lifecycle_methods=$methods.Count}
})
Row 'FINAL-NO-LIFECYCLE-REST-OR-SOCKET-PATH' $astChecks (@($astChecks|Where-Object {$_.parse_errors -ne 0 -or $_.lifecycle_commands -ne 0 -or $_.lifecycle_methods -ne 0}).Count -eq 0) 'STATIC_AST_NOT_OS_SANDBOX'
$entry=Get-Content -LiteralPath (Join-Path $IRoot 'core\Start-WlbRuntime.ps1') -Raw
Row 'FINAL-NEW-SUPERVISOR-NOT-WIRED-TO-STARTUP' @{entry_mentions_supervisor_or_worker=($entry -match 'Wlb.Supervisor|Wlb.TelemetryWorker')} ($entry -notmatch 'Wlb.Supervisor|Wlb.TelemetryWorker')
Save-INew 'final-gates-results.json' @($rows)
$summary=@{tests=$rows.Count;pass=@($rows|Where-Object status -eq PASS).Count;fail=@($rows|Where-Object status -eq FAIL).Count;snapshot_runtime='NOT_VERIFIED';g4='BLOCKED_NOT_AUTHORIZED';g5='NOT_AUTHORIZED';alpha='CLOSED'}
Save-INew 'final-gates-summary.json' $summary;$summary|ConvertTo-Json
if($summary.fail){exit 1}
