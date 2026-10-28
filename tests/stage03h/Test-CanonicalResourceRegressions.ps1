#requires -Version 7.6
# Static and simulated control tests plus finite read-only observations. No listener/start/kill.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS';$Evidence=Join-Path $Root 'tests\stage03h\evidence'
. (Join-Path $Root 'core\Wlb.RuntimeMonitor.ps1')
function Clone($v){return ,(ConvertTo-Json -InputObject $v -Depth 70 | ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
function Json([string]$p){return ,(Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
function SaveNew([string]$name,$v){$p=Join-Path $Evidence $name;$s=[IO.File]::Open($p,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write([Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject $v -Depth 60)));$s.Flush($true)}finally{$s.Dispose()}}
$results=[Collections.Generic.List[object]]::new()
function Row([string]$id,$actual,[bool]$ok,[string]$kind='SIMULATED_COUNTERS_NO_RUNTIME'){$results.Add([ordered]@{id=$id;status=$(if($ok){'PASS'}else{'FAIL'});actual=$actual;evidence_kind=$kind})}
function Reject([string]$id,[scriptblock]$action,[string]$pattern='BLOCKED:'){try{$out=@(& $action);Row $id 'UNEXPECTED_ACCEPT' $false}catch{Row $id $_.Exception.Message ($_.Exception.Message -match $pattern) 'EXECUTED_STATIC_CONTRACT'}}
$policy=Read-WlbJson (Join-Path $Root 'policy\startup-policy.json')
$observed=Get-WlbPassiveProcessObservation $PID
Row 'REAL-SELF-PROCESS-READ' $observed ($observed.status -ceq 'AVAILABLE_PROCESS_ATTRIBUTED' -and $observed.process_id -eq $PID -and $observed.private_bytes -gt 0 -and -not $observed.identity_match_is_launch_ownership) 'REAL_PASSIVE_OWN_OBSERVER_NOT_COMFY'
$absent=Get-WlbPassiveProcessObservation 0
Row 'INVALID-PID-UNAVAILABLE' $absent ($absent.status -ceq 'UNAVAILABLE') 'REAL_READ_INTERFACE_NO_PROCESS_CHANGE'
$clock1=Get-WlbPassiveClock;$clock2=Get-WlbPassiveClock
Row 'REAL-MONOTONIC-CLOCK' @($clock1,$clock2) ($clock2.monotonic_ms -ge $clock1.monotonic_ms -and $clock1.clock_id -ceq $clock2.clock_id) 'REAL_STOPWATCH_NO_RUNTIME'
$native=Get-WlbPassivePortObservation
$cim=@(Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetTCPConnection -Filter 'LocalPort=8189' -OperationTimeoutSec 2 | Where-Object {$_.State -eq 2})
Row 'REAL-PORT-NATIVE-CIM-CROSSCHECK' ([ordered]@{native=$native;cim_listener_count=$cim.Count;atomic=$false}) ($native.known -and $native.listeners.Count -eq $cim.Count) 'REAL_PASSIVE_TWO_NONATOMIC_INTERFACES'
Initialize-WlbPassiveTcpReader
$v4=[byte[]]::new(28);[BitConverter]::GetBytes([uint32]1).CopyTo($v4,0);[BitConverter]::GetBytes([uint32]2).CopyTo($v4,4);([byte[]]@(127,0,0,1)).CopyTo($v4,8);[BitConverter]::GetBytes([uint32]0xFD1F).CopyTo($v4,12);[BitConverter]::GetBytes([uint32]424242).CopyTo($v4,24)
$decoded=@([WlbPassive.Tcp]::Decode($v4,2))
Row 'MOCK-TCP4-OCCUPIED-DECODE' $decoded ($decoded.Count -eq 1 -and $decoded[0].Port -eq 8189 -and $decoded[0].Address -ceq '127.0.0.1' -and $decoded[0].ProcessId -eq 424242) 'SYNTHETIC_TCP_TABLE_NO_LISTENER'
$v6=[byte[]]::new(60);[BitConverter]::GetBytes([uint32]1).CopyTo($v6,0);$v6[19]=1;[BitConverter]::GetBytes([uint32]0xFD1F).CopyTo($v6,24);[BitConverter]::GetBytes([uint32]2).CopyTo($v6,52);[BitConverter]::GetBytes([uint32]424242).CopyTo($v6,56)
$decoded=@([WlbPassive.Tcp]::Decode($v6,23))
Row 'MOCK-TCP6-OCCUPIED-DECODE' $decoded ($decoded.Count -eq 1 -and $decoded[0].Address -ceq '::1') 'SYNTHETIC_TCP_TABLE_NO_LISTENER'
Reject 'MOCK-TCP-TRUNCATED' {[WlbPassive.Tcp]::Decode([byte[]]@(1,0,0,0),2)} 'Invalid TCP table'
$process=[ordered]@{status='AVAILABLE_PROCESS_ATTRIBUTED';requested_pid=424242;process_id=424242;creation_time_utc='2099-01-01T00:00:00.0000000Z';image_path='D:\SIMULATED\python.exe';image_sha256=('1'*64);private_bytes=[long](1GB);cpu_total_100ns=[long]1000000;captured_ms=[long]0}
$base=[ordered]@{schema_version='wlb-passive-telemetry/0.1';source='PASSIVE_LOCAL_READ_ONLY';clock_id='SIMULATED_CLOCK_NOT_LIVE';start_ms=[long]0;end_ms=[long]10;collection_ms=[long]10;host=@{status='AVAILABLE_GLOBAL';available_ram_bytes=[long](10GB);commit_total_bytes=[long](16GB);commit_limit_bytes=[long](32GB);commit_headroom_bytes=[long](16GB)};processes=@($process);gpu=@{status='AVAILABLE_GLOBAL';global=@{used_bytes=[long](1GB);free_bytes=[long](15GB);total_bytes=[long](16GB)};rtx_process_attribution='VERIFIED_RTX_PROCESS_RESIDENCY'};port=@{known=$true;occupied=$false};concurrency=@{known=$true;potential_heavy_processes=@();exclusivity_proven=$true};disk=@{known=$true;aggregate_bytes=[long]0};source_generation_freshness='VERIFIED'}
$sample=Clone $base;$sample.start_ms=[long]100;$sample.end_ms=[long]110
$out=Test-WlbPassiveResourcePreflight $policy $base $sample $process 200 1000
Row 'POSITIVE-MOCK-PREFLIGHT-NO-AUTHORITY' $out ($out.state -ceq 'FEASIBILITY_THRESHOLDS_ONLY' -and -not $out.authorized_to_execute)
$exact=Clone $sample;$exact.host.available_ram_bytes=[long](8GB);$exact.host.commit_total_bytes=[long](20GB);$exact.host.commit_limit_bytes=[long](30GB);$exact.host.commit_headroom_bytes=[long](10GB);$exact.processes[0].private_bytes=[long](4GB);$exact.gpu.global.used_bytes=[long](3GB);$exact.gpu.global.free_bytes=[long](13GB);$exact.disk.aggregate_bytes=[long](256MB)
$out=Test-WlbPassiveResourcePreflight $policy $base $exact $process 200 1000;Row 'EXACT-THRESHOLD-BOUNDARIES-NO-CAP-INCREASE' $out ($out.state -ceq 'FEASIBILITY_THRESHOLDS_ONLY' -and -not $out.authorized_to_execute)
$cases=[ordered]@{
 'RAM-BELOW-8'={param($s) $s.host.available_ram_bytes=[long](8GB-1)}
 'COMMIT-HEADROOM-BELOW-10'={param($s) $s.host.commit_limit_bytes=[long](26GB-1);$s.host.commit_headroom_bytes=[long](10GB-1)}
 'COMMIT-DELTA-OVER-4'={param($s) $s.host.commit_total_bytes=[long](20GB+1);$s.host.commit_headroom_bytes=$s.host.commit_limit_bytes-$s.host.commit_total_bytes}
 'PRIVATE-OVER-4'={param($s) $s.processes[0].private_bytes=[long](4GB+1)}
 'VRAM-DELTA-OVER-2'={param($s) $s.gpu.global.used_bytes=[long](3GB+1);$s.gpu.global.free_bytes=$s.gpu.global.total_bytes-$s.gpu.global.used_bytes}
 'DISK-OVER-256'={param($s) $s.disk.aggregate_bytes=[long](256MB+1)}
 'MEMORY-UNAVAILABLE'={param($s) $s.host.status='UNAVAILABLE'}
 'MEMORY-WRONG-TYPE'={param($s) $s.host.available_ram_bytes='10737418240'}
 'MEMORY-INCONSISTENT'={param($s) $s.host.commit_headroom_bytes++}
 'GPU-UNAVAILABLE'={param($s) $s.gpu.status='UNAVAILABLE'}
 'GPU-WRONG-TYPE'={param($s) $s.gpu.global.used_bytes='1'}
 'GPU-NEGATIVE'={param($s) $s.gpu.global.used_bytes=[long]-1}
 'GPU-INCONSISTENT'={param($s) $s.gpu.global.free_bytes=[long](16GB)}
 'GPU-ATTRIBUTION-IMPOSSIBLE'={param($s) $s.gpu.rtx_process_attribution='NOT_VERIFIED'}
 'GPU-FOREIGN-ACTORS'={param($s) $s.concurrency.exclusivity_proven=$false}
 'GPU-EXCLUSIVITY-WRONG-TYPE'={param($s) $s.concurrency.exclusivity_proven='true'}
 'HEAVY-PROCESS'={param($s) $s.concurrency.potential_heavy_processes=@(@{process_id=111;name='SIMULATED_RENDER'})}
 'CONCURRENCY-QUERY-FAILED'={param($s) $s.concurrency.known=$false}
 'PORT-OCCUPIED'={param($s) $s.port.occupied=$true}
 'PORT-UNKNOWN'={param($s) $s.port.known=$false}
 'PORT-WRONG-TYPE'={param($s) $s.port.occupied='false'}
 'DISK-UNKNOWN'={param($s) $s.disk.known=$false}
 'DISK-NEGATIVE'={param($s) $s.disk.aggregate_bytes=[long]-1}
 'PID-RECYCLED'={param($s) $s.processes[0].creation_time_utc='2099-01-01T00:00:01.0000000Z'}
 'PID-FALSE'={param($s) $s.processes[0].process_id=424243}
 'EXECUTABLE-FALSE'={param($s) $s.processes[0].image_path='D:\FOREIGN\python.exe'}
 'IMAGE-HASH-FALSE'={param($s) $s.processes[0].image_sha256='2'*64}
 'OWNERSHIP-METRIC-MISSING'={param($s) $s.processes=@()}
 'OWNERSHIP-DUPLICATE'={param($s) $s.processes=@($s.processes[0],$s.processes[0])}
 'PROCESS-UNAVAILABLE'={param($s) $s.processes[0].status='UNAVAILABLE'}
 'PRIVATE-WRONG-TYPE'={param($s) $s.processes[0].private_bytes='0'}
 'PRIVATE-NEGATIVE'={param($s) $s.processes[0].private_bytes=[long]-1}
 'CLOCK-REVERSED'={param($s) $s.start_ms=[long]120;$s.end_ms=[long]110;$s.collection_ms=[long]-10}
 'CLOCK-WRONG-DOMAIN'={param($s) $s.clock_id='FOREIGN_CLOCK'}
 'CLOCK-WRONG-TYPE'={param($s) $s.start_ms='100'}
 'CLOCK-COLLECTION-INCONSISTENT'={param($s) $s.collection_ms=[long]11}
 'SOURCE-GENERATION-AGE-UNKNOWN'={param($s) $s.source_generation_freshness='NOT_VERIFIED'}
 'GLOBAL-COMMIT-REVERSED'={param($s) $s.host.commit_total_bytes=[long](15GB);$s.host.commit_headroom_bytes=[long](17GB)}
 'GLOBAL-VRAM-REVERSED'={param($s) $s.gpu.global.used_bytes=[long]0}
}
foreach($entry in $cases.GetEnumerator()){$bad=Clone $sample;& $entry.Value $bad;$out=Test-WlbPassiveResourcePreflight $policy $base $bad $process 200 1000;Row $entry.Key $out ($out.state -ceq 'BLOCKED' -and -not $out.authorized_to_execute)}
foreach($age in @(1000,2000)){
 $out=Test-WlbPassiveResourcePreflight $policy $base $sample $process (100+$age) $age;Row ('FRESHNESS-EXACT-'+$age) $out ($out.state -ceq 'FEASIBILITY_THRESHOLDS_ONLY')
 $out=Test-WlbPassiveResourcePreflight $policy $base $sample $process (101+$age) $age;Row ('FRESHNESS-EXCEEDED-'+$age) $out ($out.state -ceq 'BLOCKED')
}
$late=Clone $sample;$late.start_ms=[long]119990;$late.end_ms=[long]120000;$out=Test-WlbPassiveResourcePreflight $policy $base $late $process 120000 1000;Row 'DEADLINE-120S' $out ($out.reasons -contains 'STARTUP_DEADLINE_EXPIRED')
$out=Test-WlbPassiveResourcePreflight $policy $base $sample $process 100 1000;Row 'FUTURE-SAMPLE-CLOCK' $out ($out.state -ceq 'BLOCKED')
$missing=Test-WlbPassiveResourcePreflight $policy $base $null $process 200 1000;Row 'MISSING-SAMPLE' $missing ($missing.state -ceq 'BLOCKED')
$out=Test-WlbPassiveResourcePreflight $policy $base $sample $process 200 1500;Row 'UNDECLARED-FRESHNESS-CANDIDATE' $out ($out.state -ceq 'BLOCKED')
$before=Clone $process;$after=Clone $process;$after.captured_ms=[long]1000;$after.cpu_total_100ns=[long]11000000
$cpu=Compare-WlbPassiveProcessCpu $before $after;Row 'CPU-OBSERVE-ONLY-NO-CAP' $cpu ($cpu.status -ceq 'OBSERVED_CPU_DELTA_WITH_RATIO_ESTIMATE' -and $null -eq $cpu.cpu_cap)
$after.creation_time_utc='2099-01-01T00:00:01.0000000Z';$cpu=Compare-WlbPassiveProcessCpu $before $after;Row 'CPU-RECYCLED-PID-NO-DELTA' $cpu ($cpu.status -ceq 'UNAVAILABLE')
$owned=@{process_id=424242;creation_time_utc='2099-01-01T00:00:00.0000000Z';image_path='D:\SIMULATED\python.exe';image_sha256=('1'*64);owner_token='00000000-0000-4000-8000-000000000002'}
$consent=@{kind='MOCK_ONLY';scope='G4_STARTUP_ONLY';stop_owned_allowed=$true;owner_token=$owned.owner_token}
$request=Get-WlbMockOwnedStopRequest $owned (Clone $owned) $consent -MockOnly;Row 'OWNED-MOCK-STOP-REQUEST-ONLY' $request ($request.request -ceq 'MOCK_OWNED_STOP_REQUEST_ONLY' -and -not $request.process_killed)
$foreign=Clone $owned;$foreign.process_id=424243;$request=Get-WlbMockOwnedStopRequest $owned $foreign $consent -MockOnly;Row 'FOREIGN-MOCK-STOP-DENIED' $request ($request.request -ceq 'DENIED')
$request=Get-WlbMockOwnedStopRequest $owned (Clone $owned) $consent;Row 'REAL-STOP-PATH-ABSENT' $request ($request.request -ceq 'DENIED' -and -not $request.real_stop_enabled)
$live=Json (Join-Path $Evidence 'live-preflight.json');Row 'LIVE-STRICT-PREFLIGHT-BLOCKED' $live ($live.state -ceq 'BLOCKED' -and $live.reasons -contains 'RTX_PROCESS_VRAM_ATTRIBUTION_NOT_VERIFIED') 'RECHECK_REAL_PASSIVE_MEASUREMENT_NOT_RUNTIME'
$baseline=& (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode StaticReview;Row 'DRAFT-STATIC-BASELINE' $baseline (-not $baseline.executable) 'EXECUTED_CANONICAL_STATIC_VALIDATOR'
Reject 'G4-ENTRY-STILL-REFUSED' {& (Join-Path $Root 'core\Start-WlbRuntime.ps1') -Mode Admission}
Reject 'G5-LAUNCHER-STILL-REFUSED' {& (Join-Path $Root 'core\Invoke-WlbJob.ps1') -ApprovalId ([guid]::Empty)} 'Existing human approval required'
foreach($relative in @('core\Wlb.RuntimeMonitor.ps1','core\Start-WlbRuntime.ps1','core\Invoke-WlbJob.ps1')){
 $t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root $relative),[ref]$t,[ref]$e)
 $commands=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -in @('Start-Process','Stop-Process','Invoke-RestMethod','Invoke-WebRequest','Invoke-Expression','python','python.exe','pip','git')},$true))
 $methods=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Member.Extent.Text -in @('Start','Kill','Connect','Bind','Listen')},$true))
 Row ('NO-LIFECYCLE-OR-REST-'+$relative) @{dangerous_commands=$commands.Count;dangerous_methods=$methods.Count;parser_errors=$e.Count} ($commands.Count -eq 0 -and $methods.Count -eq 0 -and $e.Count -eq 0) 'STATIC_AST_SOURCE_CHECK_NOT_SANDBOX'
}
SaveNew 'passive-contract-results.json' @($results)
$summary=[ordered]@{tests=$results.Count;pass=@($results | Where-Object {$_.status -ceq 'PASS'}).Count;fail=@($results | Where-Object {$_.status -ceq 'FAIL'}).Count;real_process_started=$false;real_process_stopped=$false;listener_opened=$false;python_executed=$false;consent_created=$false;gpu_job=$false}
SaveNew 'passive-contract-summary.json' $summary
$summary | ConvertTo-Json
if($summary.fail){exit 1}
