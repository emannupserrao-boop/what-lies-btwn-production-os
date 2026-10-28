#requires -Version 7.4
# Static startup contracts and pure decisions. NO process launch/kill, socket, REST or consent creation.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Wlb.Common.ps1')

function Assert-WlbStartupPolicy {
    param($Policy,[switch]$MockOnly)
    $contract=@{
        schema_version='String';boundary_mode='String';preparation_state='String';real_startup_enabled='Boolean'
        gpu_jobs_enabled='Boolean';auto_retry='Boolean';max_active_startups='Integer';listen_address='String';port='Integer'
        required_gate='String';consent_status='String'
        human_parameters=@{operator_identity=@{status='String';value='Null'};cpu_budget=@{status='String';value='Null'};polling_cadence_ms=@{status='String';value='Null'};telemetry_freshness_ms=@{status='String';value='Null'}}
        budget=@{min_available_ram_gib='Integer';min_commit_headroom_gib='Integer';max_incremental_commit_gib='Integer';max_process_private_gib='Integer';max_incremental_vram_gib='Integer';startup_timeout_seconds='Integer';job_timeout_seconds='Integer';output_log_cap_mib='Integer'}
        live_adapters=@{process_start='String';process_stop='String';trusted_consent='String';ram_commit='String';private_bytes='String';gpu_attribution='String';port_ownership='String';aggregate_disk='String'}
        security_claims=@{strong_operator_executor_isolation='Boolean';filesystem_sandbox='Boolean';network_egress_block='Boolean';text_identity_is_independent_authentication='Boolean';creative_agent_execution_authority='Boolean'}
    }
    # In-memory test values have a distinct status; they cannot be deployed policy.
    if($MockOnly){
        $copy=$Policy | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable
        foreach($key in $copy.human_parameters.Keys){$copy.human_parameters[$key].value=$null}
        Assert-WlbObjectContract $copy $contract 'startup-policy'
    }else{
        Assert-WlbObjectContract $Policy $contract 'startup-policy'
        foreach($key in $Policy.human_parameters.Keys){Assert-WlbCondition ($Policy.human_parameters[$key].status -ceq 'UNKNOWN') "Operational parameter not authorized in Stage03D2: $key"}
    }
    Assert-WlbCondition ($Policy.schema_version -ceq 'wlb-startup-policy/0.1') 'Startup policy version'
    Assert-WlbCondition ($Policy.boundary_mode -ceq 'SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0') 'Supervised boundary mismatch'
    Assert-WlbCondition (-not $Policy.real_startup_enabled -and -not $Policy.gpu_jobs_enabled -and -not $Policy.auto_retry) 'Real startup/jobs/retry must remain disabled'
    Assert-WlbCondition ($Policy.max_active_startups -eq 1 -and $Policy.listen_address -ceq '127.0.0.1' -and $Policy.port -eq 8189) 'Startup concurrency/listener mismatch'
    Assert-WlbCondition ($Policy.required_gate -ceq 'G4_HUMAN_STARTUP_ONLY' -and $Policy.consent_status -ceq 'ABSENT') 'Real consent must remain absent'
    foreach($value in $Policy.security_claims.Values){Assert-WlbCondition (-not $value) 'Unsupported OS/authentication/security claim'}
    $caps=@{min_available_ram_gib=8;min_commit_headroom_gib=10;max_incremental_commit_gib=4;max_process_private_gib=4;max_incremental_vram_gib=2;startup_timeout_seconds=120;job_timeout_seconds=30;output_log_cap_mib=256}
    foreach($key in $caps.Keys){Assert-WlbCondition ($Policy.budget[$key] -eq $caps[$key]) "Startup cap changed: $key"}
}

