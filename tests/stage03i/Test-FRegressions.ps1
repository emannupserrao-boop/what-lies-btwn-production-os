#requires -Version 7.6
# Targeted final-source Stage03F regressions; no mutation of canonical data or snapshot.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS';$Evidence=Join-Path $Root 'tests\stage03i\evidence'
. (Join-Path $Root 'core\Wlb.Startup.ps1')
function Clone($v){return ,(ConvertTo-Json -InputObject $v -Depth 60 | ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
$rows=[Collections.Generic.List[object]]::new()
function Record([string]$id,[bool]$ok,$actual){$rows.Add([ordered]@{id=$id;status=$(if($ok){'PASS'}else{'FAIL'});actual=$actual;evidence_kind='EXECUTED_STAGE03F_STATIC_REGRESSION'})}
function Reject([string]$id,[scriptblock]$action){try{$null=& $action;Record $id $false 'UNEXPECTED_ACCEPT'}catch{Record $id ($_.Exception.Message -match 'BLOCKED:') $_.Exception.Message}}
$identity=Read-WlbJson (Join-Path $Root 'policy\startup-identity.json');$runtime=Read-WlbJson (Join-Path $Root 'policy\runtime-lock.json')
Assert-WlbStartupIdentity $identity;Assert-WlbStagedRuntimeLock $runtime $identity
Record 'F-STAGED-BASELINE-NOT-ACTIVATED' ($identity.snapshot.status -ceq 'STAGED_NOT_ACTIVATED' -and -not $identity.snapshot.runtime_started -and -not $identity.snapshot.execution_authority) $identity.snapshot
foreach($kind in @('STATE','UNVERIFIED','STARTED','COMPATIBLE','AUTHORITY','INVENTORY')){
 $bad=Clone $identity
 switch($kind){'STATE'{$bad.snapshot.status='AUTHORIZED_TO_EXECUTE'};'UNVERIFIED'{$bad.snapshot.content_verified=$false};'STARTED'{$bad.snapshot.runtime_started=$true};'COMPATIBLE'{$bad.snapshot.runtime_compatibility='VERIFIED'};'AUTHORITY'{$bad.snapshot.execution_authority=$true};'INVENTORY'{$bad.snapshot.actual_inventory_sha256='0'*64}}
 Reject ('F-IDENTITY-'+$kind) {Assert-WlbStartupIdentity $bad}
}
foreach($kind in @('PYTHON','APPROVAL','STATE','INVENTORY','SECURITY')){
 $bad=Clone $runtime
 switch($kind){'PYTHON'{$bad.python_candidate.compatibility='VERIFIED'};'APPROVAL'{$bad.approval_created=$true};'STATE'{$bad.origin.snapshot_status='AUTHORIZED_TO_EXECUTE'};'INVENTORY'{$bad.origin.snapshot_sha256='0'*64};'SECURITY'{$bad.security_boundary_validation='VERIFIED'}}
 Reject ('F-RUNTIME-'+$kind) {Assert-WlbStagedRuntimeLock $bad $identity}
}
$policy=Read-WlbJson (Join-Path $Root 'policy\startup-policy.json')
Record 'F-FOUR-HUMAN-PARAMETERS-UNKNOWN' (@($policy.human_parameters.Values | Where-Object {$_.status -cne 'UNKNOWN' -or $null -ne $_.value}).Count -eq 0) $policy.human_parameters
$manifest=Read-WlbJson (Join-Path $Root 'manifests\draft\POC0-CALIBRATION-001.json')
Record 'F-DRAFT-AND-NO-CONSENT' ($manifest.state -ceq 'DRAFT' -and $policy.consent_status -ceq 'ABSENT' -and -not $policy.real_startup_enabled -and -not $policy.gpu_jobs_enabled) $manifest.state
$p=Join-Path $Evidence 'f-regression-results.json';$s=[IO.File]::Open($p,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write([Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject @($rows) -Depth 30)));$s.Flush($true)}finally{$s.Dispose()}
$rows | Group-Object status | Select-Object Name,Count | ConvertTo-Json
if(@($rows | Where-Object {$_.status -ceq 'FAIL'}).Count){exit 1}
