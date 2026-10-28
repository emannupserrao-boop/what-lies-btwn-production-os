#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$recovery=Join-Path $root 'tests\stage03j\recovery-20261015-guard-central'
$expected=[ordered]@{
 'core\Wlb.WorkerProcess.ps1'='dd20a1e2e26b766d45faefb5c76fcf689426446a9c39798a9ad36f211ff68a29'
 'policy\runtime-lock.json'='7c051ecc3926898796f400a2dd4336a1ec773ed970552afaf79f2d2251674d94'
 'manifests\draft\POC0-CALIBRATION-001.json'='2e3e049e60d4f5b5c752715f572658dd842beb1ff113bcb14af1c1ea8af3bbe0'
}
function Hash-Bytes([byte[]]$Bytes){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()}
function Save-New([string]$Path,[byte[]]$Bytes){$stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($Bytes);$stream.Flush($true)}finally{$stream.Dispose()}}
if(Test-Path -LiteralPath $recovery){throw 'RECOVERY_NAMESPACE_ALREADY_EXISTS'}
foreach($relative in $expected.Keys){
 $p=Join-Path $root $relative
 $cursor=$p
 while($cursor.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){
  if(((Get-Item -LiteralPath $cursor).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'REPARSE_PATH_REFUSED'}
  if($cursor -eq $root){break}
  $cursor=[IO.Path]::GetDirectoryName($cursor)
 }
 if((Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() -cne $expected[$relative]){throw ('SOURCE_CHANGED_BEFORE_BACKUP:'+ $relative)}
}
$historical=Import-Csv -LiteralPath (Join-Path $root 'STAGE03J_SHA256_INVENTORY.csv')
foreach($row in $historical){$p=Join-Path $root $row.relative_path;if((Get-Item -LiteralPath $p).Length -ne [long]$row.bytes -or (Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() -cne $row.sha256){throw ('HISTORICAL_PACKAGE_DRIFT:'+ $row.relative_path)}}
$preimage=@(Get-ChildItem -LiteralPath $root -Force -Recurse -File|ForEach-Object {
 [pscustomobject]@{relative_path=[IO.Path]::GetRelativePath($root,$_.FullName);bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}
})
$raw=[ordered]@{}
foreach($relative in $expected.Keys){$raw[$relative]=[IO.File]::ReadAllBytes((Join-Path $root $relative));if((Hash-Bytes $raw[$relative]) -cne $expected[$relative]){throw 'SOURCE_CHANGED_DURING_SNAPSHOT'}}
$null=[IO.Directory]::CreateDirectory((Join-Path $recovery 'backup'))
$records=@(foreach($relative in $expected.Keys){
 $dest=Join-Path $recovery ('backup\'+$relative.Replace('\','__'))
 Save-New $dest $raw[$relative]
 if((Get-FileHash -LiteralPath $dest).Hash.ToLowerInvariant() -cne $expected[$relative]){throw ('BACKUP_VERIFICATION_FAILED:'+ $relative)}
 [pscustomobject]@{relative_path=$relative;backup_relative_path=[IO.Path]::GetRelativePath($root,$dest);bytes=$raw[$relative].Length;sha256=$expected[$relative]}
})
$csv=($preimage|ConvertTo-Csv -NoTypeInformation)-join "`r`n"
Save-New (Join-Path $recovery 'prechange-inventory.csv') ([Text.UTF8Encoding]::new($false).GetBytes($csv+"`r`n"))
foreach($relative in $expected.Keys){if((Get-FileHash -LiteralPath (Join-Path $root $relative)).Hash.ToLowerInvariant() -cne $expected[$relative]){throw 'SOURCE_CHANGED_AFTER_BACKUP'}}
$receipt=[ordered]@{schema='wlb-stage03j-central-guard-backup/0.1';utc=[DateTime]::UtcNow.ToString('o');status='BACKUP_VERIFIED_BEFORE_CANONICAL_WRITES';historical_inventory_rows=$historical.Count;prechange_files=$preimage.Count;prechange_inventory_sha256=(Get-FileHash -LiteralPath (Join-Path $recovery 'prechange-inventory.csv')).Hash.ToLowerInvariant();files=$records;runtime_or_helper_started=$false}
Save-New (Join-Path $recovery 'BACKUP_VERIFIED.json') ([Text.UTF8Encoding]::new($false).GetBytes(($receipt|ConvertTo-Json -Depth 8)+"`r`n"))
$receipt|ConvertTo-Json -Depth 8