function Assert-WlbStartupIdentity {
    param($Identity)
    $contract=@{
        schema_version='String';purpose='String';main_path='String';working_directory='String'
        snapshot=@{path='String';status='String';exists='Boolean';source='String';proposal_inventory='String';proposal_sha256='String';file_count='Integer';bytes='Integer';actual_inventory_sha256='Null'}
        python=@{path='String';sha256='String';fingerprint_kind='String';runtime_validation='String';bootstrap_and_standard_library_identity='String'}
        dependencies=@{metadata_path='String';metadata_sha256='String';status='String';binary_files_verified='Boolean';runtime_compatibility='String'}
        cli_source_evidence=@{path='String';sha256='String';supported_partner_disable='String';offline_disables_partners_in_source='Boolean';egress_firewall='Boolean'}
    }
    Assert-WlbObjectContract $Identity $contract 'startup-identity'
    foreach($value in @($Identity.python.sha256,$Identity.snapshot.proposal_sha256,$Identity.dependencies.metadata_sha256,$Identity.cli_source_evidence.sha256)){Assert-WlbCondition ($value -cmatch '^[a-f0-9]{64}$') 'Startup identity fingerprint missing/invalid'}
    Assert-WlbCondition (-not $Identity.snapshot.exists -and $Identity.snapshot.status -ceq 'NOT_CREATED' -and -not $Identity.dependencies.binary_files_verified -and -not $Identity.cli_source_evidence.egress_firewall) 'Source preparation cannot claim runtime/sandbox verification'
}

function Get-WlbFixedStartupPlan {
    param($Policy,$Identity,[string]$PolicyHash,[string]$RuntimeHash)
    Assert-WlbStartupPolicy $Policy
    Assert-WlbStartupIdentity $Identity
    Assert-WlbCondition ($Identity.schema_version -ceq 'wlb-startup-identity/0.1') 'Startup identity version'
    $base=Join-Path $script:WlbRoot 'runtimes\core'
    Assert-WlbCondition ($Identity.main_path -ceq (Join-Path $base 'ComfyUI\main.py')) 'Arbitrary main path denied'
    Assert-WlbCondition ($Identity.working_directory -ceq $base -and $Identity.snapshot.path -ceq (Join-Path $base 'ComfyUI')) 'Arbitrary startup namespace denied'
    # This one named existing venv is metadata only, never an arbitrary external executable.
    Assert-WlbCondition ($Identity.python.path -ceq 'D:\Musicas\Bitter-End-Visual-Local\.venv\Scripts\python.exe') 'Arbitrary Python candidate denied'
    $state=Join-Path $base 'state';$scratch=Join-Path $base 'scratch'
    $arguments=@('-B',$Identity.main_path,'--listen','127.0.0.1','--port','8189','--base-directory',$state,'--input-directory',(Join-Path $state 'input'),'--output-directory',(Join-Path $state 'output'),'--user-directory',(Join-Path $state 'user'),'--temp-directory',$scratch,'--disable-all-custom-nodes','--disable-partner-nodes','--offline','--disable-auto-launch','--disable-metadata','--cache-none','--gpu-only')
    $environment=[ordered]@{TEMP=$scratch;TMP=$scratch;PYTHONDONTWRITEBYTECODE='1';PYTHONNOUSERSITE='1';HF_HOME=(Join-Path $state 'cache\huggingface');HF_HUB_CACHE=(Join-Path $state 'cache\huggingface\hub');TRANSFORMERS_CACHE=(Join-Path $state 'cache\huggingface\transformers');TORCH_HOME=(Join-Path $state 'cache\torch');XDG_CACHE_HOME=(Join-Path $state 'cache');CUDA_CACHE_PATH=(Join-Path $state 'cache\cuda');MPLCONFIGDIR=(Join-Path $state 'cache\matplotlib');NUMBA_CACHE_DIR=(Join-Path $state 'cache\numba');HF_HUB_OFFLINE='1';TRANSFORMERS_OFFLINE='1'}
    foreach($path in @($base,$Identity.main_path,$state,$scratch,(Join-Path $scratch 'temp'))){$null=Assert-WlbPath $path}
    [pscustomobject]@{schema_version='wlb-startup-plan/0.1';state='PREPARED';boundary_mode=$Policy.boundary_mode;executable=$Identity.python.path;python_sha256=$Identity.python.sha256;main_path=$Identity.main_path;working_directory=$base;arguments=$arguments;environment=$environment;listen_address='127.0.0.1';port=8189;input_directory=(Join-Path $state 'input');output_directory=(Join-Path $state 'output');user_directory=(Join-Path $state 'user');temp_directory=(Join-Path $scratch 'temp');policy_sha256=$PolicyHash;runtime_lock_sha256=$RuntimeHash;real_execution_enabled=$false;runtime_validation='RUNTIME_NOT_VERIFIED';consent='ABSENT';no_egress_or_filesystem_sandbox_claim=$true}
}

