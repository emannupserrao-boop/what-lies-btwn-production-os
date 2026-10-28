#requires -Version 7.6
param([ValidatePattern('^[a-z0-9-]+$')][string]$RunLabel='audit02')
. (Join-Path $PSScriptRoot 'J.Common.ps1')
$baseline=Import-Csv -LiteralPath (Join-Path $JEvidence 'baseline-files.csv')
$allowed=@('core\Test-WlbManifest.ps1','policy\runtime-lock.json','manifests\draft\POC0-CALIBRATION-001.json')
$changes=[Collections.Generic.List[object]]::new();$missing=[Collections.Generic.List[string]]::new();$checks=[Collections.Generic.List[object]]::new()
function Final-J([string]$Id,[bool]$Valid,[string]$Detail){$checks.Add(@{id=$Id;kind='FINAL_INTEGRITY';status=$(if($Valid){'PASS'}else{'FAIL'});detail=$Detail})}
foreach($row in $baseline){
 if(-not (Test-Path -LiteralPath $row.path -PathType Leaf)){$missing.Add($row.relative_path);continue}
 $now=(Get-FileHash -LiteralPath $row.path).Hash.ToLowerInvariant()
 if($now -cne $row.sha256){$changes.Add(@{relative_path=$row.relative_path;before_sha256=$row.sha256;after_sha256=$now;allowed=$row.relative_path -cin $allowed})}
}
Final-J 'baseline3387-only-three-documented-changes' ($baseline.Count -eq 3387 -and $changes.Count -eq 3 -and $missing.Count -eq 0 -and @($changes|Where-Object {-not $_.allowed}).Count -eq 0) '3384 original files unchanged; only validator, lock and draft binding changed'
$backupsValid=$true
foreach($key in $allowed){$old=@($baseline|Where-Object {$_.relative_path -ceq $key})[0];$backup=Join-Path $PSScriptRoot ('baseline\'+$key.Replace('\','__'));if((Get-FileHash -LiteralPath $backup).Hash.ToLowerInvariant() -cne $old.sha256){$backupsValid=$false}}
Final-J 'exact-three-rollback-backups' $backupsValid 'Prechange sources match StageI baseline hashes'
$oldLock=Read-JJson (Join-Path $PSScriptRoot 'baseline\policy__runtime-lock.json');$newLock=Read-JJson (Join-Path $JRoot 'policy\runtime-lock.json')
$oldPins=$oldLock.prepared_artifacts;$newPins=$newLock.prepared_artifacts
$oldLock.Remove('prepared_artifacts');$newLock.Remove('prepared_artifacts')
Final-J 'runtime-lock-only-prepared-pins-changed' ((ConvertTo-Json $oldLock -Depth 70 -Compress) -ceq (ConvertTo-Json $newLock -Depth 70 -Compress)) 'All non-pin lock values unchanged'
$pinsValid=$newPins.Count -eq 21 -and $oldPins.Count -eq 19
foreach($entry in $oldPins.GetEnumerator()){if($entry.Key -cne 'core\Test-WlbManifest.ps1' -and $newPins[$entry.Key] -cne $entry.Value){$pinsValid=$false}}
foreach($entry in $newPins.GetEnumerator()){if((Get-FileHash -LiteralPath (Join-Path $JRoot $entry.Key)).Hash.ToLowerInvariant() -cne $entry.Value){$pinsValid=$false}}
Final-J '19-to21-prepared-map-exact' $pinsValid '18 old pins unchanged; validator repinned; two new disabled components'
$oldManifest=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'baseline\manifests__draft__POC0-CALIBRATION-001.json'))
$oldHash=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'baseline\policy__runtime-lock.json')).Hash.ToLowerInvariant();$newHash=(Get-FileHash -LiteralPath (Join-Path $JRoot 'policy\runtime-lock.json')).Hash.ToLowerInvariant()
Final-J 'draft-only64char-lock-sha-replacement' ($oldManifest.Replace($oldHash,$newHash) -ceq [IO.File]::ReadAllText((Join-Path $JRoot 'manifests\draft\POC0-CALIBRATION-001.json'))) 'Draft differs solely in runtime lock SHA256'
$oldValidator=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'baseline\core__Test-WlbManifest.ps1'))
$expectedValidator=$oldValidator.Replace("'core\Wlb.Supervisor.ps1', 'core\Wlb.TelemetryWorker.ps1')","'core\Wlb.Supervisor.ps1', 'core\Wlb.TelemetryWorker.ps1', 'core\Wlb.WorkerProcess.ps1', 'tests\stage03j\OwnedTelemetryWorker.ps1')")
Final-J 'validator-only-two-allowlist-paths-added' ($expectedValidator -ceq [IO.File]::ReadAllText((Join-Path $JRoot 'core\Test-WlbManifest.ps1'))) 'No budget/policy/execution logic changed'
$baselineSet=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);foreach($row in $baseline){$null=$baselineSet.Add($row.relative_path)}
$newFiles=@(Get-ChildItem -LiteralPath $JRoot -Recurse -File|ForEach-Object {$rel=[IO.Path]::GetRelativePath($JRoot,$_.FullName);if(-not $baselineSet.Contains($rel)){[pscustomobject]@{relative_path=$rel;bytes=$_.Length}}})
$scopeValid=$true;foreach($file in $newFiles){if($file.relative_path -cne 'core\Wlb.WorkerProcess.ps1' -and -not $file.relative_path.StartsWith('tests\stage03j\',[StringComparison]::Ordinal) -and $file.relative_path -notmatch '^STAGE03J_[A-Z0-9_]+\.(md|csv|json)$'){$scopeValid=$false}}
Final-J 'new-files-stay-in-approved-stageJ-scope' $scopeValid 'New core component, tests/stage03j and StageJ delivery documents only'
Final-J 'no-new-approval-records' (@($newFiles|Where-Object {$_.relative_path.StartsWith('approvals\',[StringComparison]::OrdinalIgnoreCase)}).Count -eq 0) 'No G4/G5 approvals created or consumed'
$indexes=@(Get-ChildItem -LiteralPath $JEvidence -Filter 'run*-real-index.json');$allAttempts=[Collections.Generic.List[object]]::new()
foreach($file in $indexes){$items=Read-JJson $file.FullName;foreach($item in $items){$allAttempts.Add($item)}}
Final-J 'all-recorded-owned-helper-handles-proved-exited' (@($allAttempts|Where-Object {-not $_.lease.exited}).Count -eq 0) ('All '+$allAttempts.Count+' created benign helpers exited before their creation handles were closed; includes repaired attempts')
$final=Read-JJson (Join-Path $JEvidence 'run06-real-index.json')
Final-J 'final-six-attempts-zero-harness-failure' (@($final|Where-Object {$null -ne $_.failure}).Count -eq 0) 'run06 is final real process evidence'
$oneStop=$true;foreach($item in $final){if(@($item.stop_history|Where-Object {$_.result.TerminationRequested}).Count -gt 1){$oneStop=$false}}
Final-J 'owned-stop-request-latched-once' $oneStop 'No repeated termination request while waiting for process exit'
$bytes=[long](($newFiles|Measure-Object -Property bytes -Sum).Sum)
Final-J 'stageJ-created-file-footprint-below256MiB' ($bytes -lt 256MB) ($bytes.ToString()+' bytes before delivery metadata; observed footprint, not hard OS cap')
$syntaxValid=$true;foreach($path in @('core\Wlb.WorkerProcess.ps1','tests\stage03j\OwnedTelemetryWorker.ps1','tests\stage03j\J.Common.ps1','tests\stage03j\Bind-PreparedOnly.ps1','tests\stage03j\Invoke-RealBoundaryTests.ps1','tests\stage03j\Test-ProtocolAndRegressions.ps1','tests\stage03j\Test-FinalIntegrity.ps1')){$errs=$null;$null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $JRoot $path),[ref]$null,[ref]$errs);if($errs.Count){$syntaxValid=$false}}
Final-J 'current-stageJ-source-syntax-valid' $syntaxValid 'PowerShell parser checked seven current StageJ sources'
$normal=@($final|Where-Object {$_.case -ceq 'normal-passive'})[0];$sample=$normal.samples[0];$payload=$sample.PayloadJson|ConvertFrom-Json -AsHashtable -DateKind String
$hostRows=@(foreach($item in $final){$item.host_before;$item.host_after})
$minRam=[long](($hostRows.available_ram_bytes|Measure-Object -Minimum).Minimum);$minHeadroom=[long](($hostRows.commit_headroom_bytes|Measure-Object -Minimum).Minimum)
$maxPositiveDelta=[long]0;foreach($item in $final){$delta=$item.host_after.commit_total_bytes-$item.host_before.commit_total_bytes;if($delta -gt $maxPositiveDelta){$maxPositiveDelta=$delta}}
Final-J 'observed-minimal-helper-resource-readings-within-budgets' ($minRam -ge 8GB -and $minHeadroom -ge 10GB -and $payload.process.private_bytes -le 4GB -and $maxPositiveDelta -le 4GB) 'Discrete passive samples only: neither peak monitoring nor global delta attribution nor GPU residency proof'
$metrics=@{final_run='run06';total_created_helpers=$allAttempts.Count;actual_max_concurrent_helpers=1;implementation_concurrency_limit=2;implementation_total_limit_per_parent=32;minimum_observed_ram_bytes=$minRam;minimum_observed_commit_headroom_bytes=$minHeadroom;maximum_observed_positive_global_commit_delta_bytes=$maxPositiveDelta;normal_helper_observed_private_bytes=$payload.process.private_bytes;final_live_sample_payload_bytes=[Text.Encoding]::UTF8.GetByteCount($sample.PayloadJson);normal_collection_duration_ms=$sample.CollectionCompletedMs-$sample.RequestStartedMs;normal_acquisition_to_receipt_ms=$normal.messages[3].received_ms-[Math]::Min($sample.FastAcquiredMs,$sample.SlowAcquiredMs);new_file_bytes_before_delivery=$bytes;preexisting_files=$baseline.Count;preexisting_unchanged=$baseline.Count-$changes.Count;existing_modified=$changes.Count;no_real120s_watchdog_claim=$true;gpu_residency='NOT_VERIFIED';provider_generation_age='UNKNOWN'}
Save-JNew ($RunLabel+'-metrics.json') $metrics
Save-JNew ($RunLabel+'-final-audit.json') @{utc=[DateTime]::UtcNow.ToString('o');baseline_count=$baseline.Count;preserved=$baseline.Count-$changes.Count;modified=@($changes);missing=@($missing);new_files=@($newFiles);checks=@($checks);metrics=$metrics;scope_attestation='Explicit operations and checked Production OS inventory only; not a forensic all-host immutability claim'}
Save-JNew ($RunLabel+'-integrity-checks.json') @($checks)
@{pass=@($checks|Where-Object {$_.status -eq 'PASS'}).Count;fail=@($checks|Where-Object {$_.status -eq 'FAIL'}).Count;metrics=$metrics}|ConvertTo-Json -Depth 8
if(@($checks|Where-Object {$_.status -eq 'FAIL'}).Count){exit 1}
