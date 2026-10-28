#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$prior=Join-Path $root 'tests\stage03j\recovery-20261015-guard-central'
$recovery=Join-Path $root 'tests\stage03j\recovery-20261015-attempt-terminal'
$expected=[ordered]@{'core\Wlb.WorkerProcess.ps1'='4cd34847f8e83a9eda12fa8371c5a55efdede17bc4d1e01445f34e19f46c9c4d';'policy\runtime-lock.json'='50c6b9dfe0d30934399fff7241fe062444e1aa3871dd49933b781a9be0ed7cc7';'manifests\draft\POC0-CALIBRATION-001.json'='122d4791c387dd193527e88dc38de8577be5d96f87bcbe088ce42a18c6f77bad'}
function Hash-Bytes([byte[]]$Bytes){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()}
function Save-New([string]$Path,[byte[]]$Bytes){$s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write($Bytes);$s.Flush($true)}finally{$s.Dispose()}}
if(Test-Path -LiteralPath $recovery){throw 'RECOVERY_NAMESPACE_EXISTS'}
if((Get-FileHash -LiteralPath (Join-Path $prior 'RECOVERY_DELIVERY.json')).Hash.ToLowerInvariant() -cne '9c169452dc426bf3bda3f9273dfc35022725235ece7e604e6489ec72779843a5'){throw 'PRIOR_DELIVERY_CHANGED'}
if((Get-FileHash -LiteralPath (Join-Path $prior 'RECOVERY_SHA256.csv')).Hash.ToLowerInvariant() -cne 'dc6e00c844b784f7dbcff53434cbcaf80a74891b2148ebd2d96e8f34fbf50915'){throw 'PRIOR_INVENTORY_CHANGED'}
$previous=Import-Csv -LiteralPath (Join-Path $prior 'RECOVERY_SHA256.csv')
foreach($row in $previous){$p=Join-Path $root $row.relative_path;if((Get-Item -LiteralPath $p).Length -ne [long]$row.bytes -or (Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() -cne $row.sha256){throw ('PRIOR_PACKAGE_DRIFT:'+ $row.relative_path)}}
$raw=[ordered]@{};foreach($key in $expected.Keys){$p=Join-Path $root $key;$cursor=$p;while($cursor.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){if(((Get-Item -LiteralPath $cursor).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'REPARSE_PATH'};if($cursor -eq $root){break};$cursor=[IO.Path]::GetDirectoryName($cursor)};$raw[$key]=[IO.File]::ReadAllBytes($p);if((Hash-Bytes $raw[$key]) -cne $expected[$key]){throw 'CANONICAL_PREIMAGE_CHANGED'}}
$preimage=@(Get-ChildItem -LiteralPath $root -Force -Recurse -File|ForEach-Object {[pscustomobject]@{relative_path=[IO.Path]::GetRelativePath($root,$_.FullName);bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
foreach($key in $expected.Keys){if((Get-FileHash -LiteralPath (Join-Path $root $key)).Hash.ToLowerInvariant() -cne $expected[$key]){throw 'TARGET_CHANGED_DURING_SNAPSHOT'}}
$null=[IO.Directory]::CreateDirectory((Join-Path $recovery 'backup'))
$files=@(foreach($key in $expected.Keys){$dest=Join-Path $recovery ('backup\'+$key.Replace('\','__'));Save-New $dest $raw[$key];if((Get-FileHash -LiteralPath $dest).Hash.ToLowerInvariant() -cne $expected[$key]){throw 'BACKUP_VERIFICATION_FAILED'};[ordered]@{relative_path=$key;backup_relative_path=[IO.Path]::GetRelativePath($root,$dest);bytes=$raw[$key].Length;sha256=$expected[$key]}})
$csv=($preimage|ConvertTo-Csv -NoTypeInformation)-join "`r`n"
Save-New (Join-Path $recovery 'prechange-inventory.csv') ([Text.UTF8Encoding]::new($false).GetBytes($csv+"`r`n"))
foreach($key in $expected.Keys){if((Get-FileHash -LiteralPath (Join-Path $root $key)).Hash.ToLowerInvariant() -cne $expected[$key]){throw 'TARGET_CHANGED_AFTER_BACKUP'}}
$receipt=[ordered]@{schema='wlb-stage03j-attempt-terminal-backup/0.1';utc=[DateTime]::UtcNow.ToString('o');status='BACKUP_VERIFIED_BEFORE_CANONICAL_WRITES';prior_delivery_sha256='9c169452dc426bf3bda3f9273dfc35022725235ece7e604e6489ec72779843a5';prior_inventory_rows=$previous.Count;prechange_files=$preimage.Count;prechange_inventory_sha256=(Get-FileHash -LiteralPath (Join-Path $recovery 'prechange-inventory.csv')).Hash.ToLowerInvariant();files=$files;real_helpers_created=0}
Save-New (Join-Path $recovery 'BACKUP_VERIFIED.json') ([Text.UTF8Encoding]::new($false).GetBytes(($receipt|ConvertTo-Json -Depth 8)+"`r`n"))
$receipt|ConvertTo-Json -Depth 8
