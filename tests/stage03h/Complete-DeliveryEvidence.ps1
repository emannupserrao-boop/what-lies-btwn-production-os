#requires -Version 7.6
# Read-only preservation audit; new evidence only. Do not rerun into same namespace.
. (Join-Path $PSScriptRoot 'H.Common.ps1')
$baseline=@(Import-Csv -LiteralPath (Join-Path $HEvidence 'baseline-files.csv'))
$old=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$drift=@(foreach($file in $baseline){
 $null=$old.Add($file.path)
 if(-not(Test-Path -LiteralPath $file.path -PathType Leaf)){@{path=$file.path;status='MISSING'};continue}
 $item=Get-Item -LiteralPath $file.path
 $hash=(Get-FileHash -LiteralPath $file.path -Algorithm SHA256).Hash.ToLowerInvariant()
 if($hash -cne $file.sha256 -or $item.Length -ne [long]$file.bytes){@{path=$file.path;status='DRIFT';before=$file.sha256;after=$hash}}
})
if($drift.Count){$drift|ConvertTo-Json -Depth 9;throw 'STOP: preexisting file drift'}
$new=@(Get-ChildItem -LiteralPath $HRoot -Recurse -Force -File|Where-Object {-not $old.Contains($_.FullName)})
$outside=@($new|Where-Object {-not $_.FullName.StartsWith((Join-Path $HRoot 'tests\stage03h')+'\',[StringComparison]::OrdinalIgnoreCase) -and $_.Name -notin @('STAGE03H_G4_RESOURCE_DECISION_PACKAGE.md','STAGE03H_IMPLEMENTATION_RECEIPT.md')})
if($outside.Count){throw 'New file out of StageH scope'}
$linked=@(Get-ChildItem -LiteralPath (Join-Path $HRoot 'tests\stage03h') -Force -Recurse|Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0})
if($linked.Count){throw 'New reparse path rejected'}
$parsers=@(foreach($file in @($new|Where-Object Extension -eq '.ps1')){
 $tok=$null;$err=$null;$null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tok,[ref]$err)
 [pscustomobject]@{path=$file.FullName;parser_errors=@($err).Count}
})
if(@($parsers|Where-Object parser_errors -ne 0).Count){throw 'Prepared script parse error'}
$snap=@($baseline|Where-Object {$_.relative_path.StartsWith('runtimes\core\ComfyUI\',[StringComparison]::OrdinalIgnoreCase)})
if($snap.Count -ne 619 -or [long](($snap|Measure-Object bytes -Sum).Sum) -ne 9533695){throw 'Snapshot baseline count drift'}
$test=Read-HJson (Join-Path $HEvidence 'test-summary.json')
$ready=Read-HJson (Join-Path $HEvidence 'final-readiness.json')
$report=Join-Path $HRoot 'STAGE03H_G4_RESOURCE_DECISION_PACKAGE.md'
$receipt=Join-Path $HRoot 'STAGE03H_IMPLEMENTATION_RECEIPT.md'
$text=Get-Content -LiteralPath $report -Raw
$sections=@('A. STAGE03H_STATUS','B. BASELINE_VERIFICATION','C. RAM_CONSUMPTION_DIAGNOSIS','D. MEMORY_RECOVERY_OPTIONS_FOR_OPERATOR','E. SAMPLING_OVERHEAD_ANALYSIS','F. NVIDIA_WDDM_ATTRIBUTION_RESULT','G. GLOBAL_GPU_PROXY_CONTRACT_PROPOSAL','H. PROVIDER_FRESHNESS_AND_WATCHDOG_DESIGN','I. HUMAN_PARAMETER_BINDING_PROPOSAL','J. TESTS_AND_EVIDENCE','K. MINIMUM_NEXT_CHANGESET','L. REMAINING_G4_BLOCKERS','M. REMAINING_G5_BLOCKERS','N. NO_OUT_OF_SCOPE_MUTATION_ATTESTATION','O. NEXT_GATE = WAITING_HUMAN_REVIEW')
foreach($section in $sections){if(-not $text.Contains('## '+$section)){throw 'Missing required delivery section'}}
$localLinks=@([regex]::Matches($text,'\]\((D:/[^)]+)\)')|ForEach-Object {$_.Groups[1].Value})
foreach($link in $localLinks){if(-not(Test-Path -LiteralPath $link)){throw 'Broken artifact link'}}
Save-HNew 'final-audit.json' @{utc=[DateTime]::UtcNow.ToString('o');preexisting_files=$baseline.Count;preserved=$baseline.Count;changed=0;removed=0;snapshot_files=$snap.Count;snapshot_bytes=9533695;new_files_before_audit=$new.Count;all_new_in_scope=$true;new_reparse_paths=0;parse_checks=$parsers;required_sections=$sections.Count;local_links_checked=$localLinks.Count;tests=$test;readiness=$ready;canonical_edits=0;no_python_or_runtime_or_jobs_or_process_intervention=$true;human_parameters_bound=$false;next_gate='WAITING_HUMAN_REVIEW';scope_of_attestation='Observed commands and Production OS hashes, not independent Windows/app activity'}
$index=@(Get-ChildItem -LiteralPath $HRoot -Recurse -Force -File|Where-Object {-not $old.Contains($_.FullName)}|Sort-Object FullName|ForEach-Object {[pscustomobject]@{path=$_.FullName;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}})
Save-HNew 'new-files-inventory.csv' (($index|ConvertTo-Csv -NoTypeInformation)-join "`n") -Text
$integrity=@{receipt_sha256=(Get-FileHash -LiteralPath $receipt).Hash.ToLowerInvariant();decision_package_sha256=(Get-FileHash -LiteralPath $report).Hash.ToLowerInvariant();new_inventory_sha256=(Get-FileHash -LiteralPath (Join-Path $HEvidence 'new-files-inventory.csv')).Hash.ToLowerInvariant();final_audit_sha256=(Get-FileHash -LiteralPath (Join-Path $HEvidence 'final-audit.json')).Hash.ToLowerInvariant();inventory_rows=$index.Count;new_files_total=$index.Count+2;preexisting_preserved=$baseline.Count;canonical_changes=0;self_metadata_excluded=@('tests\stage03h\evidence\new-files-inventory.csv','tests\stage03h\evidence\delivery-integrity.json');self_hash_recorded_in_final_response=$true;next_gate='WAITING_HUMAN_REVIEW'}
Save-HNew 'delivery-integrity.json' $integrity
foreach($file in $baseline){if((Get-FileHash -LiteralPath $file.path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $file.sha256){throw 'Postdelivery drift'}}
foreach($file in $index){if((Get-FileHash -LiteralPath $file.path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $file.sha256){throw 'New delivery file drift'}}
$integrity|ConvertTo-Json -Depth 12
@{delivery_integrity_sha256=(Get-FileHash -LiteralPath (Join-Path $HEvidence 'delivery-integrity.json')).Hash.ToLowerInvariant();current_files=@(Get-ChildItem -LiteralPath $HRoot -Recurse -Force -File).Count}|ConvertTo-Json
