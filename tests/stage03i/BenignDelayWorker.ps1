#requires -Version 7.6
param($Mailbox,[string]$WorkerIdentity,[string]$ClockId,[ValidateRange(100,3000)][int]$DelayMs)
# Naturally completing test runspace; no subprocess or process control.
. 'D:\WHAT-LIES-BTWN-PRODUCTION-OS\core\Wlb.TelemetryWorker.ps1'
$observed=Get-WlbPassiveProcessObservation $PID
if((Get-WlbWorkerObservationFingerprint $observed) -cne $WorkerIdentity){throw 'Test worker identity mismatch'}
$null=$Mailbox.TryHeartbeat([WlbSupervision.Heartbeat]::new($WorkerIdentity,$ClockId,1,(Get-WlbSupervisorMonotonicMs),$false))
[Threading.Thread]::Sleep($DelayMs) # Finite injected blocked query, not a hung real provider.
[pscustomobject]@{completed_naturally=$true;delay_ms=$DelayMs;worker_observation=$observed;provider_query_simulated=$true;real_process_launched=$false;real_process_stopped=$false}
