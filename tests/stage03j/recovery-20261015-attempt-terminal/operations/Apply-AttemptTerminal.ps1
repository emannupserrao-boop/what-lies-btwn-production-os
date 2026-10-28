#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$recovery=Join-Path $root 'tests\stage03j\recovery-20261015-attempt-terminal'
$workspace='C:\Users\user\Documents\Codex\2026-10-15\task-2'
function Hash-Bytes([byte[]]$Bytes){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()}
function Save-New([string]$Path,[byte[]]$Bytes){$s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write($Bytes);$s.Flush($true)}finally{$s.Dispose()}}
function Replace-One([string]$Text,[string]$Old,[string]$New){if(($Text.Split(@($Old),[StringSplitOptions]::None).Count-1) -ne 1){throw 'BINDING_REPLACEMENT_NOT_UNIQUE'};$Text.Replace($Old,$New)}
$receiptPath=Join-Path $recovery 'BACKUP_VERIFIED.json'
if((Get-FileHash -LiteralPath $receiptPath).Hash.ToLowerInvariant() -cne '71d5923229f846f9fda00d0a00424d56d1c3c492ab17e864bb8de436a4ce630d'){throw 'BACKUP_RECEIPT_CHANGED'}
$receipt=Get-Content -LiteralPath $receiptPath -Raw|ConvertFrom-Json
if($receipt.status -cne 'BACKUP_VERIFIED_BEFORE_CANONICAL_WRITES'){throw 'BACKUP_NOT_VERIFIED'}
$preimage=Import-Csv -LiteralPath (Join-Path $recovery 'prechange-inventory.csv')
if((Get-FileHash -LiteralPath (Join-Path $recovery 'prechange-inventory.csv')).Hash.ToLowerInvariant() -cne $receipt.prechange_inventory_sha256){throw 'PREIMAGE_INVENTORY_CHANGED'}
$drift=@(foreach($row in $preimage){$p=Join-Path $root $row.relative_path;if(-not(Test-Path -LiteralPath $p -PathType Leaf)){ $row.relative_path;continue };if((Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() -cne $row.sha256){$row.relative_path}})
$known=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);foreach($row in $preimage){$null=$known.Add($row.relative_path)}
$foreignNew=@(Get-ChildItem -LiteralPath $root -Force -Recurse -File|Where-Object {-not $_.FullName.StartsWith($recovery+'\',[StringComparison]::OrdinalIgnoreCase)}|ForEach-Object {$rel=[IO.Path]::GetRelativePath($root,$_.FullName);if(-not $known.Contains($rel)){$rel}})
if($drift.Count -or $foreignNew.Count){throw ('CONCURRENT_CHANGE_REFUSED:'+ (($drift+$foreignNew)-join ';'))}
$old=[ordered]@{};foreach($row in $receipt.files){$backup=Join-Path $root $row.backup_relative_path;$bytes=[IO.File]::ReadAllBytes($backup);if((Hash-Bytes $bytes) -cne $row.sha256){throw 'BACKUP_HASH_DIVERGED'};$old[$row.relative_path]=$bytes}
$module=[IO.File]::ReadAllBytes((Join-Path $workspace 'Wlb.WorkerProcess.terminal-proposed.ps1'))
if((Hash-Bytes $module) -cne '21a16861c526d52b8ce70fc7dc534bed2898b2a58b2ae34c905bb223a105d34e'){throw 'PROPOSED_MODULE_CHANGED'}
$moduleHash=Hash-Bytes $module
$lockText=[Text.Encoding]::UTF8.GetString($old['policy\runtime-lock.json'])
$newLock=([Text.UTF8Encoding]::new($false)).GetBytes((Replace-One $lockText '4cd34847f8e83a9eda12fa8371c5a55efdede17bc4d1e01445f34e19f46c9c4d' $moduleHash))
$lockHash=Hash-Bytes $newLock
$draftText=[Text.Encoding]::UTF8.GetString($old['manifests\draft\POC0-CALIBRATION-001.json'])
$newDraft=([Text.UTF8Encoding]::new($false)).GetBytes((Replace-One $draftText '50c6b9dfe0d30934399fff7241fe062444e1aa3871dd49933b781a9be0ed7cc7' $lockHash))
$replacement=[ordered]@{'core\Wlb.WorkerProcess.ps1'=$module;'policy\runtime-lock.json'=$newLock;'manifests\draft\POC0-CALIBRATION-001.json'=$newDraft}
$testBytes=[IO.File]::ReadAllBytes((Join-Path $workspace 'Test-AttemptTerminalNoCreate.ps1'))
Save-New (Join-Path $recovery 'Test-AttemptTerminalNoCreate.ps1') $testBytes
Save-New (Join-Path $recovery 'preapply-concurrency-check.json') ([Text.UTF8Encoding]::new($false).GetBytes((@{utc=[DateTime]::UtcNow.ToString('o');preimage_files=$preimage.Count;changed_files=$drift;foreign_new_files=$foreignNew;status='NO_CONCURRENT_CONTENT_CHANGES'}|ConvertTo-Json -Depth 5)+"`r`n"))
$held=[ordered]@{}
try{
 # Open all three existing files exclusively and verify their preimages before the first write.
 foreach($row in $receipt.files){$stream=[IO.File]::Open((Join-Path $root $row.relative_path),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$held[$row.relative_path]=$stream;$memory=[IO.MemoryStream]::new();try{$stream.CopyTo($memory);if((Hash-Bytes $memory.ToArray()) -cne $row.sha256){throw 'CONCURRENT_TARGET_CHANGE_REFUSED'}}finally{$memory.Dispose()}}
 foreach($key in $replacement.Keys){$stream=$held[$key];$stream.Position=0;$stream.SetLength($replacement[$key].Length);$stream.Write($replacement[$key]);$stream.Flush($true)}
 foreach($key in $replacement.Keys){$stream=$held[$key];$stream.Position=0;$memory=[IO.MemoryStream]::new();try{$stream.CopyTo($memory);if((Hash-Bytes $memory.ToArray()) -cne (Hash-Bytes $replacement[$key])){throw 'POSTWRITE_VERIFICATION_FAILED'}}finally{$memory.Dispose()}}
}finally{foreach($stream in $held.Values){$stream.Dispose()}}
$changes=@(foreach($key in $replacement.Keys){[ordered]@{path=$key;before_sha256=(Hash-Bytes $old[$key]);after_sha256=(Hash-Bytes $replacement[$key]);before_bytes=$old[$key].Length;after_bytes=$replacement[$key].Length}})
$applied=[ordered]@{schema='wlb-stage03j-attempt-terminal-applied/0.1';utc=[DateTime]::UtcNow.ToString('o');changes=$changes;test_sha256=(Hash-Bytes $testBytes);real_helpers_created=0;normal_exit_attempt='NOT_RUN_AWAITING_INDEPENDENT_REVIEW';g4=$false;g5=$false;historical_package_overwritten=$false}
Save-New (Join-Path $recovery 'FINAL_CHANGESET.json') ([Text.UTF8Encoding]::new($false).GetBytes(($applied|ConvertTo-Json -Depth 8)+"`r`n"))
$applied|ConvertTo-Json -Depth 8
