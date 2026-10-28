# Focused checks after the pinned-read/engine-mutex changes. Own files only.
#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
. 'D:\WHAT-LIES-BTWN-PRODUCTION-OS\tests\stage03f\Regression-StartupFiles.ps1'
$folder=Join-Path $Root 'tests\stage03f\regression\final-file-fixtures'
$null=New-Item -ItemType Directory -Path $folder
$rows=[Collections.Generic.List[object]]::new()
function Add([string]$id,$actual,[bool]$pass){$rows.Add([pscustomobject]@{id=$id;expectation='Pinned identity/path/bytes or exclusive reservation guard';actual=$actual;status=$(if($pass){'PASS'}else{'FAIL'});evidence_kind='REAL_FIXTURE_FILE_IO_CURRENT_SOURCE'})}
$bytes=[Text.Encoding]::UTF8.GetBytes('FINAL OWN FIXTURE')
$path=Join-Path $folder 'pinned.bin';$fp=Write-WlbTestNewFile $path $bytes;$read=Read-WlbTestPinnedFile $fp
Add 'FINAL-PINNED-READ-STABLE' $read.sha256 ($read.sha256 -ceq $fp.sha256)
$stored=Join-Path $folder 'pinned-original-retained.bin';$null=Assert-WlbStartupTestPath $stored
[IO.File]::Move($path,$stored);$new=Write-WlbTestNewFile $path $bytes
try{$null=Read-WlbTestPinnedFile $fp;Add 'FINAL-REPLACEMENT-REJECTED' 'UNEXPECTED_READ' $false}catch{Add 'FINAL-REPLACEMENT-REJECTED' $_.Exception.Message ($_.Exception.Message -match 'replaced since fingerprint')}
[IO.File]::WriteAllText($path,'MODIFIED OWN BYTES')
try{$null=Read-WlbTestPinnedFile $new;Add 'FINAL-BYTES-REJECTED' 'UNEXPECTED_READ' $false}catch{Add 'FINAL-BYTES-REJECTED' $_.Exception.Message ($_.Exception.Message -match 'Pinned bytes changed')}
try{$null=Write-WlbTestNewFile $path $bytes;Add 'FINAL-NO-OVERWRITE' 'UNEXPECTED_WRITE' $false}catch{Add 'FINAL-NO-OVERWRITE' $_.Exception.Message ($_.Exception.Message -match 'already exists|exists')}
$leaseFolder=Join-Path $folder 'lease';$null=New-Item -ItemType Directory -Path $leaseFolder
$l=New-WlbTestStartupLease $leaseFolder;Close-WlbTestStartupLease $l
try{$again=New-WlbTestStartupLease $leaseFolder;Close-WlbTestStartupLease $again;Add 'FINAL-RESERVATION-RECOVERY' 'UNEXPECTED_RESTART' $false}catch{Add 'FINAL-RESERVATION-RECOVERY' $_.Exception.Message ($_.Exception.Message -match 'already exists|exists')}
$json=ConvertTo-Json -InputObject @($rows) -Depth 15
[IO.File]::WriteAllText((Join-Path $Root 'tests\stage03f\evidence\final-file-results.json'),$json,[Text.UTF8Encoding]::new($false))
$rows | ConvertTo-Json -Depth 15
if(@($rows | Where-Object {$_.status -eq 'FAIL'}).Count){exit 1}
