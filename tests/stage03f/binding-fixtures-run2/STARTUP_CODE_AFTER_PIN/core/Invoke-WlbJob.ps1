#requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('POC0-CALIBRATION-001')][string]$JobId = 'POC0-CALIBRATION-001',
    [guid]$ApprovalId
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Wlb.Common.ps1')

# Deliberate G1 fail-closed launcher contract. No network, process-start,
# approval writes, receipt creation or output writes exist in this version.
# G1 cannot credibly claim a tested budget watchdog or TOCTOU boundary.
$null = & (Join-Path $PSScriptRoot 'Test-WlbManifest.ps1') -Mode StaticReview
if ($ApprovalId -eq [guid]::Empty) { throw 'BLOCKED: Existing human approval required; no approval is created by this launcher.' }
$approvalPath = Join-Path $script:WlbRoot ("approvals\{0}.json" -f $ApprovalId.ToString('D'))
$approval = Read-WlbJson $approvalPath
Assert-WlbKeys $approval @('schema_version','approval_id','job_id','manifest_sha256','graph_sha256','runtime_lock_sha256','policy_sha256','scope','status','approved_by','expires_at_utc') 'approval'
Assert-WlbCondition ($approval.schema_version -ceq 'wlb-approval/0.1') 'Approval version mismatch'
Assert-WlbCondition ($approval.approval_id -ceq $ApprovalId.ToString('D')) 'Approval ID mismatch'
Assert-WlbCondition ($approval.job_id -ceq $JobId) 'Approval job mismatch'
Assert-WlbCondition ($approval.scope -ceq 'ONE_GPU_JOB_ONLY') 'Approval scope mismatch'
Assert-WlbCondition ($approval.status -ceq 'UNUSED') 'Approval replay rejected'
Assert-WlbCondition (-not [string]::IsNullOrWhiteSpace($approval.approved_by) -and $approval.approved_by -cne 'UNKNOWN') 'Missing human owner'
Assert-WlbCondition ($approval.expires_at_utc -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') 'Approval requires exact UTC expiry'
$expiry = [DateTimeOffset]::ParseExact($approval.expires_at_utc, "yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
Assert-WlbCondition ($expiry -gt [DateTimeOffset]::UtcNow) 'Approval expired'
$manifestPath = Join-Path $script:WlbRoot 'manifests\draft\POC0-CALIBRATION-001.json'
$graphPath = Join-Path $script:WlbRoot 'workflows\draft\poc0-calibration.api.json'
$lockPath = Join-Path $script:WlbRoot 'policy\runtime-lock.json'
$policyPath = Join-Path $script:WlbRoot 'policy\executor-policy.json'
Assert-WlbCondition ($approval.manifest_sha256 -ceq (Get-WlbHash $manifestPath)) 'Approval/manifest mismatch'
Assert-WlbCondition ($approval.graph_sha256 -ceq (Get-WlbHash $graphPath)) 'Approval/graph mismatch'
Assert-WlbCondition ($approval.runtime_lock_sha256 -ceq (Get-WlbHash $lockPath)) 'Approval/runtime mismatch'
Assert-WlbCondition ($approval.policy_sha256 -ceq (Get-WlbHash $policyPath)) 'Approval/policy mismatch'

# This intentionally remains an unconditional refusal, even with a supplied file.
# The next implementation must implement atomic consumption BEFORE one POST,
# engine locking, live budgets, owned cancellation and uncertain-state recovery.
throw 'BLOCKED: G4/G5 remain closed. Atomic one-use consumption, engine lock, trusted runtime/preflight, resource watchdog and scoped submit/cancel adapter are NOT_IMPLEMENTED. No POST /prompt has been made.'
