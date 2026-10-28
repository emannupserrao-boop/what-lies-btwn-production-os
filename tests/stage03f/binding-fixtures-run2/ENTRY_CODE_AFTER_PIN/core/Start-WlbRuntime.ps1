#requires -Version 7.4
[CmdletBinding()]
param([ValidateSet('Plan','Admission')][string]$Mode='Plan')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Wlb.Startup.ps1')
# No external path, URL, executable, shell fragment, CLI, approval or callback parameter.
$null=& (Join-Path $PSScriptRoot 'Test-WlbManifest.ps1') -Mode StaticReview
$policyPath=Join-Path $script:WlbRoot 'policy\startup-policy.json'
$identityPath=Join-Path $script:WlbRoot 'policy\startup-identity.json'
$policy=Read-WlbJson $policyPath;$identity=Read-WlbJson $identityPath
Assert-WlbStagedRuntimeLock (Read-WlbJson (Join-Path $script:WlbRoot 'policy\runtime-lock.json')) $identity
$plan=Get-WlbFixedStartupPlan $policy $identity (Get-WlbHash $policyPath) (Get-WlbHash (Join-Path $script:WlbRoot 'policy\runtime-lock.json'))
$snapshot=Test-WlbStagedSnapshotContent $identity
$evidence=@{policy_sha256=$plan.policy_sha256;runtime_lock_sha256=$plan.runtime_lock_sha256;snapshot_exists=$identity.snapshot.exists;snapshot_bytes_verified=$snapshot.content_verified;python_sha256=$identity.python.sha256;dependency_identity_verified=$false;port_identity_known=$false;port_occupied=$false;monitor_provider_ready=$false;prior_reservation=$false}
$admission=Test-WlbStartupAdmission $policy $plan $evidence $null
if($Mode -eq 'Admission'){throw ('BLOCKED: '+($admission.reasons -join '; '))}
[pscustomobject]@{preparation='PREPARED';snapshot_state=$snapshot.snapshot_state;snapshot_integrity=$snapshot;runtime='NOT_VERIFIED';human='WAITING_HUMAN';state=$admission.state;plan=$plan;admission=$admission;startup_performed=$false}
# Stage03F preserves no reachable real execution path even with verified staged bytes.

# OWN TEST TAMPER
