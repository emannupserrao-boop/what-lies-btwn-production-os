#requires -Version 7.4
param(
 [string]$SourcePath='D:\WHAT-LIES-BTWN-PRODUCTION-OS\core\Wlb.WorkerProcess.ps1',
 [Parameter(Mandatory)][string]$ResultPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$checks=[Collections.Generic.List[object]]::new()
function Check([string]$Id,[scriptblock]$Body){try{$r=& $Body;if($r -isnot [bool] -or -not $r){throw 'ASSERTION_FALSE'};$checks.Add([ordered]@{id=$Id;status='PASS'})}catch{$checks.Add([ordered]@{id=$Id;status='FAIL';detail=$_.Exception.Message})}}
function Replace-One([string]$Text,[string]$Before,[string]$After){if(($Text.Split(@($Before),[StringSplitOptions]::None).Count-1) -ne 1){throw ('ISOLATION_REPLACEMENT_NOT_UNIQUE:'+ $Before)};$Text.Replace($Before,$After)}
$errs=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$null,[ref]$errs)
if($errs.Count){throw 'PRODUCTION_POWERSHELL_SYNTAX_INVALID'}
$csNodes=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value.StartsWith('using System;')},$true))
if($csNodes.Count -ne 1){throw 'EMBEDDED_SOURCE_AMBIGUOUS'}
$cs=$csNodes[0].Value
if($null -ne ('WlbOwnedJ.Lifecycle' -as [type])){throw 'FRESH_TEST_HOST_REQUIRED'}
# Compile the exact production C# without calling its lifecycle or any native function.
Add-Type -TypeDefinition $cs
Check 'production-native-source-compiles-without-invocation' { $null -ne ('WlbOwnedJ.Lifecycle' -as [type]) }
# Every behavioral test uses an isolated in-memory namespace. Production code has no test switch.
$fixture=Replace-One $cs 'namespace WlbOwnedJ {' 'namespace WlbOwnedJRecoveryFixture {'
$createDecl='[DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] internal static extern bool CreateProcessW(string app,StringBuilder command,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr environment,string directory,ref StartupInfo startup,out ProcessInfo info);'
$fixture=Replace-One $fixture $createDecl 'internal static bool CreateProcessW(string app,StringBuilder command,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr environment,string directory,ref StartupInfo startup,out ProcessInfo info){info=default(ProcessInfo);Fixture.Creates++;Fixture.Events.Enqueue("CREATE_INTERCEPTED");throw new InvalidOperationException("TEST_CREATE_INTERCEPTED");}'
$readDecl='[DllImport("psapi.dll",SetLastError=true)] [return: MarshalAs(UnmanagedType.Bool)] static extern bool GetPerformanceInfo(out Performance p,uint size);'
$fixture=Replace-One $fixture $readDecl 'static bool GetPerformanceInfo(out Performance p,uint size){return Fixture.Read(out p);}'
$stopDecl='[DllImport("kernel32.dll",SetLastError=true)] internal static extern bool TerminateProcess(SafeProcessHandle process,uint code);'
$fixture=Replace-One $fixture $stopDecl 'internal static bool TerminateProcess(SafeProcessHandle process,uint code){throw new InvalidOperationException("TEST_TERMINATION_FORBIDDEN");}'
$fixture=Replace-One $fixture 'public static string Hash(string p){using(var s=File.OpenRead(p))return Convert.ToHexString(SHA256.HashData(s)).ToLowerInvariant();}' 'public static string Hash(string p){return Fixture.FixedHash(p);}'
$fixture=Replace-One $fixture 'Directory.CreateDirectory(scratch);' 'Fixture.ScratchPreparations++;'
$fixture+=@'
namespace WlbOwnedJRecoveryFixture {
 public static class Fixture {
  public const string HelperHash="b89d0bcbae989d7d15b98539310fc227211897710d0d9277e2504219ab3d502e";
  public static ulong AvailablePages,PhysicalPages,CommitPages,LimitPages,PageSize;
  public static bool Available,ThrowOnRead;public static int Creates,Reads,ScratchPreparations,ActiveReads,MaxActiveReads;
  public static System.Collections.Concurrent.ConcurrentQueue<string> Events=new System.Collections.Concurrent.ConcurrentQueue<string>();
  public static void Reset(){AvailablePages=8UL*1024*1024*1024;PhysicalPages=32UL*1024*1024*1024;CommitPages=20UL*1024*1024*1024;LimitPages=30UL*1024*1024*1024;PageSize=1;Available=true;ThrowOnRead=false;Creates=Reads=ScratchPreparations=ActiveReads=MaxActiveReads=0;Events=new System.Collections.Concurrent.ConcurrentQueue<string>();}
  public static string FixedHash(string path){if(path==Lifecycle.Executable)return Lifecycle.ExecutableHash;if(path==Lifecycle.Helper)return HelperHash;throw new InvalidOperationException("TEST_UNEXPECTED_HASH_PATH");}
  internal static bool Read(out Native.Performance p){
   p=default(Native.Performance);int active=System.Threading.Interlocked.Increment(ref ActiveReads);if(active>MaxActiveReads)MaxActiveReads=active;
   try{System.Threading.Interlocked.Increment(ref Reads);Events.Enqueue("READ_MEMORY");System.Threading.Thread.Sleep(10);if(ThrowOnRead)throw new InvalidOperationException("TEST_PROVIDER_EXCEPTION");if(!Available)return false;p.PhysicalAvailable=new UIntPtr(AvailablePages);p.PhysicalTotal=new UIntPtr(PhysicalPages);p.CommitTotal=new UIntPtr(CommitPages);p.CommitLimit=new UIntPtr(LimitPages);p.PageSize=new UIntPtr(PageSize);return true;}
   finally{System.Threading.Interlocked.Decrement(ref ActiveReads);}
  }
  public static string Call(string attempt){try{Lifecycle.Start(attempt,new string('a',64),"NORMAL_EXIT",HelperHash,"WLB_STAGE03J_"+Guid.Parse(attempt).ToString("N"),Guid.NewGuid().ToString("D"));return "UNEXPECTED_LEASE";}catch(Exception e){return e.Message;}}
  public static string[] ConcurrentCalls(int count,bool same){string attempt=Guid.NewGuid().ToString("D");var tasks=new Task<string>[count];for(int i=0;i<count;i++){string id=same?attempt:Guid.NewGuid().ToString("D");tasks[i]=Task.Run(()=>Call(id));}Task.WaitAll(tasks);var results=new string[count];for(int i=0;i<count;i++)results[i]=tasks[i].Result;return results;}
 }
}
'@
if($fixture.Contains('extern bool CreateProcessW') -or $fixture.Contains('extern bool TerminateProcess')){throw 'UNSAFE_FIXTURE_PROCESS_PRIMITIVE'}
Add-Type -TypeDefinition $fixture
$fixtureHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($fixture))).ToLowerInvariant()
function Reset-Fixture { [WlbOwnedJRecoveryFixture.Fixture]::Reset() }
function Call-Fixture { [WlbOwnedJRecoveryFixture.Fixture]::Call([guid]::NewGuid().ToString('D')) }
function Refused([string]$Message,[string]$Reason){$Message.Contains('STAGE03J_RESOURCE_BLOCKED:') -and $Message.Contains($Reason) -and [WlbOwnedJRecoveryFixture.Fixture]::Creates -eq 0}
Check 'direct-call-exact8-and10-reaches-interceptor-only' {Reset-Fixture;$m=Call-Fixture;$m -eq 'TEST_CREATE_INTERCEPTED' -and [WlbOwnedJRecoveryFixture.Fixture]::Creates -eq 1 -and ([WlbOwnedJRecoveryFixture.Fixture]::Events.ToArray() -join ',') -eq 'READ_MEMORY,CREATE_INTERCEPTED'}
Check 'direct-call-ram-one-byte-below-refused' {Reset-Fixture;[WlbOwnedJRecoveryFixture.Fixture]::AvailablePages--;Refused (Call-Fixture) 'AVAILABLE_RAM_BELOW_8_GIB'}
Check 'direct-call-headroom-one-byte-below-refused' {Reset-Fixture;[WlbOwnedJRecoveryFixture.Fixture]::LimitPages--;Refused (Call-Fixture) 'COMMIT_HEADROOM_BELOW_10_GIB'}
Check 'direct-call-native-provider-unavailable-refused' {Reset-Fixture;[WlbOwnedJRecoveryFixture.Fixture]::Available=$false;Refused (Call-Fixture) 'STAGE03J_RESOURCE_BLOCKED'}
Check 'direct-call-native-provider-exception-refused' {Reset-Fixture;[WlbOwnedJRecoveryFixture.Fixture]::ThrowOnRead=$true;Refused (Call-Fixture) 'TEST_PROVIDER_EXCEPTION'}
Check 'direct-call-counter-conversion-overflow-refused' {Reset-Fixture;[WlbOwnedJRecoveryFixture.Fixture]::AvailablePages=[ulong]::MaxValue;Refused (Call-Fixture) 'STAGE03J_RESOURCE_BLOCKED'}
Check 'direct-call-page-multiplication-overflow-refused' {Reset-Fixture;[WlbOwnedJRecoveryFixture.Fixture]::PhysicalPages=[long]::MaxValue;[WlbOwnedJRecoveryFixture.Fixture]::PageSize=4096;Refused (Call-Fixture) 'STAGE03J_RESOURCE_BLOCKED'}
Check 'direct-call-zero-page-size-refused' {Reset-Fixture;[WlbOwnedJRecoveryFixture.Fixture]::PageSize=0;Refused (Call-Fixture) 'HOST_READING_INCONSISTENT'}
Check 'direct-call-available-exceeds-total-refused' {Reset-Fixture;[WlbOwnedJRecoveryFixture.Fixture]::PhysicalPages=1;Refused (Call-Fixture) 'HOST_READING_INCONSISTENT'}
Check 'direct-call-commit-exceeds-limit-refused' {Reset-Fixture;[WlbOwnedJRecoveryFixture.Fixture]::CommitPages=[WlbOwnedJRecoveryFixture.Fixture]::LimitPages+1;Refused (Call-Fixture) 'HOST_READING_INCONSISTENT'}
Check 'direct-call-realistic4096-page-unit-conversion' {Reset-Fixture;[WlbOwnedJRecoveryFixture.Fixture]::AvailablePages=8GB/4096;[WlbOwnedJRecoveryFixture.Fixture]::PhysicalPages=32GB/4096;[WlbOwnedJRecoveryFixture.Fixture]::CommitPages=20GB/4096;[WlbOwnedJRecoveryFixture.Fixture]::LimitPages=30GB/4096;[WlbOwnedJRecoveryFixture.Fixture]::PageSize=4096;(Call-Fixture) -eq 'TEST_CREATE_INTERCEPTED' -and [WlbOwnedJRecoveryFixture.Fixture]::Creates -eq 1}
Check 'direct-refusal-consumes-attempt-even-after-resource-recovery' {Reset-Fixture;$id=[guid]::NewGuid().ToString('D');[WlbOwnedJRecoveryFixture.Fixture]::AvailablePages=1;$first=[WlbOwnedJRecoveryFixture.Fixture]::Call($id);[WlbOwnedJRecoveryFixture.Fixture]::AvailablePages=8GB;$again=[WlbOwnedJRecoveryFixture.Fixture]::Call($id);(Refused $first 'AVAILABLE_RAM_BELOW_8_GIB') -and $again -eq 'ATTEMPT_RESTART_OR_PROCESS_BOUND_DENIED' -and [WlbOwnedJRecoveryFixture.Fixture]::Reads -eq 1}
Check 'creation-failure-also-consumes-attempt' {Reset-Fixture;$id=[guid]::NewGuid().ToString('D');$first=[WlbOwnedJRecoveryFixture.Fixture]::Call($id);$again=[WlbOwnedJRecoveryFixture.Fixture]::Call($id);$first -eq 'TEST_CREATE_INTERCEPTED' -and $again -eq 'ATTEMPT_RESTART_OR_PROCESS_BOUND_DENIED' -and [WlbOwnedJRecoveryFixture.Fixture]::Creates -eq 1}
Check 'concurrent-direct-calls-serialize-fresh-read-and-create' {Reset-Fixture;$results=[WlbOwnedJRecoveryFixture.Fixture]::ConcurrentCalls(4,$false);@($results|Where-Object {$_ -eq 'TEST_CREATE_INTERCEPTED'}).Count -eq 4 -and [WlbOwnedJRecoveryFixture.Fixture]::Reads -eq 4 -and [WlbOwnedJRecoveryFixture.Fixture]::MaxActiveReads -eq 1 -and ([WlbOwnedJRecoveryFixture.Fixture]::Events.ToArray() -join ',') -eq ((@('READ_MEMORY,CREATE_INTERCEPTED')*4)-join ',')}
Check 'same-attempt-concurrent-call-cannot-double-create' {Reset-Fixture;$results=[WlbOwnedJRecoveryFixture.Fixture]::ConcurrentCalls(2,$true);@($results|Where-Object {$_ -eq 'TEST_CREATE_INTERCEPTED'}).Count -eq 1 -and @($results|Where-Object {$_ -eq 'ATTEMPT_RESTART_OR_PROCESS_BOUND_DENIED'}).Count -eq 1 -and [WlbOwnedJRecoveryFixture.Fixture]::Creates -eq 1}
# Load pure assertion contracts; extract only the two wrapper functions from the source AST.
. (Join-Path $root 'core\Wlb.Common.ps1')
$ready=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-WlbJHelperResourceReadiness'},$true))
$wrapper=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Start-WlbJOwnedHelper'},$true))
if($ready.Count -ne 1 -or $wrapper.Count -ne 1){throw 'WRAPPER_SOURCE_AMBIGUOUS'}
. ([scriptblock]::Create($ready[0].Extent.Text))
$wrapperText=$wrapper[0].Extent.Text.Replace('function Start-WlbJOwnedHelper','function Start-RecoveryFixtureHelper').Replace('[WlbOwnedJ.Lifecycle]','[WlbOwnedJRecoveryFixture.Lifecycle]')
. ([scriptblock]::Create($wrapperText))
function Get-WlbPassiveHostMemory {if($script:WrapperThrows){throw 'TEST_WRAPPER_PROVIDER_EXCEPTION'};return $script:WrapperReading}
function New-WrapperReading { @{status='AVAILABLE_GLOBAL';available_ram_bytes=[long]8GB;commit_total_bytes=[long]20GB;commit_limit_bytes=[long]30GB;commit_headroom_bytes=[long]10GB} }
function New-WrapperAttempt { $id=[guid]::NewGuid().ToString('D');[pscustomobject]@{scope='STAGE03J_OWNED_HELPER_TEST_ONLY';id=$id;nonce=('a'*64);pipe_name=('WLB_STAGE03J_'+([guid]$id).ToString('N'));session_id=[guid]::NewGuid().ToString('D');helper_sha256=[WlbOwnedJRecoveryFixture.Fixture]::HelperHash;created=$false;terminal=$false;reason=$null;lease=$null} }
$script:WrapperThrows=$false
Check 'high-wrapper-low-native-refuses-with-correct-attempt-state' {Reset-Fixture;$script:WrapperReading=New-WrapperReading;[WlbOwnedJRecoveryFixture.Fixture]::AvailablePages=1;$a=New-WrapperAttempt;try{$null=Start-RecoveryFixtureHelper $a NORMAL_EXIT;return $false}catch{$message=$_.Exception.Message};(Refused $message 'AVAILABLE_RAM_BELOW_8_GIB') -and $a.terminal -and -not $a.created -and $null -eq $a.lease}
Check 'wrapper-low-refusal-and-retry-never-call-native' {Reset-Fixture;$script:WrapperReading=New-WrapperReading;$script:WrapperReading.available_ram_bytes=1;$a=New-WrapperAttempt;try{$null=Start-RecoveryFixtureHelper $a NORMAL_EXIT;return $false}catch{};$script:WrapperReading=New-WrapperReading;try{$null=Start-RecoveryFixtureHelper $a NORMAL_EXIT;return $false}catch{$retry=$_.Exception.Message};$retry.Contains('Attempt restart/foreign scope denied') -and $a.terminal -and -not $a.created -and $null -eq $a.lease -and [WlbOwnedJRecoveryFixture.Fixture]::Reads -eq 0 -and [WlbOwnedJRecoveryFixture.Fixture]::Creates -eq 0}
Check 'wrapper-unexpected-provider-exception-is-terminal' {Reset-Fixture;$script:WrapperThrows=$true;$a=New-WrapperAttempt;try{try{$null=Start-RecoveryFixtureHelper $a NORMAL_EXIT;return $false}catch{$message=$_.Exception.Message};$message -eq 'TEST_WRAPPER_PROVIDER_EXCEPTION' -and $a.terminal -and -not $a.created -and $null -eq $a.lease -and [WlbOwnedJRecoveryFixture.Fixture]::Reads -eq 0}finally{$script:WrapperThrows=$false}}
Check 'wrapper-malformed-string-counter-refused' {$r=New-WrapperReading;$r.available_ram_bytes='8589934592';-not (Test-WlbJHelperResourceReadiness $r).allowed_to_create_owned_test_helper}
Check 'wrapper-inconsistent-headroom-refused' {$r=New-WrapperReading;$r.commit_headroom_bytes++;-not (Test-WlbJHelperResourceReadiness $r).allowed_to_create_owned_test_helper}
$summary=[ordered]@{schema='wlb-stage03j-central-guard-no-create-tests/0.1';utc=[DateTime]::UtcNow.ToString('o');source_sha256=(Get-FileHash -LiteralPath $SourcePath).Hash.ToLowerInvariant();test_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();isolated_fixture_sha256=$fixtureHash;production_type_compiled_only=$true;behavioral_native_creation_replaced_with_throwing_interceptor=$true;native_termination_replaced_with_throw=$true;real_helpers_created=0;production_start_invoked=$false;pass=@($checks|Where-Object status -eq PASS).Count;fail=@($checks|Where-Object status -eq FAIL).Count;checks=@($checks)}
$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($summary|ConvertTo-Json -Depth 8)+"`r`n")
$stream=[IO.File]::Open($ResultPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($bytes);$stream.Flush($true)}finally{$stream.Dispose()}
$summary|ConvertTo-Json -Depth 8
if($summary.fail){exit 1}
