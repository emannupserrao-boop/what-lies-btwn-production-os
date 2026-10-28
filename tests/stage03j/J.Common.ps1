#requires -Version 7.6
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$JRoot='D:\WHAT-LIES-BTWN-PRODUCTION-OS';$JEvidence=Join-Path $JRoot 'tests\stage03j\evidence'
function Save-JNew([string]$Name,$Value,[switch]$Text){
 $path=[IO.Path]::GetFullPath((Join-Path $JEvidence $Name));if(-not $path.StartsWith($JEvidence+'\',[StringComparison]::OrdinalIgnoreCase) -or $Name -match ':|(^|[\\/])\.\.([\\/]|$)'){throw 'StageJ evidence scope'}
 $content=if($Text){[string]$Value}else{ConvertTo-Json -InputObject $Value -Depth 90}
 $s=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write([Text.UTF8Encoding]::new($false).GetBytes($content));$s.Flush($true)}finally{$s.Dispose()}
}
function Read-JJson([string]$Path){return ,(Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
function Copy-JObject($Value){return ,(ConvertTo-Json -InputObject $Value -Depth 80|ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
