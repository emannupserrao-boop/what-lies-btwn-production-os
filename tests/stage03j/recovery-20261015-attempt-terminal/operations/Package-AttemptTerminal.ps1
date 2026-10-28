#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$recovery=Join-Path $root 'tests\stage03j\recovery-20261015-attempt-terminal'
$workspace='C:\Users\user\Documents\Codex\2026-10-15\task-2'
function Save-New([string]$Path,[byte[]]$Bytes){$s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write($Bytes);$s.Flush($true)}finally{$s.Dispose()}}
function File-Hash([string]$Path){(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}
$change=Get-Content -LiteralPath (Join-Path $recovery 'FINAL_CHANGESET.json') -Raw|ConvertFrom-Json
$expected=@{};foreach($row in $change.changes){$expected[$row.path]=$row.after_sha256;if((File-Hash (Join-Path $root $row.path)) -cne $row.after_sha256){throw 'CANONICAL_CHANGED'}}
$tests=Get-Content -LiteralPath (Join-Path $workspace 'terminal-final-tests.json') -Raw|ConvertFrom-Json
$verified=Get-Content -LiteralPath (Join-Path $workspace 'terminal-final-verification.json') -Raw|ConvertFrom-Json
if($tests.pass -ne 28 -or $tests.fail -ne 0 -or $tests.source_sha256 -cne $expected['core\Wlb.WorkerProcess.ps1'] -or $verified.pass -ne 16 -or $verified.fail -ne 0){throw 'SELECTED_VERIFICATION_INVALID'}
$preimage=Import-Csv -LiteralPath (Join-Path $recovery 'prechange-inventory.csv')
$known=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($row in $preimage){$null=$known.Add($row.relative_path);$wanted=if($expected.ContainsKey($row.relative_path)){$expected[$row.relative_path]}else{$row.sha256};if((File-Hash (Join-Path $root $row.relative_path)) -cne $wanted){throw ('CONCURRENT_CHANGE:'+ $row.relative_path)}}
$outside=@(Get-ChildItem -LiteralPath $root -Force -Recurse -File|Where-Object {-not $_.FullName.StartsWith($recovery+'\',[StringComparison]::OrdinalIgnoreCase)}|ForEach-Object {$rel=[IO.Path]::GetRelativePath($root,$_.FullName);if(-not $known.Contains($rel)){$rel}})
if($outside.Count){throw 'NEW_FILES_OUTSIDE_RECOVERY'}
$copies=[ordered]@{'ATTEMPT_REVIEW_READY.md'='REVIEW_READY.md';'ATTEMPT_CHANGESET.diff'='CHANGESET.diff';'terminal-before-tests.json'='terminal-before-tests.json';'terminal-proposed-tests.json'='terminal-proposed-tests.json';'terminal-final-tests.json'='terminal-final-tests.json';'terminal-final-verification.json'='terminal-final-verification.json';'Verify-AttemptTerminal.ps1'='Verify-AttemptTerminal.ps1';'Backup-AttemptTerminal.ps1'='operations\Backup-AttemptTerminal.ps1';'Apply-AttemptTerminal.ps1'='operations\Apply-AttemptTerminal.ps1';'Package-AttemptTerminal.ps1'='operations\Package-AttemptTerminal.ps1'}
$null=[IO.Directory]::CreateDirectory((Join-Path $recovery 'operations'))
foreach($key in $copies.Keys){$source=Join-Path $workspace $key;$dest=Join-Path $recovery $copies[$key];Save-New $dest ([IO.File]::ReadAllBytes($source));if((File-Hash $source) -cne (File-Hash $dest)){throw 'COPY_MISMATCH'}}
$inventory=@(foreach($row in $change.changes){$p=Join-Path $root $row.path;[pscustomobject]@{relative_path=$row.path;kind='MODIFIED_CANONICAL';bytes=(Get-Item -LiteralPath $p).Length;sha256=(File-Hash $p)}};Get-ChildItem -LiteralPath $recovery -Recurse -File|Sort-Object FullName|ForEach-Object {[pscustomobject]@{relative_path=[IO.Path]::GetRelativePath($root,$_.FullName);kind='RECOVERY_NEW';bytes=$_.Length;sha256=(File-Hash $_.FullName)}})
$csv=($inventory|ConvertTo-Csv -NoTypeInformation)-join "`r`n"
Save-New (Join-Path $recovery 'RECOVERY_SHA256.csv') ([Text.UTF8Encoding]::new($false).GetBytes($csv+"`r`n"))
$meta=[ordered]@{schema='wlb-stage03j-attempt-terminal-delivery/0.1';utc=[DateTime]::UtcNow.ToString('o');status='READY_FOR_INDEPENDENT_REVIEW';existing_files_modified=3;existing_files_preserved=3499;before_reproduction_checks=@{pass=21;fail=7};behavioral_checks=@{pass=28;fail=0};verification_checks=@{pass=16;fail=0};historical_status='PARTIAL_WITH_BLOCKERS';historical_checks=@{pass=137;fail=1};prior_recovery_delivery_sha256='9c169452dc426bf3bda3f9273dfc35022725235ece7e604e6489ec72779843a5';normal_exit_attempt='NOT_RUN_AWAITING_INDEPENDENT_REVIEW';real_helpers_created=0;g4=$false;g5=$false;consent='ABSENT';inventory=@{path='RECOVERY_SHA256.csv';rows=$inventory.Count;sha256=(File-Hash (Join-Path $recovery 'RECOVERY_SHA256.csv'));exclusions=@('RECOVERY_SHA256.csv','RECOVERY_DELIVERY.json')};review_sha256=(File-Hash (Join-Path $recovery 'REVIEW_READY.md'));changeset_sha256=(File-Hash (Join-Path $recovery 'FINAL_CHANGESET.json'));selected_tests_sha256=(File-Hash (Join-Path $recovery 'terminal-final-tests.json'));selected_verification_sha256=(File-Hash (Join-Path $recovery 'terminal-final-verification.json'))}
Save-New (Join-Path $recovery 'RECOVERY_DELIVERY.json') ([Text.UTF8Encoding]::new($false).GetBytes(($meta|ConvertTo-Json -Depth 8)+"`r`n"))
$meta|ConvertTo-Json -Depth 8