function Test-WlbProcessIdentity {
    param($Expected,$Observed)
    try{
        $contract=@{process_id='Integer';creation_time_utc='String';image_path='String';image_sha256='String';owner_token='String'}
        Assert-WlbObjectContract $Expected $contract 'expected-process'
        Assert-WlbObjectContract $Observed $contract 'observed-process'
        foreach($p in @($Expected,$Observed)){
            Assert-WlbCondition ($p.process_id -gt 0 -and $p.owner_token -match '^[a-f0-9-]{36}$' -and $p.image_sha256 -match '^[a-f0-9]{64}$') 'Incomplete process identity'
            Assert-WlbCondition ($p.creation_time_utc -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}Z$') 'Exact process creation time required'
            $null=[DateTimeOffset]::ParseExact($p.creation_time_utc,"yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'",[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal)
            Assert-WlbCondition ($p.image_path -match '^[Dd]:\\' -and $p.image_path -notmatch '(^|[\\/])\.\.?([\\/]|$)|:.*:') 'Noncanonical process image path'
        }
        $match=$Expected.process_id -eq $Observed.process_id -and $Expected.creation_time_utc -ceq $Observed.creation_time_utc -and $Expected.image_path -ceq $Observed.image_path -and $Expected.image_sha256 -ceq $Observed.image_sha256 -and $Expected.owner_token -ceq $Observed.owner_token
        [pscustomobject]@{owned=$match;reason=$(if($match){'EXACT_OWNED_TUPLE'}else{'FOREIGN_OR_REUSED_PROCESS_ID'});runtime_observation_verified=$false}
    }catch{[pscustomobject]@{owned=$false;reason=$_.Exception.Message;runtime_observation_verified=$false}}
}

function Test-WlbPortOwnership {
    param($Expected,$ObservedProcess,$PortObservation)
    $owned=Test-WlbProcessIdentity $Expected $ObservedProcess
    try{
        Assert-WlbObjectContract $PortObservation @{known='Boolean';occupied='Boolean';listen_address='String';port='Integer';process_id='Integer'} 'port-observation'
        $ok=$owned.owned -and $PortObservation.known -and $PortObservation.occupied -and $PortObservation.listen_address -ceq '127.0.0.1' -and $PortObservation.port -eq 8189 -and $PortObservation.process_id -eq $Expected.process_id
        [pscustomobject]@{owned=$ok;reason=$(if($ok){'OWNED_PORT_TUPLE'}else{'UNKNOWN_OR_FOREIGN_PORT'});live_query_performed=$false}
    }catch{[pscustomobject]@{owned=$false;reason=$_.Exception.Message;live_query_performed=$false}}
}

function Test-WlbMockStopAuthority {
    param($Expected,$Observed,$Consent,[switch]$MockOnly)
    $owned=Test-WlbProcessIdentity $Expected $Observed
    $allowed=$MockOnly -and $owned.owned -and $null -ne $Consent -and $Consent.kind -ceq 'MOCK_ONLY' -and $Consent.scope -ceq 'G4_STARTUP_ONLY' -and $Consent.stop_owned_allowed -is [bool] -and $Consent.stop_owned_allowed -and $Consent.owner_token -ceq $Expected.owner_token
    [pscustomobject]@{allowed=$allowed;reason=$(if($allowed){'MOCK_OWNED_STOP_ONLY'}else{'FOREIGN_OR_UNAUTHORIZED_STOP_DENIED'});real_process_stop_enabled=$false}
}

function Test-WlbStartupAdmission {
    param($Policy,$Plan,$Evidence,$Consent,[switch]$MockOnly)
    $reasons=[Collections.Generic.List[string]]::new()
    try{
        Assert-WlbStartupPolicy $Policy -MockOnly:$MockOnly
        Assert-WlbObjectContract $Evidence @{policy_sha256='String';runtime_lock_sha256='String';snapshot_exists='Boolean';snapshot_bytes_verified='Boolean';python_sha256='String';dependency_identity_verified='Boolean';port_identity_known='Boolean';port_occupied='Boolean';monitor_provider_ready='Boolean';prior_reservation='Boolean'} 'startup-evidence'
        if($Plan.policy_sha256 -cne $Evidence.policy_sha256){$reasons.Add('POLICY_HASH_DIVERGENCE')}
        if($Plan.runtime_lock_sha256 -cne $Evidence.runtime_lock_sha256){$reasons.Add('RUNTIME_HASH_DIVERGENCE')}
        if(-not $Evidence.snapshot_exists -or -not $Evidence.snapshot_bytes_verified){$reasons.Add('SNAPSHOT_MISSING_OR_UNVERIFIED')}
        if($Plan.python_sha256 -notmatch '^[a-f0-9]{64}$' -or $Evidence.python_sha256 -cne $Plan.python_sha256){$reasons.Add('PYTHON_FINGERPRINT_MISSING_OR_DIVERGENT')}
        if(-not $Evidence.dependency_identity_verified){$reasons.Add('DEPENDENCY_IDENTITY_UNVERIFIED')}
        if(-not $Evidence.port_identity_known -or $Evidence.port_occupied){$reasons.Add('PORT_OCCUPIED_OR_UNKNOWN')}
        if(-not $Evidence.monitor_provider_ready){$reasons.Add('OPERATIONAL_MONITOR_NOT_READY')}
        if($Evidence.prior_reservation){$reasons.Add('PRIOR_RESERVATION_RECONCILE_NO_RESTART')}
        foreach($key in $Policy.human_parameters.Keys){
            if(-not $MockOnly -or $Policy.human_parameters[$key].status -cne 'INJECTED_TEST_ONLY' -or $null -eq $Policy.human_parameters[$key].value){$reasons.Add('HUMAN_PARAMETER_PENDING:'+ $key)}
        }
        if($null -eq $Consent){$reasons.Add('CONSENT_MISSING')}
        else{
            Assert-WlbObjectContract $Consent @{kind='String';scope='String';policy_sha256='String';runtime_lock_sha256='String';python_sha256='String';single_attempt='Boolean';stop_owned_allowed='Boolean';owner_token='String'} 'mock-consent'
            if(-not $MockOnly -or $Consent.kind -cne 'MOCK_ONLY' -or $Consent.scope -cne 'G4_STARTUP_ONLY' -or $Consent.policy_sha256 -cne $Plan.policy_sha256 -or $Consent.runtime_lock_sha256 -cne $Plan.runtime_lock_sha256 -or $Consent.python_sha256 -cne $Plan.python_sha256 -or -not $Consent.single_attempt){$reasons.Add('CONSENT_NOT_TRUSTED_OR_WRONG_BINDING')}
        }
        if(-not $MockOnly){$reasons.Add('REAL_ADAPTERS_AND_G4_AUTHORITY_DISABLED')}
    }catch{$reasons.Add($_.Exception.Message)}
    [pscustomobject]@{state=$(if($reasons.Count){'BLOCKED'}else{'FUTURE_G4_ELIGIBLE'});eligible_to_present_for_future_review=($reasons.Count -eq 0);authorized_to_execute=$false;mock_evidence=[bool]$MockOnly;reasons=@($reasons);runtime_compatibility='RUNTIME_NOT_VERIFIED';no_automatic_retry=$true}
}
