#requires -Version 7.6
# One-shot integrity evidence; existing baselines and canonical hashes read only.
. (Join-Path $PSScriptRoot 'I.Common.ps1')
$baseline=@(Import-Csv -LiteralPath (Join-Path $IEvidence 'baseline-files.csv'))
$changes=Read-IJson (Join-Path $IEvidence 'canonical-changes-delivery.json')
$expected=@{};foreach($row in $changes){$expected[$row.path]=$row.after_sha256}
$old=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);$actualChanges=@();$drift=@()
foreach($row in $baseline){
 $null=$old.Add($row.path)
 if(-not(Test-Path -LiteralPath $row.path -PathType Leaf)){$drift+=@(@{path=$row.path;reason='MISSING'});continue}
 $hash=(Get-FileHash -LiteralPath $row.path).Hash.ToLowerInvariant()
 if($hash -cne $row.sha256){
  if($expected.ContainsKey($row.path) -and $hash -ceq $expected[$row.path]){$actualChanges+=@($row.path)}else{$drift+=@(@{path=$row.path;reason='UNEXPECTED_HASH_DRIFT'})}
 }
}
if($drift.Count -or $actualChanges.Count -ne 3){$drift|ConvertTo-Json;throw 'STOP preservation drift'}
foreach($row in $changes){if((Get-FileHash -LiteralPath $row.path).Hash.ToLowerInvariant() -cne $row.after_sha256){throw 'Final canonical source pin drift'}}
$lock=Read-IJson (Join-Path $IRoot 'policy\runtime-lock.json')
foreach($key in $lock.prepared_artifacts.Keys){if((Get-FileHash -LiteralPath (Join-Path $IRoot $key)).Hash.ToLowerInvariant() -cne $lock.prepared_artifacts[$key]){throw 'Final prepared pin drift'}}
$before=Read-IJson (Join-Path $IRoot 'tests\stage03i\baseline\policy__runtime-lock.json');$compare=Copy-IObject $lock
$null=$compare.prepared_artifacts.Remove('core\Wlb.Supervisor.ps1');$null=$compare.prepared_artifacts.Remove('core\Wlb.TelemetryWorker.ps1');$compare.prepared_artifacts['core\Test-WlbManifest.ps1']=$before.prepared_artifacts['core\Test-WlbManifest.ps1']
if((ConvertTo-Json -InputObject $compare -Depth 80 -Compress) -cne (ConvertTo-Json -InputObject $before -Depth 80 -Compress)){throw 'Unexpected lock semantic mutation'}
$manifestPath=Join-Path $IRoot 'manifests\draft\POC0-CALIBRATION-001.json';$beforeManifest=Get-Content -LiteralPath (Join-Path $IRoot 'tests\stage03i\baseline\manifests__draft__POC0-CALIBRATION-001.json') -Raw
$afterManifest=Get-Content -LiteralPath $manifestPath -Raw;$oldLockHash=(Get-FileHash -LiteralPath (Join-Path $IRoot 'tests\stage03i\baseline\policy__runtime-lock.json')).Hash.ToLowerInvariant();$newLockHash=(Get-FileHash -LiteralPath (Join-Path $IRoot 'policy\runtime-lock.json')).Hash.ToLowerInvariant()
if($afterManifest -cne $beforeManifest.Replace($oldLockHash,$newLockHash)){throw 'Unexpected manifest byte mutation'}
$new=@(Get-ChildItem -LiteralPath $IRoot -File -Force -Recurse|Where-Object {-not $old.Contains($_.FullName)})
$newCore=@('core\Wlb.Supervisor.ps1','core\Wlb.TelemetryWorker.ps1');$reports=@('STAGE03I_IMPLEMENTATION_RECEIPT.md','STAGE03I_SUPERVISION_DECISION_PACKAGE.md','STAGE03I_TEST_MATRIX.md')
foreach($row in $new){$rel=$row.FullName.Substring($IRoot.Length+1);if(-not $rel.StartsWith('tests\stage03i\',[StringComparison]::OrdinalIgnoreCase) -and $rel -notin $newCore -and $rel -notin $reports){throw 'New file outside StageI scope'}}
$sourceParse=@(foreach($row in @($new|Where-Object Extension -eq '.ps1')){$tok=$null;$err=$null;$null=[Management.Automation.Language.Parser]::ParseFile($row.FullName,[ref]$tok,[ref]$err);@{path=$row.FullName;errors=@($err).Count}})
if(@($sourceParse|Where-Object {$_.errors -gt 0}).Count){throw 'Prepared PS script parse error'}
$summary=Read-IJson (Join-Path $IEvidence 'test-summary.json');if($summary.checks -ne 198 -or $summary.fail -ne 0){throw 'Test summary divergence'}
$receiptPath=Join-Path $IRoot 'STAGE03I_IMPLEMENTATION_RECEIPT.md';$report=Get-Content -LiteralPath $receiptPath -Raw
$sections=@('A. STAGE03I_STATUS','B. VERIFIED_STAGE03H_BASELINE','C. DOCUMENT_RECONCILIATION_AND_SCOPE','D. EXACT_CHANGESET_AND_HASHES','E. SUPERVISOR_IMPLEMENTATION','F. TELEMETRY_WORKER_IMPLEMENTATION','G. MAILBOX_AND_FRESHNESS_CONTRACT','H. FAILURE_AND_DEADLINE_TESTS','I. GLOBAL_GPU_PROXY_PREPARATION_STATUS','J. PERFORMANCE_AND_OVERHEAD','K. REGRESSION_RESULTS','L. HUMAN_DECISIONS_PENDING','M. MINIMUM_NEXT_G4_CHANGESET','N. REMAINING_G4_AND_G5_BLOCKERS','O. NO_OUT_OF_SCOPE_MUTATION_ATTESTATION','P. NEXT_GATE = WAITING_HUMAN_REVIEW')
foreach($section in $sections){if(-not $report.Contains('## '+$section)){throw 'Missing required report section'}}
foreach($rel in $reports){$text=Get-Content -LiteralPath (Join-Path $IRoot $rel) -Raw;foreach($match in [regex]::Matches($text,'\]\((D:/[^)]+)\)')){if(-not(Test-Path -LiteralPath $match.Groups[1].Value)){throw 'Broken local artifact link'}}}
$snapshot=@($baseline|Where-Object {$_.relative_path.StartsWith('runtimes\core\ComfyUI\',[StringComparison]::OrdinalIgnoreCase)})
if($snapshot.Count -ne 619){throw 'Snapshot inventory baseline count drift'}
Save-INew 'final-audit.json' @{utc=[DateTime]::UtcNow.ToString('o');preexisting_files=3281;preserved_preexisting=3278;modified_existing=3;allowed_existing_changes=$actualChanges;unexpected_drift=0;snapshot_files_preserved=619;new_files_before_audit=$new.Count;new_core=2;new_reports=3;all_new_paths_in_scope=$true;source_parse_checks=$sourceParse;sections_verified=16;final_pins=19;lock_changes_only_source_pins=$true;manifest_changed_only64hex_binding=$true;tests=$summary;g4='BLOCKED_NOT_AUTHORIZED';g5='NOT_AUTHORIZED';alpha_mcp='CLOSED';runtime_started=$false;process_killed=$false;approval_created_or_consumed=$false;parameters_bound=$false;next_gate='WAITING_HUMAN_REVIEW';attestation_scope='Observed commands and Production OS hashes; not independent Windows/app activity'}
$index=@(Get-ChildItem -LiteralPath $IRoot -File -Force -Recurse|Where-Object {-not $old.Contains($_.FullName) -or $expected.ContainsKey($_.FullName)}|Sort-Object FullName|ForEach-Object {
 $before=@($baseline|Where-Object path -ceq $_.FullName)
 [pscustomobject]@{path=$_.FullName;change=$(if($before.Count){'MODIFIED_AUTHORIZED'}else{'NEW'});bytes=$_.Length;before_sha256=$(if($before.Count){$before[0].sha256}else{$null});sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}
})
Save-INew 'changes-inventory.csv' (($index|ConvertTo-Csv -NoTypeInformation)-join "`n") -Text
$integrity=@{receipt_sha256=(Get-FileHash -LiteralPath $receiptPath).Hash.ToLowerInvariant();decision_package_sha256=(Get-FileHash -LiteralPath (Join-Path $IRoot 'STAGE03I_SUPERVISION_DECISION_PACKAGE.md')).Hash.ToLowerInvariant();test_matrix_sha256=(Get-FileHash -LiteralPath (Join-Path $IRoot 'STAGE03I_TEST_MATRIX.md')).Hash.ToLowerInvariant();inventory_sha256=(Get-FileHash -LiteralPath (Join-Path $IEvidence 'changes-inventory.csv')).Hash.ToLowerInvariant();final_audit_sha256=(Get-FileHash -LiteralPath (Join-Path $IEvidence 'final-audit.json')).Hash.ToLowerInvariant();inventory_rows=$index.Count;modified_existing=3;new_files_total=$index.Count-3+2;preexisting_preserved=3278;canonical_changes=$changes;self_metadata_excluded=@('tests\stage03i\evidence\changes-inventory.csv','tests\stage03i\evidence\delivery-integrity.json');self_metadata_hash_recorded_in_final_response=$true;next_gate='WAITING_HUMAN_REVIEW'}
Save-INew 'delivery-integrity.json' $integrity
foreach($row in $index){if((Get-FileHash -LiteralPath $row.path).Hash.ToLowerInvariant() -cne $row.sha256){throw 'Delivery inventory drift'}}
foreach($row in $baseline){$hash=(Get-FileHash -LiteralPath $row.path).Hash.ToLowerInvariant();$desired=if($expected.ContainsKey($row.path)){$expected[$row.path]}else{$row.sha256};if($hash -cne $desired){throw 'Postdelivery preexisting drift'}}
$integrity|ConvertTo-Json -Depth 12
@{delivery_integrity_sha256=(Get-FileHash -LiteralPath (Join-Path $IEvidence 'delivery-integrity.json')).Hash.ToLowerInvariant();root_files=@(Get-ChildItem -LiteralPath $IRoot -File -Force -Recurse).Count}|ConvertTo-Json
