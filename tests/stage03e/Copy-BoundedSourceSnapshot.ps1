#requires -Version 7.6
# One-shot Stage03E integrity/copy tool. Never executes/imports snapshot content.
# ValidateOnly performs the same complete preflight without creating a snapshot/reservation.
[CmdletBinding()]
param([switch]$ValidateOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$Source='D:\Musicas\Bitter-End-Visual-Local\ComfyUI'
$Destination=Join-Path $Root 'runtimes\core\ComfyUI'
$Evidence=Join-Path $Root 'tests\stage03e\evidence'
$InventoryPath=Join-Path $Root 'spec\G4_SNAPSHOT_COPY_INVENTORY.csv'
$pins=@{
 'spec\G4_SNAPSHOT_COPY_INVENTORY.csv'='a8e69c205a7f98a1aa3bb34d399201a61e76c112c233f7202abc8b25ba2941eb'
 'spec\G4_DEPENDENCY_METADATA.json'='97710ef8f044f13c1eb2c570ba188a697ce301c17aa871ef573a0afbbaabe901'
 'policy\startup-identity.json'='7f42355c74483f6965f6eb6e837b5ac09d71485fcde610882bc627c3dd420edb'
 'policy\startup-policy.json'='e1db244a744f6ee228956d7fdd199c89737822299bab7785b58ba8c9e527795f'
}
function EHash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function EJson([string]$Path){ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($Path)) -AsHashtable -DateKind String}
function Require([bool]$Condition,[string]$Reason){if(-not $Condition){throw "BLOCKED: $Reason"}}
function HandleHash($Stream){$Stream.Position=0;$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Stream)).ToLowerInvariant();$Stream.Position=0;return $hash}
$expected=@{}
foreach($item in (EJson (Join-Path $Root 'tests\stage03d2\evidence\all-existing-before.json'))){$expected[$item.path]=$item.sha256}
foreach($item in (EJson (Join-Path $Root 'tests\stage03d2\evidence\final-audit.json')).changed_preexisting){$expected[$item.path]=$item.after_sha256}
foreach($item in (Import-Csv -LiteralPath (Join-Path $Root 'tests\stage03d2\evidence\new-files-inventory.csv'))){$expected[$item.path]=$item.sha256}
$oldIntegrity=EJson (Join-Path $Root 'tests\stage03d2\evidence\delivery-integrity.json')
Require ($oldIntegrity.receipt_sha256 -ceq 'b19aed5ac764b6d5acd7543d46033fe358d2f4eb15d684ddf2e9f545ec8db5ac') 'D2 receipt pin'
$expected['tests\stage03d2\evidence\new-files-inventory.csv']=$oldIntegrity.new_inventory_sha256
$expected['tests\stage03d2\evidence\delivery-integrity.json']=EHash (Join-Path $Root 'tests\stage03d2\evidence\delivery-integrity.json')
function CheckBaseline {
 foreach($key in $expected.Keys){Require ((Test-Path -LiteralPath (Join-Path $Root $key) -PathType Leaf) -and (EHash (Join-Path $Root $key)) -ceq $expected[$key]) "Existing baseline divergence: $key"}
 foreach($file in (Get-ChildItem -LiteralPath $Root -File -Recurse -Force)){
  $relative=$file.FullName.Substring($Root.Length+1)
  Require ($expected.ContainsKey($relative) -or $relative.StartsWith('tests\stage03e\',[StringComparison]::OrdinalIgnoreCase) -or ($script:copyStarted -and $file.FullName.StartsWith($Destination+'\',[StringComparison]::OrdinalIgnoreCase))) "Unexpected Production OS addition: $relative"
 }
}
$script:copyStarted=$false
CheckBaseline
foreach($key in $pins.Keys){Require ((EHash (Join-Path $Root $key)) -ceq $pins[$key]) "Authoritative input pin: $key"}
Require ($expected.Count -eq 2269) 'Expected complete Stage03D2 baseline count'
Require (-not (Test-Path -LiteralPath $Destination)) 'Destination already exists; no reuse/overwrite'
# Existing fixed helper supplies Windows read-only handle identity/reparse/link queries.
# No startup/job function is called. The native directory creation below is the only new native mutation.
. (Join-Path $Root 'core\Wlb.StartupFiles.ps1')
Initialize-WlbStartupNative
if($null -eq ('WlbStageE.NewDirectory' -as [type])){
 Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace WlbStageE {
 public static class NewDirectory {
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
  static extern bool CreateDirectoryW(string path,IntPtr security);
  public static void CreateNew(string path){
   if(!CreateDirectoryW(path,IntPtr.Zero))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
  }
 }
}
'@
}
$directoryPins=@{}
function PinDirectory([string]$Path){
 $full=[IO.Path]::GetFullPath($Path)
 if($directoryPins.ContainsKey($full)){return}
 $parent=[IO.Path]::GetDirectoryName($full.TrimEnd('\'))
 if($parent -and $parent -cne $full){PinDirectory $parent}
 $item=Get-Item -LiteralPath $full -Force
 Require ($item.PSIsContainer -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) "Directory link/type rejected: $full"
 $handle=[WlbStartup.ReadOnlyNative]::OpenDirectory($full)
 try{
  Require ([WlbStartup.ReadOnlyNative]::FinalPath($handle).Equals($full,[StringComparison]::OrdinalIgnoreCase)) "Directory alias rejected: $full"
  $directoryPins[$full]=[pscustomobject]@{path=$full;handle=$handle;identity=[WlbStartup.ReadOnlyNative]::Identity($handle)}
 }catch{$handle.Dispose();throw}
}
function CheckDirectories {
 foreach($item in $directoryPins.Values){Require ([WlbStartup.ReadOnlyNative]::Identity($item.handle) -ceq $item.identity -and [WlbStartup.ReadOnlyNative]::FinalPath($item.handle).Equals($item.path,[StringComparison]::OrdinalIgnoreCase)) "Directory changed: $($item.path)"}
}
function CheckFileHandle($Stream,[string]$Path,[long]$Bytes,[string]$Identity=''){
 Require ([WlbStartup.ReadOnlyNative]::FinalPath($Stream.SafeFileHandle).Equals($Path,[StringComparison]::OrdinalIgnoreCase)) "Opened file alias: $Path"
 Require ([WlbStartup.ReadOnlyNative]::LinkCount($Stream.SafeFileHandle) -eq 1) "Hardlink rejected: $Path"
 Require ($Stream.Length -eq $Bytes) "Opened file size changed: $Path"
 $actual=[WlbStartup.ReadOnlyNative]::Identity($Stream.SafeFileHandle)
 if($Identity){Require ($actual -ceq $Identity) "File identity changed: $Path"}
 return $actual
}
function MakeNewDirectory([string]$Path){
 Require ($Path.StartsWith($Root+'\',[StringComparison]::OrdinalIgnoreCase)) 'New directory outside Production OS'
 PinDirectory ([IO.Path]::GetDirectoryName($Path))
 CheckDirectories
 [WlbStageE.NewDirectory]::CreateNew($Path)
 $createdDirectories.Add($Path)
 PinDirectory $Path
 CheckDirectories
}
function WriteNewEvidence([string]$Name,[string]$Text){
 Require ($Name -match '^[A-Za-z0-9_.-]+$') 'Evidence name'
 $path=Join-Path $Evidence $Name
 PinDirectory $Evidence
 CheckDirectories
 $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes($Text);$stream.Write($bytes);$stream.Flush($true);$null=CheckFileHandle $stream $path $bytes.Length;CheckDirectories}finally{$stream.Dispose()}
}
$sources=[Collections.Generic.List[object]]::new()
$copied=[Collections.Generic.List[object]]::new()
$createdFiles=[Collections.Generic.List[string]]::new()
$createdDirectories=[Collections.Generic.List[string]]::new()
$preflight=$null;$failure=$null;$reservationStream=$null;$mutex=$null;$acquired=$false;$state='PARTIAL_BLOCKED'
$startUtc=[DateTime]::UtcNow.ToString('o')
try{
 PinDirectory $Root;PinDirectory $Source
 # Validate and retain every approved source's read handle, denying write/delete sharing.
 # No destination directory is created before this complete pass succeeds.
 $rows=@(Import-Csv -LiteralPath $InventoryPath)
 Require ($rows.Count -eq 619 -and ($rows | Measure-Object bytes -Sum).Sum -eq 9533695 -and @($rows.group | Sort-Object -Unique).Count -eq 11) 'Allowlist aggregate'
 $seen=@{};$sourceSeen=@{}
 foreach($row in $rows){
  Require ($row.relative_path -notmatch '(^|[\\/])\.\.?([\\/]|$)|:|^[\\/]' -and $row.relative_path -notmatch '/') 'Noncanonical relative path'
  Require ($row.source -ceq (Join-Path $Source $row.relative_path) -and [IO.Path]::GetFullPath($row.source) -ceq $row.source) 'Source path outside fixed root'
  Require ($row.planned_destination -ceq (Join-Path $Destination $row.relative_path) -and [IO.Path]::GetFullPath($row.planned_destination) -ceq $row.planned_destination) 'Destination path outside fixed root'
  Require (-not $seen.ContainsKey($row.planned_destination) -and -not $sourceSeen.ContainsKey($row.source)) 'Duplicate destination/source'
  $seen[$row.planned_destination]=$true;$sourceSeen[$row.source]=$true
  Require ($row.sha256 -cmatch '^[a-f0-9]{64}$' -and $row.bytes -match '^[0-9]+$') 'Invalid CSV hash/size'
  PinDirectory ([IO.Path]::GetDirectoryName($row.source))
  $item=Get-Item -LiteralPath $row.source -Force
  Require (-not $item.PSIsContainer -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) "Source link/type: $($row.relative_path)"
  $stream=[IO.File]::Open($row.source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  try{
   $fileId=CheckFileHandle $stream $row.source ([long]$row.bytes)
   Require ((HandleHash $stream) -ceq $row.sha256) "Source hash mismatch: $($row.relative_path)"
   $sources.Add([pscustomobject]@{row=$row;stream=$stream;identity=$fileId;last_write_utc=$item.LastWriteTimeUtc.ToString('o')})
  }catch{$stream.Dispose();throw}
 }
 CheckDirectories
 Require (-not (Test-Path -LiteralPath $Destination)) 'Destination appeared during preflight'
 $metadata=EJson (Join-Path $Root 'spec\G4_DEPENDENCY_METADATA.json')
 Require ($metadata.Count -eq 16) 'Dependency distribution count'
 $dependencyEvidence=@()
 foreach($dependency in $metadata){foreach($m in $dependency.metadata){
  Require ($m.path.StartsWith('D:\Musicas\Bitter-End-Visual-Local\.venv\Lib\site-packages\',[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($m.path) -in @('METADATA','WHEEL','RECORD')) 'Dependency metadata path'
  Require ((EHash $m.path) -ceq $m.sha256 -and (Get-Item -LiteralPath $m.path).Length -eq $m.bytes) "Dependency metadata changed: $($m.path)"
  $dependencyEvidence+=[pscustomobject]@{distribution=$dependency.name;path=$m.path;bytes=$m.bytes;sha256=$m.sha256;observation='STATIC_METADATA_ONLY'}
 }}
 $free=[IO.DriveInfo]::new('D:\').AvailableFreeSpace;$required=[long]9533695+64MB
 Require ($free -ge $required) 'Insufficient disk space for content plus conservative filesystem margin'
 CheckBaseline
 $preflight=[ordered]@{state='PRECOPY_INTEGRITY_VERIFIED';validated_utc=[DateTime]::UtcNow.ToString('o');baseline_files=$expected.Count;baseline_divergences=0;source_files=$rows.Count;source_bytes=[long]9533695;groups=11;unique_sources=$sourceSeen.Count;unique_destinations=$seen.Count;all_source_handles_retained=$true;source_hardlink_counts=1;reparse_points_allowed=$false;destination_absent=$true;D_drive_available_bytes=$free;disk_content_plus_margin_bytes=$required;input_pins=$pins;dependency_distributions=16;metadata_files=$dependencyEvidence.Count;runtime_validation='NOT_PERFORMED';validate_only=[bool]$ValidateOnly}
 if($ValidateOnly){ConvertTo-Json $preflight -Depth 8;return}
 # No retry: a persistent reservation excludes this namespace even after interruption.
 $engineHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Destination.ToLowerInvariant()))).Substring(0,24)
 $mutex=[Threading.Mutex]::new($false,('Local\Wlb.Stage03E.Copy.'+$engineHash))
 try{$acquired=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$acquired=$true;throw 'BLOCKED: Abandoned copy mutex; human recovery required'}
 Require $acquired 'Copy mutex already held'
 if(-not (Test-Path -LiteralPath $Evidence)){MakeNewDirectory $Evidence}else{PinDirectory $Evidence}
 $reservationPath=Join-Path $Evidence 'snapshot-reservation.json'
 $reservationStream=[IO.File]::Open($reservationPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 $reservation=[ordered]@{purpose='SOURCE_COPY_ONLY_NOT_STARTUP_OR_RENDER_CONSENT';attempt_id=[Guid]::NewGuid().ToString();source=$Source;destination=$Destination;allowlist_sha256=$pins['spec\G4_SNAPSHOT_COPY_INVENTORY.csv'];start_utc=$startUtc;reuse_allowed=$false;execution_authorized=$false}
 $reservationBytes=[Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json $reservation -Depth 8));$reservationStream.Write($reservationBytes);$reservationStream.Flush($true)
 $null=CheckFileHandle $reservationStream $reservationPath $reservationBytes.Length
 WriteNewEvidence 'precopy-verification.json' (ConvertTo-Json $preflight -Depth 12)
 WriteNewEvidence 'dependency-metadata-recheck.json' (ConvertTo-Json -InputObject $dependencyEvidence -Depth 8)
 $baselineInventory=@($expected.Keys | Sort-Object | ForEach-Object {[pscustomobject]@{path=$_;bytes=(Get-Item -LiteralPath (Join-Path $Root $_)).Length;sha256=$expected[$_]}})
 WriteNewEvidence 'all-existing-before.json' (ConvertTo-Json -InputObject $baselineInventory -Depth 8)
 $sourceBefore=@($sources | ForEach-Object {[pscustomobject]@{relative_path=$_.row.relative_path;source=$_.row.source;destination=$_.row.planned_destination;bytes=[long]$_.row.bytes;sha256=$_.row.sha256;file_identity=$_.identity;last_write_utc=$_.last_write_utc}})
 WriteNewEvidence 'source-before.json' (ConvertTo-Json -InputObject $sourceBefore -Depth 8)
 # Existing parent directories are validated/pinned; absent parents are created atomically.
 foreach($path in @((Join-Path $Root 'runtimes'),(Join-Path $Root 'runtimes\core'))){if(Test-Path -LiteralPath $path){PinDirectory $path}else{MakeNewDirectory $path}}
 Require (-not (Test-Path -LiteralPath $Destination)) 'Destination appeared before CreateDirectoryNew'
 MakeNewDirectory $Destination
 $script:copyStarted=$true
 $requiredDirs=@{}
 foreach($row in $rows){$parent=[IO.Path]::GetDirectoryName($row.planned_destination);while($parent -cne $Destination){Require ($parent.StartsWith($Destination+'\',[StringComparison]::OrdinalIgnoreCase)) 'Derived directory outside snapshot';$requiredDirs[$parent]=$true;$parent=[IO.Path]::GetDirectoryName($parent)}}
 foreach($path in ($requiredDirs.Keys | Sort-Object @{Expression={$_.Length}},@{Expression={$_}})){MakeNewDirectory $path}
 foreach($item in $sources){
  CheckDirectories
  $row=$item.row
  $null=CheckFileHandle $item.stream $row.source ([long]$row.bytes) $item.identity
  Require ((HandleHash $item.stream) -ceq $row.sha256) "Source changed before copy: $($row.relative_path)"
  $target=[IO.File]::Open($row.planned_destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
  $createdFiles.Add($row.planned_destination)
  try{
   CheckDirectories
   $item.stream.Position=0;$item.stream.CopyTo($target);$target.Flush($true)
   $targetId=CheckFileHandle $target $row.planned_destination ([long]$row.bytes)
   $targetHash=HandleHash $target
   Require ($targetHash -ceq $row.sha256) "Copied content mismatch: $($row.relative_path)"
   $copied.Add([pscustomobject]@{relative_path=$row.relative_path;source=$row.source;destination=$row.planned_destination;group=$row.group;bytes=[long]$row.bytes;source_sha256=$row.sha256;destination_sha256=$targetHash;source_identity=$item.identity;destination_identity=$targetId;copy_mode='CreateNew';flushed_to_disk=$true})
  }finally{$target.Dispose()}
  $null=CheckFileHandle $item.stream $row.source ([long]$row.bytes) $item.identity
  Require ((HandleHash $item.stream) -ceq $row.sha256) "Source changed after copy: $($row.relative_path)"
 }
 # Independent directory enumeration, allowlist comparison and new read handles after copying.
 $actual=[Collections.Generic.List[object]]::new()
 $createdByPath=@{};foreach($record in $copied){$createdByPath[$record.destination]=$record}
 $enumerated=@(Get-ChildItem -LiteralPath $Destination -Recurse -File -Force)
 Require ($enumerated.Count -eq 619) 'Actual snapshot file count'
 foreach($file in ($enumerated | Sort-Object FullName)){
  Require ($seen.ContainsKey($file.FullName) -and -not ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) "Unapproved snapshot file: $($file.FullName)"
  $record=$createdByPath[$file.FullName]
  $read=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  try{$actualId=CheckFileHandle $read $file.FullName $record.bytes $record.destination_identity;$actualHash=HandleHash $read;Require ($actualHash -ceq $record.source_sha256) 'Independent destination rehash mismatch'}finally{$read.Dispose()}
  $actual.Add([pscustomobject]@{relative_path=$record.relative_path;path=$file.FullName;group=$record.group;bytes=$file.Length;sha256=$actualHash;file_identity=$actualId;hardlink_count=1;status='STAGED_NOT_ACTIVATED'})
 }
 Require (($actual | Measure-Object bytes -Sum).Sum -eq 9533695) 'Actual snapshot total bytes'
 foreach($directory in (Get-ChildItem -LiteralPath $Destination -Directory -Recurse -Force)){Require ($requiredDirs.ContainsKey($directory.FullName) -and -not ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Extra directory/reparse in snapshot'}
 CheckDirectories
 $sourceAfter=@()
 foreach($item in $sources){$row=$item.row;$null=CheckFileHandle $item.stream $row.source ([long]$row.bytes) $item.identity;Require ((HandleHash $item.stream) -ceq $row.sha256) 'Source final content changed';$pathRead=[IO.File]::Open($row.source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read);try{$null=CheckFileHandle $pathRead $row.source ([long]$row.bytes) $item.identity;Require ((HandleHash $pathRead) -ceq $row.sha256) 'Source path identity/content changed'}finally{$pathRead.Dispose()};$sourceAfter+=[pscustomobject]@{relative_path=$row.relative_path;source=$row.source;bytes=[long]$row.bytes;sha256=$row.sha256;file_identity=$item.identity;preserved=$true}}
 CheckBaseline
 foreach($m in $dependencyEvidence){Require ((EHash $m.path) -ceq $m.sha256) 'Dependency metadata changed after copy'}
 $actualCsv=($actual | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
 WriteNewEvidence 'actual-snapshot-inventory.csv' ($actualCsv+"`r`n")
 $actualInventoryHash=EHash (Join-Path $Evidence 'actual-snapshot-inventory.csv')
 WriteNewEvidence 'copy-execution-ledger.json' (ConvertTo-Json -InputObject @($copied) -Depth 8)
 WriteNewEvidence 'source-after.json' (ConvertTo-Json -InputObject $sourceAfter -Depth 8)
 WriteNewEvidence 'directory-identities.json' (ConvertTo-Json -InputObject @($directoryPins.Values | ForEach-Object {[pscustomobject]@{path=$_.path;identity=$_.identity}} | Sort-Object path) -Depth 8)
 $state='STAGED_NOT_ACTIVATED'
 $outcome=[ordered]@{stage='03E';status='COMPLETE_WITH_LIMITATIONS';snapshot_state=$state;attempt_id=$reservation.attempt_id;source=$Source;destination=$Destination;start_utc=$startUtc;end_utc=[DateTime]::UtcNow.ToString('o');files=619;bytes=[long]9533695;groups=11;actual_inventory=Join-Path $Evidence 'actual-snapshot-inventory.csv';actual_inventory_sha256=$actualInventoryHash;allowlist_sha256=$pins['spec\G4_SNAPSHOT_COPY_INVENTORY.csv'];source_identity_and_content_preserved=$true;baseline_files_preserved=2269;baseline_changes=0;no_extra_snapshot_files=$true;created_directories=@($createdDirectories);snapshot_content_executed=$false;python_executed=$false;imports_performed=$false;runtime_compatibility='NOT_VERIFIED';real_approval_created=$false;canonical_identity_and_bindings_updated=$false;real_startup_enabled=$false;gpu_jobs_enabled=$false;g4='BLOCKED_NOT_AUTHORIZED';g5='NOT_AUTHORIZED';next_gate='WAITING_HUMAN_REVIEW'}
 WriteNewEvidence 'copy-outcome.json' (ConvertTo-Json $outcome -Depth 15)
 ConvertTo-Json $outcome -Depth 12
}catch{
 $failure=$_.Exception.Message
 if(-not $ValidateOnly){
  # Record a unique failure file; do not reuse, delete, overwrite or retry the snapshot.
  $partial=[ordered]@{stage='03E';snapshot_state='PARTIAL_BLOCKED';error=$failure;failed_utc=[DateTime]::UtcNow.ToString('o');destination=$Destination;destination_created=$script:copyStarted;all_created_files=@($createdFiles);verified_copies=@($copied);created_directories=@($createdDirectories);retry_allowed=$false;cleanup_performed=$false;next_gate='WAITING_HUMAN_REVIEW'}
  try{if(-not (Test-Path -LiteralPath $Evidence)){MakeNewDirectory $Evidence};WriteNewEvidence ('failure-'+[Guid]::NewGuid().ToString()+'.json') (ConvertTo-Json $partial -Depth 15)}catch{Write-Output ('FAILURE_EVIDENCE_WRITE_BLOCKED: '+$_.Exception.Message)}
 }
 throw
}finally{
 foreach($item in $sources){$item.stream.Dispose()}
 if($reservationStream){$reservationStream.Dispose()}
 if($acquired -and $mutex){$mutex.ReleaseMutex()};if($mutex){$mutex.Dispose()}
 foreach($item in $directoryPins.Values){$item.handle.Dispose()}
}
