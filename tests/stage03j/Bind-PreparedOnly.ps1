#requires -Version 7.6
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$validator=Join-Path $root 'core\Test-WlbManifest.ps1'
$text=[IO.File]::ReadAllText($validator)
if(-not $text.Contains("'core\Wlb.WorkerProcess.ps1'")){
 $old="'core\Wlb.Supervisor.ps1', 'core\Wlb.TelemetryWorker.ps1')"
 if(-not $text.Contains($old)){throw 'UNEXPECTED_VALIDATOR_ALLOWLIST'}
 $text=$text.Replace($old,"'core\Wlb.Supervisor.ps1', 'core\Wlb.TelemetryWorker.ps1', 'core\Wlb.WorkerProcess.ps1', 'tests\stage03j\OwnedTelemetryWorker.ps1')")
 [IO.File]::WriteAllText($validator,$text,[Text.UTF8Encoding]::new($false))
}
$lockPath=Join-Path $root 'policy\runtime-lock.json';$oldLock=Get-FileHash -LiteralPath $lockPath
$lockText=[IO.File]::ReadAllText($lockPath)
$lock=$lockText|ConvertFrom-Json -AsHashtable
foreach($key in @('core\Test-WlbManifest.ps1','core\Wlb.WorkerProcess.ps1','tests\stage03j\OwnedTelemetryWorker.ps1')){
 $sha=(Get-FileHash -LiteralPath (Join-Path $root $key)).Hash.ToLowerInvariant()
 if($lock.prepared_artifacts.Contains($key)){$lockText=$lockText.Replace([string]$lock.prepared_artifacts[$key],$sha)}
 else{
  $anchor='    "core\\Wlb.TelemetryWorker.ps1": "'+$lock.prepared_artifacts['core\Wlb.TelemetryWorker.ps1']+'"'
  if(-not $lockText.Contains($anchor)){throw 'UNEXPECTED_PIN_ANCHOR'}
  $entry='    "'+$key.Replace('\','\\')+'": "'+$sha+'"'
  $lockText=$lockText.Replace($anchor,$anchor+",`r`n"+$entry)
 }
}
[IO.File]::WriteAllText($lockPath,$lockText,[Text.UTF8Encoding]::new($false))
$newLock=(Get-FileHash -LiteralPath $lockPath).Hash.ToLowerInvariant()
$manifestPath=Join-Path $root 'manifests\draft\POC0-CALIBRATION-001.json'
$manifest=[IO.File]::ReadAllText($manifestPath)
if(-not $manifest.Contains($oldLock.Hash.ToLowerInvariant())){throw 'MANIFEST_OLD_LOCK_BINDING_MISMATCH'}
[IO.File]::WriteAllText($manifestPath,$manifest.Replace($oldLock.Hash.ToLowerInvariant(),$newLock),[Text.UTF8Encoding]::new($false))
& $validator -Mode StaticReview
