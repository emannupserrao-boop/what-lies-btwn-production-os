# Read-only source/dependency identity inventory. NO snapshot/source copy, import or Python execution.
#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$Source='D:\Musicas\Bitter-End-Visual-Local\ComfyUI'
$Site='D:\Musicas\Bitter-End-Visual-Local\.venv\Lib\site-packages'
function Write-New([string]$Path,[string]$Text){
    if(-not $Path.StartsWith($Root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Outside root'}
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($Text)
    $mode=if([IO.File]::Exists($Path)){[IO.FileMode]::Truncate}else{[IO.FileMode]::CreateNew}
    $s=[IO.File]::Open($Path,$mode,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$s.Write($bytes,0,$bytes.Length);$s.Flush($true)}finally{$s.Dispose()}
}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
. (Join-Path $Root 'core\Wlb.Common.ps1')
$files=[Collections.Generic.List[object]]::new()
$excluded=[Collections.Generic.List[string]]::new()
function Include-File($Item,[string]$Group){
    if($Item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw ('Included reparse point: '+$Item.FullName)}
    if($Item.Length -gt 2MB){throw 'Unexpected large source file; bounded proposal stops'}
    Assert-WlbSingleLink $Item.FullName
    $relative=$Item.FullName.Substring($Source.Length+1)
    $files.Add([pscustomobject]@{group=$Group;relative_path=$relative;source=$Item.FullName;planned_destination=Join-Path (Join-Path $Root 'runtimes\core\ComfyUI') $relative;bytes=$Item.Length;sha256=Hash $Item.FullName;license_evidence='Root LICENSE contains GNU GPL v3 text; per-file exceptions not independently certified';dependency_risk='STATIC_ONLY; imports, native libraries, configuration and startup side effects RUNTIME_NOT_VERIFIED'})
}
foreach($relative in @('main.py','nodes.py','server.py','execution.py','folder_paths.py','latent_preview.py','node_helpers.py','comfyui_version.py','protocol.py','cuda_malloc.py','hook_breaker_ac10a0.py','LICENSE','requirements.txt','pyproject.toml')){
    Include-File (Get-Item -LiteralPath (Join-Path $Source $relative)) 'root-startup-and-provenance'
}
$groups=@('comfy','comfy_execution','comfy_api','comfy_config','comfy_extras','app','api_server','middleware','utils','alembic_db')
$denyNames=@('.git','custom_nodes','comfy_api_nodes','cache','caches','__pycache__','tests','tests-unit','credentials','configs')
# Root models/input/output/user/temp are excluded by the root-directory allowlist.
# Nested comfy/ldm/models and comfy_api/input are Python SOURCE packages, not weights/input assets.
foreach($group in $groups){
    $pending=[Collections.Generic.Stack[string]]::new();$pending.Push((Join-Path $Source $group))
    while($pending.Count){
        $directory=$pending.Pop();$di=Get-Item -LiteralPath $directory -Force
        if($di.Attributes -band [IO.FileAttributes]::ReparsePoint){$excluded.Add($directory);continue}
        foreach($item in Get-ChildItem -LiteralPath $directory -Force){
            if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){$excluded.Add($item.FullName);continue}
            if($item.PSIsContainer){if($item.Name -notin $denyNames){$pending.Push($item.FullName)}else{$excluded.Add($item.FullName)}}
            elseif($item.Extension -in @('.py','.pyi')){Include-File $item $group}
        }
        if($files.Count -gt 2000 -or ($files | ForEach-Object {$_.bytes} | Measure-Object -Sum).Sum -gt 64MB){throw 'Source proposal exceeds explicit 2000-file / 64MiB bound'}
    }
}
$ordered=@($files | Sort-Object relative_path)
$csvPath=Join-Path $Root 'spec\G4_SNAPSHOT_COPY_INVENTORY.csv'
Write-New $csvPath (($ordered | ConvertTo-Csv -NoTypeInformation) -join "`n")
$groupSummary=@($ordered | Group-Object group | ForEach-Object {[ordered]@{group=$_.Name;file_count=$_.Count;measured_bytes=($_.Group | ForEach-Object {$_.bytes} | Measure-Object -Sum).Sum;source=Join-Path $Source $(if($_.Name -eq 'root-startup-and-provenance'){''}else{$_.Name});planned_destination=Join-Path (Join-Path $Root 'runtimes\core\ComfyUI') $(if($_.Name -eq 'root-startup-and-provenance'){''}else{$_.Name});inclusion='Exact named root files; .py/.pyi only under explicit code directories';exclusions='No weights/custom/provider nodes/.git/state/cache/credentials/links; optional config/data excluded';license='Root GPLv3 LICENSE evidence; per-file/license distribution review still required';risk='Import closure and optional database configuration not validated by runtime'}})
$summary=[ordered]@{source=$Source;destination=Join-Path $Root 'runtimes\core\ComfyUI';authorization='DESIGN_ONLY_NO_COPY';file_count=$ordered.Count;measured_bytes=($ordered | ForEach-Object {$_.bytes} | Measure-Object -Sum).Sum;inventory_sha256=Hash $csvPath;max_files=2000;max_bytes=67108864;groups=$groupSummary;skipped_links_or_excluded_dirs=@($excluded);snapshot_created=$false;runtime_validation='RUNTIME_NOT_VERIFIED';config_gap='alembic.ini and any other config/data are excluded pending necessity and credential-free template review; this exact code candidate is not certified runnable';provider_exclusion='comfy_api_nodes excluded; CLI --offline and --disable-partner-nodes are source-supported; no claim of Python egress enforcement'}
Write-New (Join-Path $Root 'tests\stage03d2\evidence\snapshot-proposal-summary.json') (ConvertTo-Json -InputObject $summary -Depth 30)
# Relevant distribution METADATA/WHEEL/RECORD text fingerprints identify installed metadata only.
# RECORD hash is NOT verification of every binary listed in RECORD. No package code is imported/read.
$names=@('torch','torchaudio','torchvision','transformers','numpy','pillow','safetensors','aiohttp','yarl','pyyaml','psutil','comfy_aimdo','comfy_kitchen','comfyui_frontend_package','alembic','sqlalchemy')
$dependencies=@(foreach($name in $names){
    $directories=@(Get-ChildItem -LiteralPath $Site -Directory -Filter ($name+'-*.dist-info'))
    if($directories.Count -ne 1){[ordered]@{name=$name;status='MISSING_OR_AMBIGUOUS';metadata=@()};continue}
    $d=$directories[0];$metadataPath=Join-Path $d.FullName 'METADATA';$header=Get-Content -LiteralPath $metadataPath | Select-String -Pattern '^(Name|Version|License|License-Expression):' | Select-Object -First 5
    [ordered]@{name=$name;status='STATIC_METADATA_ONLY';header=@($header | ForEach-Object {$_.Line});metadata=@(foreach($f in @('METADATA','WHEEL','RECORD')){$p=Join-Path $d.FullName $f;if(Test-Path -LiteralPath $p){[ordered]@{path=$p;bytes=(Get-Item -LiteralPath $p).Length;sha256=Hash $p}}});runtime_compatibility='RUNTIME_NOT_VERIFIED'}
})
$dependencyPath=Join-Path $Root 'spec\G4_DEPENDENCY_METADATA.json'
Write-New $dependencyPath (ConvertTo-Json -InputObject $dependencies -Depth 30)
$python='D:\Musicas\Bitter-End-Visual-Local\.venv\Scripts\python.exe'
Assert-WlbSingleLink $python
$identity=[ordered]@{
    schema_version='wlb-startup-identity/0.1';purpose='STATIC_CANDIDATE_NOT_EXECUTION_AUTHORITY'
    snapshot=[ordered]@{path=Join-Path $Root 'runtimes\core\ComfyUI';status='NOT_CREATED';exists=$false;source=$Source;proposal_inventory=Join-Path $Root 'spec\G4_SNAPSHOT_COPY_INVENTORY.csv';proposal_sha256=Hash $csvPath;file_count=$ordered.Count;bytes=[long]$summary.measured_bytes;actual_inventory_sha256=$null}
    python=[ordered]@{path=$python;sha256=Hash $python;fingerprint_kind='RAW_ENTRY_EXECUTABLE_ONLY';runtime_validation='RUNTIME_NOT_VERIFIED';bootstrap_and_standard_library_identity='NOT_VERIFIED'}
    dependencies=[ordered]@{metadata_path=$dependencyPath;metadata_sha256=Hash $dependencyPath;status='STATIC_METADATA_ONLY';binary_files_verified=$false;runtime_compatibility='RUNTIME_NOT_VERIFIED'}
    main_path=Join-Path $Root 'runtimes\core\ComfyUI\main.py';working_directory=Join-Path $Root 'runtimes\core'
    cli_source_evidence=[ordered]@{path=Join-Path $Source 'comfy\cli_args.py';sha256=Hash (Join-Path $Source 'comfy\cli_args.py');supported_partner_disable='--disable-partner-nodes';offline_disables_partners_in_source=$true;egress_firewall=$false}
}
Write-New (Join-Path $Root 'policy\startup-identity.json') (ConvertTo-Json -InputObject $identity -Depth 30)
$policy=[ordered]@{
    schema_version='wlb-startup-policy/0.1';boundary_mode='SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0';preparation_state='PREPARED'
    real_startup_enabled=$false;gpu_jobs_enabled=$false;auto_retry=$false;max_active_startups=1
    listen_address='127.0.0.1';port=8189;required_gate='G4_HUMAN_STARTUP_ONLY';consent_status='ABSENT'
    human_parameters=[ordered]@{operator_identity=@{status='UNKNOWN';value=$null};cpu_budget=@{status='UNKNOWN';value=$null};polling_cadence_ms=@{status='UNKNOWN';value=$null};telemetry_freshness_ms=@{status='UNKNOWN';value=$null}}
    budget=(Read-WlbJson (Join-Path $Root 'policy\executor-policy.json')).budget
    live_adapters=[ordered]@{process_start='NOT_IMPLEMENTED_DISABLED';process_stop='NOT_IMPLEMENTED_DISABLED';trusted_consent='NOT_IMPLEMENTED';ram_commit='NOT_VERIFIED';private_bytes='NOT_VERIFIED';gpu_attribution='NOT_VERIFIED';port_ownership='NOT_VERIFIED';aggregate_disk='NOT_VERIFIED'}
    security_claims=[ordered]@{strong_operator_executor_isolation=$false;filesystem_sandbox=$false;network_egress_block=$false;text_identity_is_independent_authentication=$false;creative_agent_execution_authority=$false}
}
Write-New (Join-Path $Root 'policy\startup-policy.json') (ConvertTo-Json -InputObject $policy -Depth 30)
[ordered]@{proposal=$summary;python_entry_sha256=$identity.python.sha256;dependency_distributions=$dependencies.Count;source_copied=$false;python_run=$false} | ConvertTo-Json -Depth 30
