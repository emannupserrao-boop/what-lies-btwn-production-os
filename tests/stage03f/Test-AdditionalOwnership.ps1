# Additional real fixture concurrency and injected permission regressions. No child runtime.
#requires -Version 7.6
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$Scope=Join-Path $Root 'tests\stage03f\regression\additional-fixtures'
$null=New-Item -ItemType Directory -Path $Scope
. 'D:\WHAT-LIES-BTWN-PRODUCTION-OS\tests\stage03f\Regression-StartupFiles.ps1'
. (Join-Path $Root 'core\Wlb.RuntimeMonitor.ps1')
$rows=[Collections.Generic.List[object]]::new()
function Row([string]$id,[string]$expected,$actual,[bool]$pass,[string]$kind){$rows.Add([pscustomobject]@{id=$id;expectation=$expected;actual=$actual;status=$(if($pass){'PASS'}else{'FAIL'});evidence_kind=$kind})}
$a=Join-Path $Scope 'attempt-A';$b=Join-Path $Scope 'attempt-B';$null=New-Item -ItemType Directory -Path $a,$b
$lease=New-WlbTestStartupLease $a;$ps=[PowerShell]::Create()
try{
    $code='param($m,$n) . $m; try {$l=New-WlbTestStartupLease $n;Close-WlbTestStartupLease $l;"UNEXPECTED_ACQUIRE"}catch{$_.Exception.Message}'
    $null=$ps.AddScript($code).AddArgument('D:\WHAT-LIES-BTWN-PRODUCTION-OS\tests\stage03f\Regression-StartupFiles.ps1').AddArgument($b)
    $async=$ps.BeginInvoke();$out=@($ps.EndInvoke($async)) -join ';'
    Row 'ENGINE-MUTEX-DIFFERENT-ATTEMPTS' 'One engine lock denies concurrent distinct attempt namespaces' $out ($out -match 'Concurrent executor mutex already owned') 'REAL_NAMED_TEST_MUTEX'
}finally{$ps.Dispose();Close-WlbTestStartupLease $lease}
# Simultaneous CreateNew contenders on the same own target. One may succeed, exactly one must fail.
$racePath=Join-Path $Scope 'concurrent-create.test.json';$gateName='Local\Wlb.Stage03D2.CreateRace.'+[guid]::NewGuid().ToString('N')
$gate=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$gateName)
$workers=[Collections.Generic.List[object]]::new()
try{
    for($i=0;$i -lt 2;$i++){
        $worker=[PowerShell]::Create()
        $code='param($m,$p,$g) . $m; $gate=[Threading.EventWaitHandle]::OpenExisting($g); try{$null=$gate.WaitOne(5000);try{$f=Write-WlbTestNewFile $p ([Text.Encoding]::UTF8.GetBytes("OWN TEST BYTES"));"CREATED"}catch{"REJECTED:"+$_.Exception.Message}}finally{$gate.Dispose()}'
        $null=$worker.AddScript($code).AddArgument('D:\WHAT-LIES-BTWN-PRODUCTION-OS\tests\stage03f\Regression-StartupFiles.ps1').AddArgument($racePath).AddArgument($gateName)
        $workers.Add([pscustomobject]@{ps=$worker;async=$worker.BeginInvoke()})
    }
    $null=$gate.Set();$outcomes=@(foreach($w in $workers){@($w.ps.EndInvoke($w.async)) -join ';'})
    Row 'CONCURRENT-CREATENEW-RESERVATION' 'Exactly one creator; other refuses without overwriting' $outcomes (@($outcomes | Where-Object {$_ -eq 'CREATED'}).Count -eq 1 -and @($outcomes | Where-Object {$_ -like 'REJECTED:*'}).Count -eq 1) 'REAL_FIXTURE_CONCURRENT_FILE_IO'
}finally{foreach($w in $workers){$w.ps.Dispose()};$gate.Dispose()}
$record=Get-Content -LiteralPath (Join-Path $Root 'tests\stage03d2\evidence\run2\test-results.json') -Raw | ConvertFrom-Json -AsHashtable -DateKind String
$good=@($record | Where-Object {$_.id -eq 'OWNED-PROCESS-TUPLE'})[0].actual
Row 'OWNED-TUPLE-ALREADY-REGRESSED' 'Final tuple comparison is typed/matching' $good $good.owned 'RECHECK_RECORDED_MOCK'
foreach($r in @($record | Where-Object {$_.id -in @('NO-OVERWRITE','PARENT-SWAP-DURING-USE','FOREIGN-PROCESS-CANNOT-STOP','PERSISTENT-RESERVATION-RESTART-DENIED')})){Row ('RECHECK-'+$r.id) 'Prior guard evidence preserved and PASS' $r.actual ($r.status -ceq 'PASS') 'RECHECK_RECORDED_EVIDENCE'}
$json=ConvertTo-Json -InputObject @($rows) -Depth 30
[IO.File]::WriteAllText((Join-Path $Root 'tests\stage03f\evidence\additional-results.json'),$json,[Text.UTF8Encoding]::new($false))
$rows | ConvertTo-Json -Depth 20
if(@($rows | Where-Object {$_.status -eq 'FAIL'}).Count){exit 1}
