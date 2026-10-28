#requires -Version 7.6
# Only new-root fixture mirrors; no snapshot copy, runtime or real approvals.
[CmdletBinding()]
param([ValidateSet('initial','run2')][string]$Run='initial')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS';$Stage=Join-Path $Root 'tests\stage03f'
$Fixtures=Join-Path $Stage ('binding-fixtures-'+$Run)
if(Test-Path -LiteralPath $Fixtures){throw 'Fresh binding fixtures required'}
$null=New-Item -ItemType Directory -Path $Fixtures
function Hash([string]$p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function Json([string]$p){return ,(Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
function Save([string]$p,$v){[IO.File]::WriteAllText($p,(ConvertTo-Json -InputObject $v -Depth 70),[Text.UTF8Encoding]::new($false))}
$lock=Json (Join-Path $Root 'policy\runtime-lock.json')
$files=@($lock.prepared_artifacts.Keys)+@('policy\runtime-lock.json','manifests\draft\POC0-CALIBRATION-001.json')
$rows=[Collections.Generic.List[object]]::new()
foreach($case in @('BASELINE','STARTUP_CODE_AFTER_PIN','ENTRY_CODE_AFTER_PIN','MANIFEST_LOCK_BINDING','LOCK_BYTES','FORGED_STARTUP_PIN','ENABLE_JOBS','PROMOTE_DRAFT')){
 $mirror=Join-Path $Fixtures $case
 foreach($relative in $files){$p=Join-Path $mirror $relative;$parent=[IO.Path]::GetDirectoryName($p);if(-not(Test-Path -LiteralPath $parent)){$null=New-Item -ItemType Directory -Path $parent};$text=[IO.File]::ReadAllText((Join-Path $Root $relative));$text=$text.Replace($Root.Replace('\','\\'),$mirror.Replace('\','\\')).Replace($Root,$mirror);[IO.File]::WriteAllText($p,$text,[Text.UTF8Encoding]::new($false))}
 $runtimePath=Join-Path $mirror 'policy\runtime-lock.json';$mPath=Join-Path $mirror 'manifests\draft\POC0-CALIBRATION-001.json'
 $r=Json $runtimePath;foreach($key in @($r.prepared_artifacts.Keys)){$r.prepared_artifacts[$key]=Hash (Join-Path $mirror $key)};Save $runtimePath $r
 $m=Json $mPath;$m.workflow.sha256=Hash (Join-Path $mirror 'workflows\draft\poc0-calibration.api.json');$m.binding.policy_sha256=Hash (Join-Path $mirror 'policy\executor-policy.json');$m.binding.runtime_lock_sha256=Hash $runtimePath;Save $mPath $m
 $pattern='BLOCKED:'
 switch($case){
  'STARTUP_CODE_AFTER_PIN'{[IO.File]::AppendAllText((Join-Path $mirror 'core\Wlb.Startup.ps1'),"`n# OWN TEST TAMPER`n");$pattern='Prepared artifact changed: core\\Wlb.Startup'}
  'ENTRY_CODE_AFTER_PIN'{[IO.File]::AppendAllText((Join-Path $mirror 'core\Start-WlbRuntime.ps1'),"`n# OWN TEST TAMPER`n");$pattern='Prepared artifact changed: core\\Start-WlbRuntime'}
  'MANIFEST_LOCK_BINDING'{$m.binding.runtime_lock_sha256='0'*64;Save $mPath $m;$pattern='Runtime lock hash mismatch'}
  'LOCK_BYTES'{[IO.File]::AppendAllText($runtimePath,"`n ");$pattern='Runtime lock hash mismatch'}
  'FORGED_STARTUP_PIN'{$r.prepared_artifacts['core\Wlb.Startup.ps1']='0'*64;Save $runtimePath $r;$m.binding.runtime_lock_sha256=Hash $runtimePath;Save $mPath $m;$pattern='Prepared artifact changed'}
  'ENABLE_JOBS'{$p=Join-Path $mirror 'policy\executor-policy.json';$v=Json $p;$v.execution_enabled=$true;Save $p $v;$r.prepared_artifacts['policy\executor-policy.json']=Hash $p;Save $runtimePath $r;$m.binding.policy_sha256=Hash $p;$m.binding.runtime_lock_sha256=Hash $runtimePath;Save $mPath $m;$pattern='must disable execution'}
  'PROMOTE_DRAFT'{$m.state='REVIEWED';Save $mPath $m;$pattern='must remain DRAFT'}
 }
 try{$out=& (Join-Path $mirror 'core\Test-WlbManifest.ps1') -Mode StaticReview;$pass=$case -ceq 'BASELINE' -and -not $out.executable;$actual=$out}catch{$actual=$_.Exception.Message;$pass=$case -cne 'BASELINE' -and $actual -match $pattern}
 $rows.Add([pscustomobject]@{id=$case;status=$(if($pass){'PASS'}else{'FAIL'});actual=$actual;evidence_kind='EXECUTED_FULL_STATIC_VALIDATOR_ON_OWN_FIXTURE';snapshot_copied=$false;runtime_started=$false})
}
$path=Join-Path $Stage ('evidence\binding-results-'+$Run+'.json');$s=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write([Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject @($rows) -Depth 30)));$s.Flush($true)}finally{$s.Dispose()}
$rows | Select-Object id,status,actual | ConvertTo-Json -Depth 8
if(@($rows | Where-Object {$_.status -ceq 'FAIL'}).Count){exit 1}
