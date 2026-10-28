#requires -Version 7.6
param($Mailbox,[string]$WorkerIdentity,[string]$ClockId,[long]$StartedMs,[ValidateRange(1,4)][int]$MaxTicks)
. 'D:\WHAT-LIES-BTWN-PRODUCTION-OS\core\Wlb.TelemetryWorker.ps1'
$state=New-WlbPreparedWorkerState $WorkerIdentity $ClockId $PID $StartedMs
for($i=0;$i -lt $MaxTicks;$i++){
 if($i -gt 0){$due=$state.last_fast_ms+500;$delay=$due-(Get-WlbSupervisorMonotonicMs);if($delay -gt 0){Start-Sleep -Milliseconds $delay}}
 Invoke-WlbPreparedWorkerTick $state $Mailbox
 if($state.failed){break}
}
[pscustomobject]@{completed_naturally=$true;failed=$state.failed;failure=$state.failure;sequence=$state.sequence;slow_sequence=$state.slow_sequence;heartbeat_sequence=$state.heartbeat_sequence;operational_parameters_bound=$false;runtime_started=$false}
