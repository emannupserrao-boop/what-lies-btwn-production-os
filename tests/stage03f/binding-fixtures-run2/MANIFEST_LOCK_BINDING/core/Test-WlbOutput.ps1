#requires -Version 7.4
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Wlb.Common.ps1')

# Future read-only checker; fixed job paths. It never creates outputs or receipts.
$jobDir = Join-Path $script:WlbRoot 'jobs\POC0-CALIBRATION-001'
$receiptPath = Join-Path $jobDir 'receipt.json'
$receipt = Read-WlbJson $receiptPath
Assert-WlbKeys $receipt @('schema_version','job_id','manifest_sha256','workflow_sha256','runtime_lock_sha256','prompt_id','output_path','output_sha256','execution_status','gpu_device_evidence','resource_evidence','completed_at_utc') 'receipt'
Assert-WlbCondition ($receipt.schema_version -ceq 'wlb-job-receipt/0.1') 'Receipt version mismatch'
Assert-WlbCondition ($receipt.job_id -ceq 'POC0-CALIBRATION-001') 'Receipt job mismatch'
Assert-WlbCondition ($receipt.execution_status -ceq 'COMPLETED') 'Execution not completed'
Assert-WlbCondition ($receipt.manifest_sha256 -ceq (Get-WlbHash (Join-Path $script:WlbRoot 'manifests\draft\POC0-CALIBRATION-001.json'))) 'Receipt/manifest mismatch'
Assert-WlbCondition ($receipt.workflow_sha256 -ceq (Get-WlbHash (Join-Path $script:WlbRoot 'workflows\draft\poc0-calibration.api.json'))) 'Receipt/workflow mismatch'
Assert-WlbCondition ($receipt.runtime_lock_sha256 -ceq (Get-WlbHash (Join-Path $script:WlbRoot 'policy\runtime-lock.json'))) 'Receipt/runtime mismatch'
Assert-WlbCondition (-not [string]::IsNullOrWhiteSpace($receipt.prompt_id)) 'Missing prompt ID'
$outputDir = Join-Path $script:WlbRoot 'runtimes\core\state\output\POC0-CALIBRATION-001'
$null = Assert-WlbPath $outputDir -MustExist
$files = @(Get-ChildItem -LiteralPath $outputDir -Force)
Assert-WlbCondition ($files.Count -eq 1 -and -not $files[0].PSIsContainer) 'Exactly one output file required'
$pngPath = Assert-WlbPath $files[0].FullName -MustExist -File
Assert-WlbCondition ($pngPath -ceq $receipt.output_path) 'Receipt output path mismatch'
Assert-WlbCondition ([IO.Path]::GetFileName($pngPath) -cmatch '^calibration_[0-9]{5}_\.png$') 'Unexpected native output filename'
Assert-WlbCondition ((Get-Item -LiteralPath $pngPath).Length -le 268435456) 'Output exceeds cap'
$outputHash = Get-WlbHash $pngPath
Assert-WlbCondition ($outputHash -ceq $receipt.output_sha256) 'Output hash mismatch'
$stream = [IO.File]::Open($pngPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    $header = [byte[]]::new(33)
    Assert-WlbCondition ($stream.Read($header, 0, 33) -eq 33) 'Truncated PNG'
} finally { $stream.Dispose() }
Assert-WlbCondition ([Convert]::ToHexString($header[0..7]) -ceq '89504E470D0A1A0A') 'PNG signature mismatch'
Assert-WlbCondition ([Convert]::ToHexString($header[8..11]) -ceq '0000000D') 'IHDR length mismatch'
Assert-WlbCondition ([Text.Encoding]::ASCII.GetString($header, 12, 4) -ceq 'IHDR') 'IHDR missing'
$width = [uint32]$header[16]*16777216 + [uint32]$header[17]*65536 + [uint32]$header[18]*256 + [uint32]$header[19]
$height = [uint32]$header[20]*16777216 + [uint32]$header[21]*65536 + [uint32]$header[22]*256 + [uint32]$header[23]
Assert-WlbCondition ($width -eq 640 -and $height -eq 360) 'Wrong dimensions'
Assert-WlbCondition ($header[24] -eq 8 -and $header[25] -eq 2 -and $header[26] -eq 0 -and $header[27] -eq 0 -and $header[28] -eq 0) 'Expected 8-bit RGB noninterlaced PNG'

[pscustomobject]@{
    technical_scope = 'HASH_AND_HEADER_ONLY'; output_sha256 = $outputHash
    width = $width; height = $height; frame_count = 1
    decoded_pixel_color = 'NOT_VERIFIED'; full_png_integrity = 'NOT_VERIFIED'
    gpu_and_budget_evidence_authenticity = 'NOT_VERIFIED'
    human_verdict = 'REQUIRED'; accepted = $false
}
