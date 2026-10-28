#requires -Version 7.4
[CmdletBinding()]
param([ValidateSet('StaticReview', 'ExecutionEligibility')][string]$Mode = 'StaticReview')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Wlb.Common.ps1')

# Fixed artifact paths. No arbitrary manifest/workflow path exposed as a parameter.
$manifestPath = Join-Path $script:WlbRoot 'manifests\draft\POC0-CALIBRATION-001.json'
$schemaPath = Join-Path $script:WlbRoot 'policy\shot-manifest.schema.json'
$policyPath = Join-Path $script:WlbRoot 'policy\executor-policy.json'
$lockPath = Join-Path $script:WlbRoot 'policy\runtime-lock.json'
$graphPath = Join-Path $script:WlbRoot 'workflows\draft\poc0-calibration.api.json'
$biblePath = Join-Path $script:WlbRoot 'bible\character-bible.v0.1.json'

$manifest = Read-WlbJson $manifestPath
$policy = Read-WlbJson $policyPath
Assert-WlbExecutorPolicy $policy
$runtime = Read-WlbJson $lockPath
$graph = Read-WlbJson $graphPath
$rawManifest = [IO.File]::ReadAllText($manifestPath)
Assert-WlbCondition ($rawManifest | Test-Json -SchemaFile $schemaPath -ErrorAction Stop) 'Manifest schema rejected'
Assert-WlbCondition ($manifest.job_id -ceq 'POC0-CALIBRATION-001') 'Wrong job'
Assert-WlbCondition ($manifest.workflow.path -ceq $graphPath) 'Wrong workflow path'
Assert-WlbCondition ($manifest.workflow.sha256 -ceq (Get-WlbHash $graphPath)) 'Workflow hash mismatch'
Assert-WlbCondition ($manifest.binding.policy_sha256 -ceq (Get-WlbHash $policyPath)) 'Policy hash mismatch'
Assert-WlbCondition ($manifest.binding.runtime_lock_sha256 -ceq (Get-WlbHash $lockPath)) 'Runtime lock hash mismatch'
Assert-WlbCondition ($manifest.binding.character_bible_sha256 -ceq (Get-WlbHash $biblePath)) 'Bible hash mismatch'

Assert-WlbCondition ($policy.root -ceq $script:WlbRoot) 'Policy root mismatch'
Assert-WlbCondition ($policy.endpoint -ceq 'http://127.0.0.1:8189') 'Endpoint mismatch'
Assert-WlbCondition ($policy.execution_enabled -eq $false) 'G1 policy must disable execution'
Assert-WlbCondition ($policy.max_active_jobs -eq 1) 'Concurrency mismatch'
Assert-WlbCondition ($policy.auto_retry -eq $false) 'Retry must be disabled'
Assert-WlbCondition (($policy.allowed_nodes -join ',') -ceq 'EmptyImage,SaveImage') 'Node allowlist mismatch'
Assert-WlbCondition ($manifest.workflow.allowed_nodes.Count -eq 2) 'Manifest node count mismatch'
Assert-WlbCondition (($manifest.workflow.allowed_nodes -join ',') -ceq 'EmptyImage,SaveImage') 'Manifest allowlist mismatch'

Assert-WlbPoc0Graph $graph

foreach ($entry in $runtime.prepared_artifacts.GetEnumerator()) {
    $boundPath = Join-Path $script:WlbRoot $entry.Key
    Assert-WlbCondition ((Get-WlbHash $boundPath) -ceq $entry.Value) "Prepared artifact changed: $($entry.Key)"
}
$expectedArtifacts = @('core\Wlb.Common.ps1', 'core\Test-WlbManifest.ps1', 'core\Invoke-WlbJob.ps1', 'core\Test-WlbOutput.ps1', 'policy\shot-manifest.schema.json', 'policy\executor-policy.json', 'bible\character-bible.v0.1.json', 'workflows\draft\poc0-calibration.api.json', 'spec\FUTURE_EXECUTION_CONTRACT.md', 'core\Wlb.Startup.ps1', 'core\Start-WlbRuntime.ps1', 'core\Wlb.RuntimeMonitor.ps1', 'core\Wlb.StartupFiles.ps1', 'policy\startup-policy.json', 'policy\startup-identity.json', 'spec\G4_SNAPSHOT_COPY_INVENTORY.csv', 'spec\G4_DEPENDENCY_METADATA.json')
Assert-WlbKeys $runtime.prepared_artifacts $expectedArtifacts 'runtime/prepared_artifacts'
Assert-WlbCondition ($manifest.output.directory -ceq (Join-Path $script:WlbRoot 'runtimes\core\state\output\POC0-CALIBRATION-001')) 'Output destination changed'
$null = Assert-WlbPath $manifest.output.directory -MustBeAbsent

$caps = @{ min_available_ram_gib=8; min_commit_headroom_gib=10; max_incremental_commit_gib=4; max_process_private_gib=4; max_incremental_vram_gib=2; startup_timeout_seconds=120; job_timeout_seconds=30; output_log_cap_mib=256 }
Assert-WlbKeys $manifest.budget @($caps.Keys) 'manifest/budget'
Assert-WlbKeys $policy.budget @($caps.Keys) 'policy/budget'
foreach ($key in $caps.Keys) {
    Assert-WlbJsonType -Value $manifest.budget[$key] -Type Integer -Context "manifest/budget/$key"
    Assert-WlbCondition ($manifest.budget[$key] -eq $caps[$key] -and $policy.budget[$key] -eq $caps[$key]) "Budget changed: $key"
}

if ($Mode -eq 'ExecutionEligibility') {
    throw 'BLOCKED: G1 preparation only. Execution disabled; runtime snapshot, approval, trusted preflight, monitor and submit adapter are not implemented/verified. See spec/FUTURE_EXECUTION_CONTRACT.md.'
}
Assert-WlbCondition ($manifest.state -ceq 'DRAFT') 'G1 artifact must remain DRAFT'
Assert-WlbCondition ($manifest.approval_contract.record_created -eq $false) 'Premature approval'
[pscustomobject]@{
    review = 'STATIC_CONTRACT_CHECK_ONLY'; job_id = $manifest.job_id
    manifest_sha256 = Get-WlbHash $manifestPath
    graph_sha256 = Get-WlbHash $graphPath
    executable = $false; runtime_validation = 'NOT_VERIFIED'
    approval = 'ABSENT'; submission = 'NOT_PERFORMED'
}
