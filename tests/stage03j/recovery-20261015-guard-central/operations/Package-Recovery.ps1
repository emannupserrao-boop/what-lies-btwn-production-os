#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$recovery=Join-Path $root 'tests\stage03j\recovery-20261015-guard-central'
$workspace='C:\Users\user\Documents\Codex\2026-10-15\task-2'
function Save-New([string]$Path,[byte[]]$Bytes){$s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write($Bytes);$s.Flush($true)}finally{$s.Dispose()}}
function File-Hash([string]$Path){(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}
$change=Get-Content -LiteralPath (Join-Path $recovery 'FINAL_CHANGESET.json') -Raw|ConvertFrom-Json
$expected=@{};foreach($row in $change.changes){$expected[$row.path]=$row.after_sha256;if((File-Hash (Join-Path $root $row.path)) -cne $row.after_sha256){throw 'CANONICAL_CHANGED_BEFORE_PACKAGING'}}
$tests=Get-Content -LiteralPath (Join-Path $workspace 'canonical-tests-02.json') -Raw|ConvertFrom-Json
$verified=Get-Content -LiteralPath (Join-Path $workspace 'final-verification-01.json') -Raw|ConvertFrom-Json
if($tests.fail -ne 0 -or $tests.pass -ne 21 -or $tests.source_sha256 -cne $expected['core\Wlb.WorkerProcess.ps1'] -or $verified.fail -ne 0 -or $verified.pass -ne 14){throw 'SELECTED_VERIFICATION_INVALID'}
$preimage=Import-Csv -LiteralPath (Join-Path $recovery 'prechange-inventory.csv')
foreach($row in $preimage){$wanted=if($expected.ContainsKey($row.relative_path)){$expected[$row.relative_path]}else{$row.sha256};if((File-Hash (Join-Path $root $row.relative_path)) -cne $wanted){throw ('CONCURRENT_CHANGE_BEFORE_PACKAGING:'+ $row.relative_path)}}
$copies=[ordered]@{
 'REVIEW_READY.md'='REVIEW_READY.md'
 'CHANGESET.final.diff'='CHANGESET.diff'
 'proposed-tests-01.json'='proposed-tests-01.json'
 'canonical-tests-01.json'='canonical-tests-01.json'
 'canonical-tests-02.json'='canonical-tests-02.json'
 'final-verification-01.json'='final-verification-01.json'
 'Verify-Recovery.ps1'='Verify-Recovery.ps1'
 'Backup-Stage03JRecovery.ps1'='operations\Backup-Stage03JRecovery.ps1'
 'Apply-CentralGuardRecovery.ps1'='operations\Apply-CentralGuardRecovery.ps1'
 'Preserve-OriginalLineEndings.ps1'='operations\Preserve-OriginalLineEndings.ps1'
 'Package-Recovery.ps1'='operations\Package-Recovery.ps1'
}
$null=[IO.Directory]::CreateDirectory((Join-Path $recovery 'operations'))
foreach($key in $copies.Keys){$source=Join-Path $workspace $key;$dest=Join-Path $recovery $copies[$key];Save-New $dest ([IO.File]::ReadAllBytes($source));if((File-Hash $source) -cne (File-Hash $dest)){throw 'DELIVERY_COPY_MISMATCH'}}
$operations=[ordered]@{schema='wlb-stage03j-recovery-operation-notes/0.1';utc=[DateTime]::UtcNow.ToString('o');preflight_rejections=@('Initial shell foreach/pipeline parse error: read-only command did not run.','Backup path traversal initially used unsupported Split-Path parameter combination: aborted before any project write.','Apply script expected receipt hash had a transcription error: aborted before any project write.');intermediate_version='CRLF version preserved in backup-intermediate; final source restores original LF with unchanged code semantics.';no_failed_behavioral_checks=$true;real_helpers_created=0;normal_exit_attempt='NOT_RUN_AWAITING_INDEPENDENT_REVIEW'}
Save-New (Join-Path $recovery 'operation-notes.json') ([Text.UTF8Encoding]::new($false).GetBytes(($operations|ConvertTo-Json -Depth 6)+"`r`n"))
$inventory=@(foreach($row in $change.changes){$p=Join-Path $root $row.path;[pscustomobject]@{relative_path=$row.path;kind='MODIFIED_CANONICAL';bytes=(Get-Item -LiteralPath $p).Length;sha256=(File-Hash $p)}};Get-ChildItem -LiteralPath $recovery -Recurse -File|Sort-Object FullName|ForEach-Object {[pscustomobject]@{relative_path=[IO.Path]::GetRelativePath($root,$_.FullName);kind='RECOVERY_NEW';bytes=$_.Length;sha256=(File-Hash $_.FullName)}})
$csv=($inventory|ConvertTo-Csv -NoTypeInformation)-join "`r`n"
Save-New (Join-Path $recovery 'RECOVERY_SHA256.csv') ([Text.UTF8Encoding]::new($false).GetBytes($csv+"`r`n"))
$meta=[ordered]@{schema='wlb-stage03j-recovery-delivery/0.1';utc=[DateTime]::UtcNow.ToString('o');status='READY_FOR_INDEPENDENT_REVIEW';existing_files_modified=3;existing_files_preserved=3473;behavioral_checks=@{pass=21;fail=0};verification_checks=@{pass=14;fail=0};historical_status='PARTIAL_WITH_BLOCKERS';historical_checks=@{pass=137;fail=1};normal_exit_attempt='NOT_RUN_AWAITING_INDEPENDENT_REVIEW';real_helpers_created=0;g4=$false;g5=$false;consent='ABSENT';inventory=@{path='RECOVERY_SHA256.csv';rows=$inventory.Count;sha256=(File-Hash (Join-Path $recovery 'RECOVERY_SHA256.csv'));exclusions=@('RECOVERY_SHA256.csv','RECOVERY_DELIVERY.json')};review_sha256=(File-Hash (Join-Path $recovery 'REVIEW_READY.md'));changeset_sha256=(File-Hash (Join-Path $recovery 'FINAL_CHANGESET.json'));selected_tests_sha256=(File-Hash (Join-Path $recovery 'canonical-tests-02.json'));selected_verification_sha256=(File-Hash (Join-Path $recovery 'final-verification-01.json'))}
Save-New (Join-Path $recovery 'RECOVERY_DELIVERY.json') ([Text.UTF8Encoding]::new($false).GetBytes(($meta|ConvertTo-Json -Depth 8)+"`r`n"))
$meta|ConvertTo-Json -Depth 8
