#requires -Version 7.6
# Static text/METADATA only. No Python imports, resolver or native ABI probe.
[CmdletBinding()]
param([ValidateSet('initial','run2')][string]$Run='initial')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS';$Stage=Join-Path $Root 'tests\stage03f';$Snapshot=Join-Path $Root 'runtimes\core\ComfyUI'
$ReviewRoot=if($Run -ceq 'initial'){Join-Path $Stage 'evidence'}else{Join-Path $Stage 'evidence\dependency-run2'}
if($Run -ceq 'run2'){if(Test-Path -LiteralPath $ReviewRoot){throw 'Fresh dependency evidence required'};$null=New-Item -ItemType Directory -Path $ReviewRoot}
$Site='D:\Musicas\Bitter-End-Visual-Local\.venv\Lib\site-packages'
function Hash([string]$p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function WriteNew([string]$p,[string]$text){if(-not $p.StartsWith($Stage+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Outside Stage03F evidence'};$s=[IO.File]::Open($p,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write([Text.UTF8Encoding]::new($false).GetBytes($text));$s.Flush($true)}finally{$s.Dispose()}}
function Save([string]$p,$v){WriteNew $p (ConvertTo-Json -InputObject $v -Depth 25)}
$distDirs=@(Get-ChildItem -LiteralPath $Site -Directory -Filter '*.dist-info')
$requirements=@(Get-Content -LiteralPath (Join-Path $Snapshot 'requirements.txt') | Where-Object {$_ -match '^[A-Za-z0-9]'} )
$rows=@(foreach($req in $requirements){
 $name=([regex]::Match($req,'^[A-Za-z0-9._-]+')).Value;$norm=$name.ToLowerInvariant().Replace('-','_').Replace('.','_')
 $dirs=@($distDirs | Where-Object {$_.Name.ToLowerInvariant().StartsWith($norm+'-')})
 if($dirs.Count -eq 1){$p=Join-Path $dirs[0].FullName 'METADATA';$text=Get-Content -LiteralPath $p -Raw;$version=([regex]::Match($text,'(?m)^Version:\s*(.+)$')).Groups[1].Value.Trim();$requires=@([regex]::Matches($text,'(?m)^Requires-Dist:\s*(.+)$') | ForEach-Object {$_.Groups[1].Value.Trim()});[pscustomobject]@{name=$name;requirement=$req;metadata_path=$p;metadata_sha256=Hash $p;version=$version;requires_dist=$requires;presence='METADATA_PRESENT_ONLY';constraint_check='NOT_A_RESOLVER_RESULT';imports='NOT_EXECUTED';native_binaries='NOT_AUTHENTICATED'}}else{[pscustomobject]@{name=$name;requirement=$req;metadata_path=$null;version=$null;presence=$(if($dirs.Count){'AMBIGUOUS_METADATA'}else{'METADATA_NOT_OBSERVED'});imports='NOT_EXECUTED';native_binaries='NOT_AUTHENTICATED'}}
})
Save (Join-Path $ReviewRoot 'dependency-metadata-review.json') $rows
$importRows=[Collections.Generic.List[object]]::new()
$inventory=@(Import-Csv -LiteralPath (Join-Path $Root 'tests\stage03e\evidence\actual-snapshot-inventory.csv'))
foreach($file in $inventory | Where-Object {$_.relative_path -match '\.pyi?$'}){
 $lines=@(Get-Content -LiteralPath $file.path)
 for($i=0;$i -lt $lines.Count;$i++){if($lines[$i] -match '^\s*(?:from\s+([.A-Za-z0-9_]+)\s+import|import\s+([.A-Za-z0-9_]+))'){$module=if($Matches[1]){$Matches[1]}else{$Matches[2]};$importRows.Add([pscustomobject]@{file=$file.relative_path;line=$i+1;module=$module;statement=$lines[$i].Trim();analysis='TEXTUAL_IMPORT_REFERENCE_NOT_EXECUTED_NOT_COMPLETE_AST'})}}
}
WriteNew (Join-Path $ReviewRoot 'import-references.csv') (($importRows | ConvertTo-Csv -NoTypeInformation) -join "`r`n")
$paths=@('D:\Musicas\Bitter-End-Visual-Local\ComfyUI\alembic.ini','D:\Musicas\Bitter-End-Visual-Local\.venv\pyvenv.cfg',"$Site\alembic\config.py","$Site\alembic\util\compat.py","$Site\alembic\script\base.py","$Site\comfyui_frontend_package\static\index.html")
$external=@(foreach($p in $paths){if(Test-Path -LiteralPath $p){[pscustomobject]@{path=$p;bytes=(Get-Item -LiteralPath $p).Length;sha256=Hash $p;operation='READ_ONLY_TEXT_OR_HASH';runtime='NOT_VERIFIED'}}else{[pscustomobject]@{path=$p;status='NOT_OBSERVED'}}})
Save (Join-Path $ReviewRoot 'configuration-source-pins.json') $external
[pscustomobject]@{requirement_rows=$rows.Count;metadata_missing=@($rows | Where-Object {$_.presence -ne 'METADATA_PRESENT_ONLY'} | Select-Object name,presence);import_references=$importRows.Count;source_python_files=616;runtime_validation='NOT_VERIFIED'} | ConvertTo-Json -Depth 7
