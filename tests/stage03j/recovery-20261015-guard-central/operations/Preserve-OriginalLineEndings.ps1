#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$recovery=Join-Path $root 'tests\stage03j\recovery-20261015-guard-central'
function Hash-Bytes([byte[]]$Bytes){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()}
function Save-New([string]$Path,[byte[]]$Bytes){$s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write($Bytes);$s.Flush($true)}finally{$s.Dispose()}}
$applied=Get-Content -LiteralPath (Join-Path $recovery 'APPLIED_CHANGESET.json') -Raw|ConvertFrom-Json
$before=[ordered]@{}
foreach($row in $applied.changes){$b=[IO.File]::ReadAllBytes((Join-Path $root $row.path));if((Hash-Bytes $b) -cne $row.after_sha256){throw 'CONCURRENT_TARGET_CHANGE'};$before[$row.path]=$b}
$historical=[IO.File]::ReadAllText((Join-Path $recovery 'backup\core__Wlb.WorkerProcess.ps1'))
if($historical.Contains("`r")){throw 'ORIGINAL_LINE_ENDINGS_UNEXPECTED'}
$encoding=[Text.UTF8Encoding]::new($false)
$module=$encoding.GetBytes([Text.Encoding]::UTF8.GetString($before['core\Wlb.WorkerProcess.ps1']).Replace("`r`n","`n"))
$moduleHash=Hash-Bytes $module
if($moduleHash -cne '4cd34847f8e83a9eda12fa8371c5a55efdede17bc4d1e01445f34e19f46c9c4d'){throw 'LF_CANDIDATE_CHANGED'}
$lock=$encoding.GetBytes([Text.Encoding]::UTF8.GetString($before['policy\runtime-lock.json']).Replace('6e5e0624099c68f572ddf0b171cd7e046d9e7a66dd3e48dfb5e9adc0f5522069',$moduleHash))
$lockHash=Hash-Bytes $lock
$draft=$encoding.GetBytes([Text.Encoding]::UTF8.GetString($before['manifests\draft\POC0-CALIBRATION-001.json']).Replace('36c8a637942b46ba59fac582c384ed060bea91e3c25d2e2ed6fcf46353cc9f2b',$lockHash))
$replacement=[ordered]@{'core\Wlb.WorkerProcess.ps1'=$module;'policy\runtime-lock.json'=$lock;'manifests\draft\POC0-CALIBRATION-001.json'=$draft}
$null=[IO.Directory]::CreateDirectory((Join-Path $recovery 'backup-intermediate'))
foreach($key in $before.Keys){$p=Join-Path $recovery ('backup-intermediate\'+$key.Replace('\','__'));Save-New $p $before[$key];if((Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() -cne (Hash-Bytes $before[$key])){throw 'INTERMEDIATE_BACKUP_FAILED'}}
$held=[ordered]@{}
try{
 foreach($key in $before.Keys){$s=[IO.File]::Open((Join-Path $root $key),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$held[$key]=$s;$m=[IO.MemoryStream]::new();try{$s.CopyTo($m);if((Hash-Bytes $m.ToArray()) -cne (Hash-Bytes $before[$key])){throw 'CONCURRENT_TARGET_CHANGE'}}finally{$m.Dispose()}}
 foreach($key in $replacement.Keys){$s=$held[$key];$s.Position=0;$s.SetLength($replacement[$key].Length);$s.Write($replacement[$key]);$s.Flush($true)}
}finally{foreach($s in $held.Values){$s.Dispose()}}
$changes=@(foreach($row in $applied.changes){$key=$row.path;if((Get-FileHash -LiteralPath (Join-Path $root $key)).Hash.ToLowerInvariant() -cne (Hash-Bytes $replacement[$key])){throw 'POSTWRITE_HASH_FAILED'};[ordered]@{path=$key;before_sha256=$row.before_sha256;after_sha256=(Hash-Bytes $replacement[$key]);before_bytes=$row.before_bytes;after_bytes=$replacement[$key].Length}})
$final=[ordered]@{schema='wlb-stage03j-central-guard-final-changeset/0.1';utc=[DateTime]::UtcNow.ToString('o');changes=$changes;note='Preserved original module LF line endings; intermediate CRLF version and test results retained separately.';real_helpers_created=0;normal_exit_attempt='NOT_RUN_AWAITING_INDEPENDENT_REVIEW';g4=$false;g5=$false}
Save-New (Join-Path $recovery 'FINAL_CHANGESET.json') ($encoding.GetBytes(($final|ConvertTo-Json -Depth 8)+"`r`n"))
$final|ConvertTo-Json -Depth 8
