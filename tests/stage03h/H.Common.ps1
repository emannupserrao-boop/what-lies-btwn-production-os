#requires -Version 7.6
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$HRoot='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$HEvidence=Join-Path $HRoot 'tests\stage03h\evidence'
function Save-HNew([string]$Name,$Value,[switch]$Text){
 $path=[IO.Path]::GetFullPath((Join-Path $HEvidence $Name))
 if(-not $path.StartsWith($HEvidence+'\',[StringComparison]::OrdinalIgnoreCase) -or $Name -match ':|(^|[\\/])\.\.([\\/]|$)'){throw 'Evidence scope violation'}
 $content=if($Text){[string]$Value}else{ConvertTo-Json -InputObject $Value -Depth 70}
 $s=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$s.Write([Text.UTF8Encoding]::new($false).GetBytes($content));$s.Flush($true)}finally{$s.Dispose()}
}
function Read-HJson([string]$Path){return ,(Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
function Copy-HObject($Value){return ,(ConvertTo-Json -InputObject $Value -Depth 70|ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
