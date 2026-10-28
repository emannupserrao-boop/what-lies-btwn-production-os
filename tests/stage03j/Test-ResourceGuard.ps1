#requires -Version 7.6
param([ValidatePattern('^[a-z0-9-]+$')][string]$RunLabel='guard02')
. (Join-Path $PSScriptRoot 'J.Common.ps1')
. (Join-Path $JRoot 'core\Wlb.WorkerProcess.ps1')
$checks=[Collections.Generic.List[object]]::new()
function Guard-J([string]$Id,[scriptblock]$Body){try{$value=& $Body;if($value -isnot [bool] -or -not $value){throw 'Expected guard behavior absent'};$checks.Add(@{id=$Id;kind='RESOURCE_GUARD';status='PASS';detail='Guard behavior verified without creating a process'})}catch{$checks.Add(@{id=$Id;kind='RESOURCE_GUARD';status='FAIL';detail=$_.Exception.Message})}}
function New-GuardReading { @{status='AVAILABLE_GLOBAL';available_ram_bytes=[long]8GB;commit_total_bytes=[long]20GB;commit_limit_bytes=[long]30GB;commit_headroom_bytes=[long]10GB} }
Guard-J 'resource-exact8-and10-admits-only-benign-test' {$r=Test-WlbJHelperResourceReadiness (New-GuardReading);$r.allowed_to_create_owned_test_helper -and -not $r.production_start_authorized -and -not $r.hard_os_cap}
Guard-J 'resource-one-byte-below8-refused' {$h=New-GuardReading;$h.available_ram_bytes--; $r=Test-WlbJHelperResourceReadiness $h;-not $r.allowed_to_create_owned_test_helper -and $r.reasons -contains 'AVAILABLE_RAM_BELOW_8_GIB'}
Guard-J 'resource-one-byte-below10-refused' {$h=New-GuardReading;$h.commit_headroom_bytes--;$h.commit_limit_bytes--;$r=Test-WlbJHelperResourceReadiness $h;-not $r.allowed_to_create_owned_test_helper -and $r.reasons -contains 'COMMIT_HEADROOM_BELOW_10_GIB'}
Guard-J 'resource-unavailable-refused' {$h=New-GuardReading;$h.status='UNAVAILABLE';-not (Test-WlbJHelperResourceReadiness $h).allowed_to_create_owned_test_helper}
Guard-J 'resource-malformed-type-refused' {$h=New-GuardReading;$h.available_ram_bytes='8589934592';-not (Test-WlbJHelperResourceReadiness $h).allowed_to_create_owned_test_helper}
Guard-J 'resource-inconsistent-commit-refused' {$h=New-GuardReading;$h.commit_headroom_bytes++;-not (Test-WlbJHelperResourceReadiness $h).allowed_to_create_owned_test_helper}
Guard-J 'resource-negative-refused' {$h=New-GuardReading;$h.available_ram_bytes=[long]-1;-not (Test-WlbJHelperResourceReadiness $h).allowed_to_create_owned_test_helper}
$actual=Get-WlbPassiveHostMemory;$decision=Test-WlbJHelperResourceReadiness $actual
Save-JNew ($RunLabel+'-live-reading.json') @{utc=[DateTime]::UtcNow.ToString('o');reading=$actual;decision=$decision;process_created=$false;production_authority=$false}
Guard-J 'live-low-ram-create-refused-without-lease' {
 if($decision.allowed_to_create_owned_test_helper){return $false}
 # Bind to current attempt but override no providers or flags; actual path must refuse before CreateProcess.
 $a=New-WlbJAttempt
 $script:refusedAttempt=$a
 try{$null=Start-WlbJOwnedHelper $a FINITE_DELAY;return $false}catch{$denied=$_.Exception.Message -match 'STAGE03J_RESOURCE_BLOCKED'}
 $denied -and -not $a.created -and $null -eq $a.lease -and $a.terminal
}
foreach($check in $checks){$check.kind='SIMULATED_RESOURCE_GUARD'};$checks[$checks.Count-1].kind='REAL_CURRENT_HOST_CREATE_REFUSAL'
Guard-J 'resource-refusal-latched-no-restart' {try{$null=Start-WlbJOwnedHelper $script:refusedAttempt FINITE_DELAY;$false}catch{$_.Exception.Message -match 'Attempt restart/foreign scope denied' -and -not $script:refusedAttempt.created -and $null -eq $script:refusedAttempt.lease}}
$checks[$checks.Count-1].kind='REAL_CURRENT_HOST_CREATE_REFUSAL'
Save-JNew ($RunLabel+'-checks.json') @($checks)
@{pass=@($checks|Where-Object {$_.status -eq 'PASS'}).Count;fail=@($checks|Where-Object {$_.status -eq 'FAIL'}).Count;live=$decision}|ConvertTo-Json -Depth 8
if(@($checks|Where-Object {$_.status -eq 'FAIL'}).Count){exit 1}
