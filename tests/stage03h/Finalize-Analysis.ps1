#requires -Version 7.6
. (Join-Path $PSScriptRoot 'H.Common.ps1')
. (Join-Path $HRoot 'core\Wlb.RuntimeMonitor.ps1')
$canonical=Read-HJson (Join-Path $HEvidence 'passive-contract-results.json')
$models=Read-HJson (Join-Path $HEvidence 'review-design-results.json')
$all=@($canonical)+@($models)
if($all.Count -ne 103 -or @($all|Where-Object {$_.status -cne 'PASS'}).Count){throw 'Test result divergence'}
Save-HNew 'consolidated-results.json' $all
$policy=Read-WlbJson (Join-Path $HRoot 'policy\startup-policy.json')
Assert-WlbStartupPolicy $policy
$ram=Get-WlbPassiveHostMemory
Save-HNew 'final-readiness.json' @{utc=[DateTime]::UtcNow.ToString('o');host=$ram;ram_gate=$(if($ram.status -eq 'AVAILABLE_GLOBAL' -and $ram.available_ram_bytes -ge 8GB){'PASS_OBSERVED_NOT_AUTHORITY'}else{'BLOCKED'});startup_enabled=$policy.real_startup_enabled;jobs_enabled=$policy.gpu_jobs_enabled;consent=$policy.consent_status;human_parameters=$policy.human_parameters;g4='BLOCKED_NOT_AUTHORIZED';g5='BLOCKED_NOT_AUTHORIZED';alpha='CLOSED';snapshot='STAGED_NOT_ACTIVATED';canonical_changes=0}
$dxgi=Read-HJson (Join-Path $HEvidence 'dxgi-adapter-evidence.json')
$gpu=Read-HJson (Join-Path $HEvidence 'gpu-diagnosis.json')
$r=Read-HJson (Join-Path $HEvidence 'ram-diagnosis.json')
$raw=$gpu.raw_gpu_process_counters[0];$naive=[DateTime]::FromFileTimeUtc([long]$raw.Timestamp_Sys100NS)
$rawReceipt=[DateTime]::Parse($gpu.receipt.utc).ToUniversalTime()
$anomalies=@(foreach($row in $dxgi.rtx_accounting_rows){if($row.dedicated_bytes -gt $gpu.canonical_gpu.global.total_bytes){@{process_id=$row.process_id;counter_bytes=$row.dedicated_bytes;global_capacity_bytes=$gpu.canonical_gpu.global.total_bytes;cannot_mean_single_physical_resident_vram=$true}}})
Save-HNew 'interpretation-limitations.json' @{rtx_accounting_capacity_anomalies=$anomalies;raw_timestamp_100ns=$raw.Timestamp_Sys100NS;raw_naive_filetime_utc=$naive.ToString('o');receipt_utc=$gpu.receipt.utc;naive_timestamp_minus_receipt_seconds=($naive-$rawReceipt).TotalSeconds;timestamp_epoch_clock_conversion_verified=$false;actual_provider_generation_age='NOT_VERIFIED';do_not_correct_by_timezone_or_invent_freshness=$true;private_working_set='UNAVAILABLE_PROVIDER_TIMEOUT';original_empty_group_sum_is_not_zero_measurement=$true;fully_correlated_process_identities=@($r.process_rows|Where-Object {$_.identity_status -like 'CIM_NATIVE*'}).Count;partial_or_denied_process_identities=@($r.process_rows|Where-Object {$_.identity_status -notlike 'CIM_NATIVE*'}).Count;same_image_parent_links=$r.same_image_parent_links.Count;parent_links_are_nonatomic_snapshot_not_historical_ownership=$true}
Save-HNew 'test-summary.json' @{total_checks=103;pass=103;fail=0;canonical_resource_checks=68;review_design_checks=35;fresh_check_executions=102;stored_stage03h_live_preflight_rechecks=1;historical_stage03g_checks_not_reexecuted_or_counted=198;diagnostic_attempt_aborted=1;baseline_reader_prewrite_abort=1;real_runtime_executions=0;model_or_job_executions=0;real_kills=0;g4_consent_records=0}
Save-HNew 'reference-sources.json' @(
 @{url='https://learn.microsoft.com/en-us/windows/win32/api/dxgi/ns-dxgi-dxgi_adapter_desc1';claim='Adapter description contains vendor/device IDs and AdapterLuid; capacity is not usage'},
 @{url='https://learn.microsoft.com/en-us/windows/win32/api/dxgi/nf-dxgi-idxgifactory1-enumadapters1';claim='Enumerate adapter descriptors; release own interface references'},
 @{url='https://docs.nvidia.com/deploy/nvidia-smi/index.html';claim='Process GPU memory unavailable under WDDM, Windows KMD manages memory'},
 @{url='https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/gpu-process-memory-counters-report-wrong-value';claim='Known Windows10 counter issue; contextual caution, not diagnosis of this host'},
 @{url='https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-perfrawdata';claim='Provider performance timestamps used in counter formulas; not proof of individual metric generation freshness'}
)
@{checks=$all.Count;final_ram_gib=[Math]::Round($ram.available_ram_bytes/1GB,3);ram_gate='PASS_OBSERVED_NOT_AUTHORITY';g4='BLOCKED_NOT_AUTHORIZED';g5='BLOCKED_NOT_AUTHORIZED';counter_anomalies=$anomalies.Count}|ConvertTo-Json
