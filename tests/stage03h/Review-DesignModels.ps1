#requires -Version 7.6
# Pure review models. Accept SIMULATED_TEST_ONLY fixtures only; no operational
# adapter, policy binding, consent, callback, process control or GPU exception.
function Test-HProxyReviewModel($Fixture){
 $reasons=[Collections.Generic.List[string]]::new()
 try{
  if($Fixture.kind -cne 'SIMULATED_TEST_ONLY'){throw 'REAL_OR_UNKNOWN_INPUT_DENIED'}
  foreach($key in @('now_ms','baseline_acquired_ms','sample_acquired_ms','available_ram_bytes','commit_headroom_bytes','baseline_commit_bytes','sample_commit_bytes','private_bytes','baseline_vram_bytes','sample_vram_bytes','aggregate_bytes')){
   if($Fixture[$key] -isnot [long] -and $Fixture[$key] -isnot [int]){throw "MISSING_OR_NONINTEGER:$key"};if($Fixture[$key] -lt 0){throw "NEGATIVE:$key"}
  }
  if($Fixture.scope -cne 'G4_STARTUP_NO_MODELS' -or $Fixture.model_or_job_requested){$reasons.Add('SCOPE_DENIED')}
  if(-not $Fixture.valid_global_baseline -or -not $Fixture.data_consistent){$reasons.Add('GLOBAL_DATA_MISSING_OR_INCONSISTENT')}
  if($Fixture.now_ms -lt $Fixture.sample_acquired_ms -or $Fixture.sample_acquired_ms -lt $Fixture.baseline_acquired_ms){$reasons.Add('CLOCK_INCONSISTENT')}
  if($Fixture.now_ms-$Fixture.sample_acquired_ms -gt 2000){$reasons.Add('RECEIPT_PROXY_STALE')}
  if($Fixture.now_ms-$Fixture.baseline_acquired_ms -ge 120000){$reasons.Add('DEADLINE')}
  if(-not $Fixture.provider_proxy_explicitly_assumed_for_simulation){$reasons.Add('PROVIDER_AGE_DECISION_PENDING')}
  if(-not $Fixture.actor_inventory_known -or -not $Fixture.activity_classified -or $Fixture.heavy_gpu_work){$reasons.Add('UNKNOWN_CONTENTION_OR_FOREIGN_GPU_WORK')}
  if($Fixture.actors_changed){$reasons.Add('BACKGROUND_ACTOR_CHANGE_REPORT_AND_BLOCK')}
  if(-not $Fixture.process_identity_matches -or -not $Fixture.port_identity_known){$reasons.Add('PROCESS_OR_PORT_UNKNOWN')}
  if($Fixture.available_ram_bytes -lt 8GB){$reasons.Add('RAM_BELOW_8')}
  if($Fixture.commit_headroom_bytes -lt 10GB){$reasons.Add('HEADROOM_BELOW_10')}
  $dc=$Fixture.sample_commit_bytes-$Fixture.baseline_commit_bytes;$dv=$Fixture.sample_vram_bytes-$Fixture.baseline_vram_bytes
  if($dc -lt 0 -or $dv -lt 0){$reasons.Add('GLOBAL_MOVEMENT_UNATTRIBUTABLE')}
  if($dc -gt 4GB){$reasons.Add('COMMIT_OVER_4')};if($Fixture.private_bytes -gt 4GB){$reasons.Add('PRIVATE_OVER_4')}
  if($dv -gt 2GB){$reasons.Add('GLOBAL_VRAM_OVER_2')};if($Fixture.aggregate_bytes -gt 256MB){$reasons.Add('DISK_OVER_256')}
 }catch{$reasons.Add($_.Exception.Message)}
 return @{state=$(if($reasons.Count){'BLOCKED_SIMULATION'}else{'SIMULATED_THRESHOLDS_ONLY'});reasons=@($reasons);authorized_to_execute=$false;consent_created=$false;rtx_pid_attribution_claim=$false;global_proxy_enabled=$false;restart_allowed=$false}
}
function Test-HSupervisorReviewModel($State){
 $reasons=@()
 if($State.kind -cne 'SIMULATED_TEST_ONLY'){$reasons+=@('REAL_INPUT_DENIED')}
 if($State.now_ms -lt $State.previous_now_ms){$reasons+=@('SUPERVISOR_CLOCK_REVERSED')}
 if($State.now_ms-$State.startup_started_ms -ge 120000){$reasons+=@('DEADLINE_EXPIRED')}
 if($State.sampler_failed){$reasons+=@('SAMPLER_FAILED')}
 if($State.last_acquired_ms -gt $State.now_ms -or $State.now_ms-$State.last_acquired_ms -gt 2000){$reasons+=@('TELEMETRY_STALE_OR_FUTURE')}
 if($State.queue_length -gt 1 -or $State.sequence -le $State.previous_sequence){$reasons+=@('QUEUE_OR_SEQUENCE_INVALID')}
 return @{state=$(if($reasons.Count){'BLOCKED_SIMULATION'}else{'OBSERVE_SIMULATION'});reasons=$reasons;real_sampler_called=$false;real_cancellation=$false;real_process_killed=$false;runtime_watchdog_verified=$false}
}
