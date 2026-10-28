#requires -Version 7.4
param([Parameter(Mandatory)][string]$ResultPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$recovery=Join-Path $root 'tests\stage03j\recovery-20261015-guard-central'
$checks=[Collections.Generic.List[object]]::new()
function Check([string]$Id,[bool]$Valid){$checks.Add([ordered]@{id=$Id;status=$(if($Valid){'PASS'}else{'FAIL'})})}
function File-Hash([string]$Path){(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}
$change=Get-Content -LiteralPath (Join-Path $recovery 'FINAL_CHANGESET.json') -Raw|ConvertFrom-Json
$expected=@{};foreach($row in $change.changes){$expected[$row.path]=$row.after_sha256}
$preimage=Import-Csv -LiteralPath (Join-Path $recovery 'prechange-inventory.csv')
$changed=@();$missing=@();foreach($row in $preimage){$p=Join-Path $root $row.relative_path;if(-not(Test-Path -LiteralPath $p -PathType Leaf)){$missing+=$row.relative_path;continue};$hash=File-Hash $p;if($hash -cne $row.sha256){$changed+=[ordered]@{path=$row.relative_path;sha256=$hash;expected=($expected.ContainsKey($row.relative_path) -and $expected[$row.relative_path] -ceq $hash)}}}
Check 'prechange3476-exact-three-approved-modifications' ($preimage.Count -eq 3476 -and $missing.Count -eq 0 -and $changed.Count -eq 3 -and @($changed|Where-Object {-not $_.expected}).Count -eq 0)
$known=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);foreach($row in $preimage){$null=$known.Add($row.relative_path)}
$foreignNew=@(Get-ChildItem -LiteralPath $root -Force -Recurse -File|Where-Object {-not $_.FullName.StartsWith($recovery+'\',[StringComparison]::OrdinalIgnoreCase)}|ForEach-Object {$rel=[IO.Path]::GetRelativePath($root,$_.FullName);if(-not $known.Contains($rel)){$rel}})
Check 'no-new-files-outside-recovery' ($foreignNew.Count -eq 0)
$backupReceipt=Get-Content -LiteralPath (Join-Path $recovery 'BACKUP_VERIFIED.json') -Raw|ConvertFrom-Json
$backupValid=$true;foreach($row in $backupReceipt.files){if((File-Hash (Join-Path $root $row.backup_relative_path)) -cne $row.sha256){$backupValid=$false}}
Check 'three-original-backups-still-match' $backupValid
$oldLockText=[IO.File]::ReadAllText((Join-Path $recovery 'backup\policy__runtime-lock.json'))
$oldModule=($change.changes|Where-Object path -eq 'core\Wlb.WorkerProcess.ps1').before_sha256
$newModule=$expected['core\Wlb.WorkerProcess.ps1']
Check 'lock-only-one-module-pin-replaced' ($oldLockText.Replace($oldModule,$newModule) -ceq [IO.File]::ReadAllText((Join-Path $root 'policy\runtime-lock.json')))
$oldDraft=[IO.File]::ReadAllText((Join-Path $recovery 'backup\manifests__draft__POC0-CALIBRATION-001.json'))
$oldLock=($change.changes|Where-Object path -eq 'policy\runtime-lock.json').before_sha256
Check 'draft-only64char-lock-binding-replaced' ($oldDraft.Replace($oldLock,$expected['policy\runtime-lock.json']) -ceq [IO.File]::ReadAllText((Join-Path $root 'manifests\draft\POC0-CALIBRATION-001.json')))
$lock=Get-Content -LiteralPath (Join-Path $root 'policy\runtime-lock.json') -Raw|ConvertFrom-Json -AsHashtable
$pinIssues=@(foreach($entry in $lock.prepared_artifacts.GetEnumerator()){if((File-Hash (Join-Path $root $entry.Key)) -cne $entry.Value){$entry.Key}})
Check 'all21-prepared-pins-match' ($lock.prepared_artifacts.Count -eq 21 -and $pinIssues.Count -eq 0)
$historical=Import-Csv -LiteralPath (Join-Path $root 'STAGE03J_SHA256_INVENTORY.csv')
$historicalUnexpected=@();$historicalExpected=@();foreach($row in $historical){$actual=File-Hash (Join-Path $root $row.relative_path);if($actual -cne $row.sha256){if($expected.ContainsKey($row.relative_path) -and $actual -ceq $expected[$row.relative_path]){$historicalExpected+=$row.relative_path}else{$historicalUnexpected+=$row.relative_path}}}
Check 'historical90-only-three-intentional-live-file-differences' ($historical.Count -eq 90 -and $historicalExpected.Count -eq 3 -and $historicalUnexpected.Count -eq 0)
$meta=Get-Content -LiteralPath (Join-Path $root 'STAGE03J_DELIVERY_INTEGRITY.json') -Raw|ConvertFrom-Json
Check 'historical-documents-and-inventory-unchanged' ((File-Hash (Join-Path $root $meta.inventory.path)) -ceq $meta.inventory.sha256 -and (File-Hash (Join-Path $root 'STAGE03J_PROCESS_BOUNDARY_DECISION_PACKAGE.md')) -ceq $meta.report_sha256 -and (File-Hash (Join-Path $root 'STAGE03J_TEST_MATRIX.md')) -ceq $meta.matrix_sha256)
$policy=Get-Content -LiteralPath (Join-Path $root 'policy\startup-policy.json') -Raw|ConvertFrom-Json -AsHashtable
$executor=Get-Content -LiteralPath (Join-Path $root 'policy\executor-policy.json') -Raw|ConvertFrom-Json -AsHashtable
$human=@($policy.human_parameters.Values|Where-Object {$_.status -cne 'UNKNOWN' -or $null -ne $_.value})
Check 'canonical-gates-budgets-human-fields-preserved' (-not $policy.real_startup_enabled -and -not $policy.gpu_jobs_enabled -and -not $policy.auto_retry -and -not $executor.execution_enabled -and $policy.consent_status -ceq 'ABSENT' -and $human.Count -eq 0 -and -not(Test-Path -LiteralPath (Join-Path $root 'approvals')))
$static=& (Join-Path $root 'core\Test-WlbManifest.ps1') -Mode StaticReview
Check 'canonical-static-review-not-executable' (-not $static.executable -and $static.approval -ceq 'ABSENT' -and $static.submission -ceq 'NOT_PERFORMED')
$refusals=@()
foreach($probe in @(@{name='execution-eligibility';path='core\Test-WlbManifest.ps1';args=@{Mode='ExecutionEligibility'};expected='G1 preparation only'},@{name='g4-admission';path='core\Start-WlbRuntime.ps1';args=@{Mode='Admission'};expected='REAL_ADAPTERS_AND_G4_AUTHORITY_DISABLED'},@{name='g5-no-approval';path='core\Invoke-WlbJob.ps1';args=@{ApprovalId=[guid]::Empty};expected='Existing human approval required'})){
 $refused=$false;$message=$null;try{$probeArgs=$probe.args;$null=& (Join-Path $root $probe.path) @probeArgs}catch{$message=$_.Exception.Message;$refused=$message.Contains($probe.expected)}
 Check $probe.name $refused
 $refusals+=[ordered]@{probe=$probe.name;reason=$message}
}
# Exercise only the new read-only PSAPI reader. Never invoke production Start/Stop.
$errs=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'core\Wlb.WorkerProcess.ps1'),[ref]$null,[ref]$errs)
$cs=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value.StartsWith('using System;')},$true))[0].Value
Add-Type -TypeDefinition $cs
$native='WlbOwnedJ.Native' -as [type]
$read=$native.GetMethod('ReadHostResources',[Reflection.BindingFlags]'Static,NonPublic')
$memory=$null;$memoryError=$null
try{$v=$read.Invoke($null,@());$memory=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');source='NEW_NATIVE_PSAPI_READER_ONLY';available_ram_bytes=$v[0];physical_total_bytes=$v[1];commit_total_bytes=$v[2];commit_limit_bytes=$v[3];commit_headroom_bytes=($v[3]-$v[2]);page_size=$v[4];thresholds_met=($v[0] -ge 8GB -and $v[3]-$v[2] -ge 10GB);start_authority=$false};Check 'new-native-memory-reader-valid-passive-measurement' ($v.Count -eq 5 -and $v[0] -ge 0 -and $v[0] -le $v[1] -and $v[2] -ge 0 -and $v[2] -le $v[3] -and $v[4] -gt 0)}catch{$memoryError=$_.Exception.Message;Check 'new-native-memory-reader-valid-passive-measurement' $false}
$result=[ordered]@{schema='wlb-stage03j-central-guard-final-verification/0.1';utc=[DateTime]::UtcNow.ToString('o');pass=@($checks|Where-Object status -eq PASS).Count;fail=@($checks|Where-Object status -eq FAIL).Count;checks=@($checks);changed_preexisting=$changed;missing=$missing;foreign_new=$foreignNew;prechange_unchanged=($preimage.Count-$changed.Count);historical_inventory_live_differences=$historicalExpected;historical_unexpected_differences=$historicalUnexpected;static_review=$static;refusals=$refusals;passive_native_memory=$memory;memory_error=$memoryError;production_start_or_stop_invoked=$false;real_helpers_created=0;normal_exit_attempt='NOT_RUN_AWAITING_INDEPENDENT_REVIEW';historical_status=$meta.status;historical_counts=$meta.checks}
$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($result|ConvertTo-Json -Depth 10)+"`r`n")
$s=[IO.File]::Open($ResultPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write($bytes);$s.Flush($true)}finally{$s.Dispose()}
$result|ConvertTo-Json -Depth 10
if($result.fail){exit 1}
