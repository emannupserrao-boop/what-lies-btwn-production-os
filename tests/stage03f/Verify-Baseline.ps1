#requires -Version 7.6
# Stage03F: read-only content/identity audit; new evidence/backups only. NO copy into snapshot.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$Stage=Join-Path $Root 'tests\stage03f'
$Evidence=Join-Path $Stage 'evidence'
if(Test-Path -LiteralPath $Evidence){throw 'BLOCKED: Stage03F evidence already exists; no automatic repeat'}
function Check([bool]$ok,[string]$why){if(-not $ok){throw "BLOCKED: $why"}}
function Hash([string]$path){(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Json([string]$path){return ,(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -DateKind String)}
function WriteNew([string]$path,[byte[]]$bytes){Check ($path.StartsWith($Stage+'\',[StringComparison]::OrdinalIgnoreCase)) 'Evidence outside Stage03F';$s=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write($bytes);$s.Flush($true)}finally{$s.Dispose()}}
function Save([string]$path,$value){WriteNew $path ([Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject $value -Depth 50)))}
$pins=@{
 'policy\startup-identity.json'='7f42355c74483f6965f6eb6e837b5ac09d71485fcde610882bc627c3dd420edb'
 'policy\startup-policy.json'='e1db244a744f6ee228956d7fdd199c89737822299bab7785b58ba8c9e527795f'
 'policy\runtime-lock.json'='2cba41ae01245961e941edb9d1f5ce016b773d6a7d99236d5e71c1b2f4727a98'
 'manifests\draft\POC0-CALIBRATION-001.json'='349503c85cde19f23558f4dcecdaf4192dfea9cef52e19aa264cdf36fe5eeebb'
 'core\Wlb.Startup.ps1'='1fffe9825cb7d7044e4e8e0dd2431aa9df559fec450c356e69538859cdd3825d'
 'core\Start-WlbRuntime.ps1'='3ed6a6cea5f1602bc47f95ffc4b031a102b12f9fdfe3f204b259ff9dfc6b9e26'
 'spec\G4_SNAPSHOT_COPY_INVENTORY.csv'='a8e69c205a7f98a1aa3bb34d399201a61e76c112c233f7202abc8b25ba2941eb'
 'tests\stage03e\evidence\actual-snapshot-inventory.csv'='a7019b00d50a866729ebfc7806f91e7495bd69561783694bfff5198ffb35a8df'
 'spec\G4_DEPENDENCY_METADATA.json'='97710ef8f044f13c1eb2c570ba188a697ce301c17aa871ef573a0afbbaabe901'
}
foreach($key in $pins.Keys){Check ((Hash (Join-Path $Root $key)) -ceq $pins[$key]) "Baseline pin drift: $key"}
$lock=Json (Join-Path $Root 'policy\runtime-lock.json')
foreach($key in $lock.prepared_artifacts.Keys){Check ((Hash (Join-Path $Root $key)) -ceq $lock.prepared_artifacts[$key]) "Prepared artifact drift: $key"}
. (Join-Path $Root 'core\Wlb.StartupFiles.ps1')
Initialize-WlbStartupNative
$held=[Collections.Generic.List[object]]::new();$checks=[Collections.Generic.List[object]]::new()
$actual=@(Import-Csv -LiteralPath (Join-Path $Root 'tests\stage03e\evidence\actual-snapshot-inventory.csv'))
$proposal=@(Import-Csv -LiteralPath (Join-Path $Root 'spec\G4_SNAPSHOT_COPY_INVENTORY.csv'))
$sourceBefore=Json (Join-Path $Root 'tests\stage03e\evidence\source-before.json')
$directoryBefore=Json (Join-Path $Root 'tests\stage03e\evidence\directory-identities.json')
$snapshot=Join-Path $Root 'runtimes\core\ComfyUI';$source='D:\Musicas\Bitter-End-Visual-Local\ComfyUI'
Check ($actual.Count -eq 619 -and $proposal.Count -eq 619 -and $sourceBefore.Count -eq 619) 'Inventory counts'
$map=@{};$sourceMap=@{};foreach($a in $actual){Check (-not $map.ContainsKey($a.relative_path)) 'Duplicate actual path';$map[$a.relative_path]=$a};foreach($s in $sourceBefore){$sourceMap[$s.relative_path]=$s}
try{
 foreach($directory in $directoryBefore){$h=[WlbStartup.ReadOnlyNative]::OpenDirectory($directory.path);try{Check ([WlbStartup.ReadOnlyNative]::Identity($h) -ceq $directory.identity -and [WlbStartup.ReadOnlyNative]::FinalPath($h).Equals($directory.path,[StringComparison]::OrdinalIgnoreCase)) 'Directory identity replacement';$held.Add($h)}catch{$h.Dispose();throw}}
 foreach($p in $proposal){
  Check ($p.relative_path -notmatch '(^|[\\/])\.\.?([\\/]|$)|:|^[\\/]') 'Relative inventory escape'
  Check ($p.source -ceq (Join-Path $source $p.relative_path) -and $p.planned_destination -ceq (Join-Path $snapshot $p.relative_path)) 'Origin/destination allowlist escape'
  Check ($map.ContainsKey($p.relative_path) -and $sourceMap.ContainsKey($p.relative_path)) 'Missing approved path'
  $a=$map[$p.relative_path]
  Check ($a.path -ceq $p.planned_destination -and $a.group -ceq $p.group -and $a.bytes -ceq $p.bytes -and $a.sha256 -ceq $p.sha256 -and $a.status -ceq 'STAGED_NOT_ACTIVATED') 'Actual/proposal divergence'
  foreach($side in @('SOURCE','SNAPSHOT')){
   $path=if($side -ceq 'SOURCE'){$p.source}else{$p.planned_destination};$expectedId=if($side -ceq 'SOURCE'){$sourceMap[$p.relative_path].file_identity}else{$a.file_identity}
   $item=Get-Item -LiteralPath $path -Force;Check (-not $item.PSIsContainer -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Link or file type drift'
   $s=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
   try{$id=[WlbStartup.ReadOnlyNative]::Identity($s.SafeFileHandle);$links=[WlbStartup.ReadOnlyNative]::LinkCount($s.SafeFileHandle);$final=[WlbStartup.ReadOnlyNative]::FinalPath($s.SafeFileHandle);$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($s)).ToLowerInvariant();Check ($id -ceq $expectedId -and $links -eq 1 -and $s.Length -eq [long]$p.bytes -and $hash -ceq $p.sha256 -and $final.Equals($path,[StringComparison]::OrdinalIgnoreCase)) "Content/path/identity drift: $path";$checks.Add([pscustomobject]@{side=$side;relative_path=$p.relative_path;path=$path;bytes=$s.Length;sha256=$hash;file_identity=$id;hardlink_count=$links;status='PASS_STATIC_CONTENT_ONLY'})}finally{$s.Dispose()}
  }
 }
 $all=@(Get-ChildItem -LiteralPath $snapshot -Recurse -Force)
 Check (@($all | Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0}).Count -eq 0) 'Unexpected snapshot link'
 $files=@($all | Where-Object {-not $_.PSIsContainer})
 Check ($files.Count -eq 619 -and ($files | Measure-Object Length -Sum).Sum -eq 9533695 -and @($actual | Group-Object group).Count -eq 11) 'Snapshot aggregate mismatch'
 foreach($file in $files){Check ($map.ContainsKey($file.FullName.Substring($snapshot.Length+1))) 'Extra snapshot file'}
 $parents=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 foreach($a in $actual){$parent=[IO.Path]::GetDirectoryName($a.path);while($parent.StartsWith($snapshot+'\',[StringComparison]::OrdinalIgnoreCase)){$null=$parents.Add($parent);$parent=[IO.Path]::GetDirectoryName($parent)}}
 foreach($dir in @($all | Where-Object {$_.PSIsContainer})){Check ($parents.Contains($dir.FullName)) 'Unexpected snapshot directory'}
 $metadata=Json (Join-Path $Root 'spec\G4_DEPENDENCY_METADATA.json')
 foreach($dep in $metadata){foreach($m in $dep.metadata){Check ((Hash $m.path) -ceq $m.sha256 -and (Get-Item -LiteralPath $m.path).Length -eq $m.bytes) 'Dependency metadata drift';$null=Get-Content -LiteralPath $m.path -Raw}}
 $baseline=@(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Where-Object {-not $_.FullName.StartsWith($Stage+'\',[StringComparison]::OrdinalIgnoreCase)} | ForEach-Object {[pscustomobject]@{relative_path=$_.FullName.Substring($Root.Length+1);bytes=$_.Length;sha256=Hash $_.FullName}})
 $null=New-Item -ItemType Directory -Path $Evidence,(Join-Path $Stage 'baseline')
 Save (Join-Path $Evidence 'all-existing-before.json') $baseline
 WriteNew (Join-Path $Evidence 'snapshot-checks-before.csv') ([Text.UTF8Encoding]::new($false).GetBytes((($checks | ConvertTo-Csv -NoTypeInformation) -join "`r`n")))
 $summary=[ordered]@{stage='03F';inventory_sha256=$pins['tests\stage03e\evidence\actual-snapshot-inventory.csv'];snapshot_files=619;bytes=9533695;groups=11;source_checks=619;destination_checks=619;directory_identities=$directoryBefore.Count;metadata_files=48;extra_files=0;existing_files=$baseline.Count;content_verified=$true;runtime_compatibility='NOT_VERIFIED';g4='BLOCKED';g5='NOT_AUTHORIZED';reservation_sha256=Hash (Join-Path $Root 'tests\stage03e\evidence\snapshot-reservation.json')}
 Save (Join-Path $Evidence 'baseline-summary.json') $summary
 foreach($key in @('policy\startup-identity.json','core\Wlb.Startup.ps1','core\Start-WlbRuntime.ps1','policy\runtime-lock.json','manifests\draft\POC0-CALIBRATION-001.json')){$dest=Join-Path (Join-Path $Stage 'baseline') $key;$parent=[IO.Path]::GetDirectoryName($dest);if(-not(Test-Path -LiteralPath $parent)){$null=New-Item -ItemType Directory -Path $parent};WriteNew $dest ([IO.File]::ReadAllBytes((Join-Path $Root $key)));Check ((Hash $dest) -ceq $pins[$key]) 'Baseline backup mismatch'}
 $summary | ConvertTo-Json -Depth 8
}finally{foreach($h in $held){$h.Dispose()}}
