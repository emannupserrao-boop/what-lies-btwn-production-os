#requires -Version 7.6
# Static/pure negative tests. No Python, server, network, GPU or real approvals.
[CmdletBinding()]
param([ValidateSet('initial','run2','run3')][string]$Run='initial')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$Stage=Join-Path $Root 'tests\stage03f'
$EvidenceRoot=if($Run -ceq 'initial'){Join-Path $Stage 'evidence'}else{Join-Path (Join-Path $Stage 'evidence') $Run}
if($Run -cne 'initial'){if(Test-Path -LiteralPath $EvidenceRoot){throw 'Fresh evidence namespace required'};$null=New-Item -ItemType Directory -Path $EvidenceRoot}
$Results=[Collections.Generic.List[object]]::new()
function Clone($v){return ,(ConvertTo-Json -InputObject $v -Depth 70 | ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
function Row([string]$id,$actual,[bool]$pass,[string]$kind='PURE_NEGATIVE_CONTRACT'){$Results.Add([pscustomobject]@{id=$id;status=$(if($pass){'PASS'}else{'FAIL'});actual=$actual;evidence_kind=$kind})}
function Reject([string]$id,[scriptblock]$action,[string]$pattern='BLOCKED:'){try{$out=@(& $action);Row $id 'UNEXPECTED_ACCEPT' $false}catch{Row $id $_.Exception.Message ($_.Exception.Message -match $pattern)}}
function SaveNew([string]$path,$value){if(-not $path.StartsWith($Stage+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Outside Stage03F evidence'};$s=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write([Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject $value -Depth 60)));$s.Flush($true)}finally{$s.Dispose()}}
. (Join-Path $Root 'core\Wlb.RuntimeMonitor.ps1')
$identity=Read-WlbJson (Join-Path $Root 'policy\startup-identity.json')
$policy=Read-WlbJson (Join-Path $Root 'policy\startup-policy.json')
$lock=Read-WlbJson (Join-Path $Root 'policy\runtime-lock.json')
$manifest=Read-WlbJson (Join-Path $Root 'manifests\draft\POC0-CALIBRATION-001.json')
$baseline=& (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode StaticReview
Row 'STATIC-DRAFT-BASELINE' $baseline (-not $baseline.executable) 'EXECUTED_STATIC_VALIDATOR'
Assert-WlbStartupIdentity $identity
$real=Test-WlbStagedSnapshotContent $identity
Row '619-FILES-REAL-READONLY-INTEGRITY' $real ($real.content_verified -and $real.files -eq 619 -and -not $real.authorized_to_execute) 'REAL_READONLY_CONTENT_HASH_IDENTITY'
$entry=& (Join-Path $Root 'core\Start-WlbRuntime.ps1') -Mode Plan
Row 'STAGED-PLAN-NO-START' $entry ($entry.snapshot_state -ceq 'STAGED_NOT_ACTIVATED' -and $entry.state -ceq 'BLOCKED' -and -not $entry.startup_performed -and -not $entry.admission.authorized_to_execute) 'EXECUTED_STATIC_PLAN'
SaveNew (Join-Path $EvidenceRoot 'plan.json') $entry
Reject 'G4-ADMISSION-STILL-REFUSED' {& (Join-Path $Root 'core\Start-WlbRuntime.ps1') -Mode Admission}
Reject 'G5-EXECUTION-ELIGIBILITY-REFUSED' {& (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode ExecutionEligibility}
Reject 'G5-JOB-LAUNCHER-EMPTY-GUID-REFUSED' {& (Join-Path $Root 'core\Invoke-WlbJob.ps1') -ApprovalId ([guid]::Empty)} 'Existing human approval required'
Reject 'G5-JOB-LAUNCHER-OMITTED-GUID-PREEXISTING-REFUSAL' {& (Join-Path $Root 'core\Invoke-WlbJob.ps1')} 'null-valued expression'
$old=Read-WlbJson (Join-Path $Stage 'baseline\policy\startup-identity.json')
Reject 'SNAPSHOT-ABSENT-DECLARATION' {Test-WlbStagedSnapshotContent $old} 'Snapshot absent or not staged'
foreach($name in @('UNKNOWN_STATE','EXISTS_FALSE','CONTENT_UNVERIFIED','STARTED_TRUE','AUTHORITY_TRUE','COMPATIBLE_WITHOUT_EVIDENCE','BAD_INVENTORY_HASH','BAD_INVENTORY_PATH','PYTHON_COMPATIBLE_WITHOUT_EVIDENCE','DEPENDENCY_COMPATIBLE_WITHOUT_EVIDENCE','EXTRA_FIELD')){
 $bad=Clone $identity
 switch($name){
  'UNKNOWN_STATE'{$bad.snapshot.status='AUTHORIZED_TO_EXECUTE'}
  'EXISTS_FALSE'{$bad.snapshot.exists=$false}
  'CONTENT_UNVERIFIED'{$bad.snapshot.content_verified=$false}
  'STARTED_TRUE'{$bad.snapshot.runtime_started=$true}
  'AUTHORITY_TRUE'{$bad.snapshot.execution_authority=$true}
  'COMPATIBLE_WITHOUT_EVIDENCE'{$bad.snapshot.runtime_compatibility='COMPATIBLE'}
  'BAD_INVENTORY_HASH'{$bad.snapshot.actual_inventory_sha256='0'*64}
  'BAD_INVENTORY_PATH'{$bad.snapshot.actual_inventory=Join-Path $Stage 'UNAPPROVED.csv'}
  'PYTHON_COMPATIBLE_WITHOUT_EVIDENCE'{$bad.python.runtime_validation='VERIFIED'}
  'DEPENDENCY_COMPATIBLE_WITHOUT_EVIDENCE'{$bad.dependencies.runtime_compatibility='VERIFIED'}
  'EXTRA_FIELD'{$bad.snapshot.command='NOT_EXECUTED'}
 }
 Reject ('IDENTITY-'+$name) {Assert-WlbStartupIdentity $bad}
}
$proposal=@(Import-Csv -LiteralPath $identity.snapshot.proposal_inventory)
$actual=@(Import-Csv -LiteralPath $identity.snapshot.actual_inventory)
$before=@(Import-Csv -LiteralPath (Join-Path $Stage 'evidence\snapshot-checks-before.csv') | Where-Object {$_.side -ceq 'SNAPSHOT'})
$observations=@($before | ForEach-Object {[ordered]@{relative_path=$_.relative_path;path=$_.path;final_path=$_.path;bytes=[long]$_.bytes;sha256=$_.sha256;file_identity=$_.file_identity;hardlink_count=[int]$_.hardlink_count}})
$comparison=Assert-WlbSnapshotInventoryContract $proposal $actual $observations $identity.snapshot.proposal_sha256 $identity.snapshot.actual_inventory_sha256
Row 'PURE-VERIFIED-OBSERVATIONS-BASELINE' $comparison (-not $comparison.authorized_to_execute) 'PURE_COMPARISON_OF_READONLY_EVIDENCE'
foreach($name in @('INCOMPLETE','EXTRA_FILE','FILE_HASH','FILE_SIZE','FILE_IDENTITY','HARDLINK','FINAL_PATH','ACTUAL_HASH','ACTUAL_STATE','ALLOWLIST_SOURCE','ALLOWLIST_DESTINATION','DUPLICATE','INVENTORY_HASH','ALLOWLIST_HASH')){
 $p=Clone $proposal;$a=Clone $actual;$o=Clone $observations;$ih=$identity.snapshot.actual_inventory_sha256;$ph=$identity.snapshot.proposal_sha256
 switch($name){
  'INCOMPLETE'{$a=@($a | Select-Object -Skip 1)}
  'EXTRA_FILE'{$extra=Clone $o[0];$extra.relative_path='EXTRA_NOT_APPROVED.py';$o=@($o)+@($extra)}
  'FILE_HASH'{$o[0].sha256='0'*64}
  'FILE_SIZE'{$o[0].bytes++}
  'FILE_IDENTITY'{$o[0].file_identity='REPLACED_FILE'}
  'HARDLINK'{$o[0].hardlink_count=2}
  'FINAL_PATH'{$o[0].final_path=Join-Path $Stage 'OUTSIDE_SNAPSHOT'}
  'ACTUAL_HASH'{$a[0].sha256='0'*64}
  'ACTUAL_STATE'{$a[0].status='ACTIVATED'}
  'ALLOWLIST_SOURCE'{$p[0].source='D:\NOT_APPROVED\file.py'}
  'ALLOWLIST_DESTINATION'{$p[0].planned_destination=Join-Path $Stage 'NOT_APPROVED.py'}
  'DUPLICATE'{$a[1]=Clone $a[0]}
  'INVENTORY_HASH'{$ih='0'*64}
  'ALLOWLIST_HASH'{$ph='0'*64}
 }
 Reject ('INTEGRITY-'+$name) {Assert-WlbSnapshotInventoryContract $p $a $o $ph $ih}
}
$plan=$entry.plan
$fake=@{policy_sha256=$plan.policy_sha256;runtime_lock_sha256=$plan.runtime_lock_sha256;snapshot_exists=$true;snapshot_bytes_verified=$true;python_sha256=$plan.python_sha256;dependency_identity_verified=$true;port_identity_known=$true;port_occupied=$false;monitor_provider_ready=$true;prior_reservation=$false}
$decision=Test-WlbStartupAdmission $policy $plan $fake $null
Row 'STAGED-AND-FABRICATED-READINESS-CANNOT-AUTHORIZE' $decision ($decision.state -ceq 'BLOCKED' -and -not $decision.authorized_to_execute -and $decision.reasons -contains 'CONSENT_MISSING') 'PURE_NO_CONSENT_DECISION'
foreach($field in @('real_startup_enabled','gpu_jobs_enabled','auto_retry')){$bad=Clone $policy;$bad[$field]=$true;Reject ('POLICY-CANNOT-ENABLE-'+$field) {Assert-WlbStartupPolicy $bad}}
foreach($key in $policy.human_parameters.Keys){Row ('HUMAN-PARAMETER-STILL-UNKNOWN-'+$key) $policy.human_parameters[$key] ($policy.human_parameters[$key].status -ceq 'UNKNOWN' -and $null -eq $policy.human_parameters[$key].value) 'READONLY_POLICY'}
Row 'SUPERVISED-MODE-PRESERVED' $policy.boundary_mode ($policy.boundary_mode -ceq 'SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0') 'READONLY_POLICY'
Row 'RUNTIME-LOCK-STAGED-NOT-RUN' $lock.origin ($lock.origin.snapshot_created -and $lock.origin.snapshot_status -ceq 'STAGED_NOT_ACTIVATED' -and $lock.execution_validation -ceq 'NOT_VERIFIED' -and -not $lock.approval_created) 'READONLY_LOCK'
Assert-WlbStagedRuntimeLock $lock $identity
foreach($kind in @('COMPATIBLE','STARTED','APPROVAL','INVENTORY','STATUS','SECURITY')){
 $bad=Clone $lock
 switch($kind){'COMPATIBLE'{$bad.python_candidate.compatibility='VERIFIED'};'STARTED'{$bad.python_candidate.execution='RUN'};'APPROVAL'{$bad.approval_created=$true};'INVENTORY'{$bad.origin.snapshot_sha256='0'*64};'STATUS'{$bad.origin.snapshot_status='AUTHORIZED_TO_EXECUTE'};'SECURITY'{$bad.security_boundary_validation='VERIFIED'}}
 Reject ('RUNTIME-LOCK-REJECT-'+$kind) {Assert-WlbStagedRuntimeLock $bad $identity}
}
# Source-level authority regression: no launch/network/consent adapter is introduced.
foreach($relative in @('core\Wlb.Startup.ps1','core\Start-WlbRuntime.ps1','core\Invoke-WlbJob.ps1')){
 $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root $relative),[ref]$tokens,[ref]$errors)
 $dangerous=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -in @('Start-Process','Stop-Process','Invoke-RestMethod','Invoke-WebRequest','Invoke-Expression','python','python.exe','pip','curl','git')},$true))
 Row ('NO-REAL-EXECUTION-COMMANDS-'+$relative) @($dangerous | ForEach-Object {$_.Extent.Text}) ($errors.Count -eq 0 -and $dangerous.Count -eq 0) 'STATIC_AST_COMMAND_CHECK_NOT_SANDBOX_PROOF'
 if($relative -ceq 'core\Invoke-WlbJob.ps1'){Row 'JOB-LAUNCHER-INCONDITIONAL-FINAL-THROW' $ast.EndBlock.Statements[-1].Extent.Text ($ast.EndBlock.Statements[-1] -is [Management.Automation.Language.ThrowStatementAst]) 'STATIC_AST'}
}
SaveNew (Join-Path $EvidenceRoot 'stage03f-results.json') @($Results)
$summary=[ordered]@{tests=$Results.Count;pass=@($Results | Where-Object {$_.status -ceq 'PASS'}).Count;fail=@($Results | Where-Object {$_.status -ceq 'FAIL'}).Count;runtime_started=$false;python_executed=$false;gpu_jobs=$false;real_approvals=$false;mock_is_runtime_evidence=$false}
SaveNew (Join-Path $EvidenceRoot 'stage03f-summary.json') $summary
$summary | ConvertTo-Json
if($summary.fail){exit 1}
