#requires -Version 7.6
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$IRoot='D:\WHAT-LIES-BTWN-PRODUCTION-OS';$IEvidence=Join-Path $IRoot 'tests\stage03i\evidence'
function Save-INew([string]$Name,$Value,[switch]$Text){
 $path=[IO.Path]::GetFullPath((Join-Path $IEvidence $Name));if(-not $path.StartsWith($IEvidence+'\',[StringComparison]::OrdinalIgnoreCase) -or $Name -match ':|(^|[\\/])\.\.([\\/]|$)'){throw 'Evidence scope violation'}
 $content=if($Text){[string]$Value}else{ConvertTo-Json -InputObject $Value -Depth 80}
 $s=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write([Text.UTF8Encoding]::new($false).GetBytes($content));$s.Flush($true)}finally{$s.Dispose()}
}
function Copy-IObject($v){return ,(ConvertTo-Json -InputObject $v -Depth 60|ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
function Read-IJson([string]$p){return ,(Get-Content -LiteralPath $p -Raw|ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
