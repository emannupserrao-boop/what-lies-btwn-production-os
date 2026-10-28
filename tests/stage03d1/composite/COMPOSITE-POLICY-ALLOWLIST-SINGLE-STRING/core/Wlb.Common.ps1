#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:WlbRoot = 'D:\WHAT-LIES-BTWN-PRODUCTION-OS\tests\stage03d1\composite\COMPOSITE-POLICY-ALLOWLIST-SINGLE-STRING'

function Assert-WlbCondition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "BLOCKED: $Message" }
}

function Initialize-WlbLinkInspector {
    # Future invocation only. No external executable; Windows read-only handle query.
    if ($null -eq ('WlbPrep.NativeFile' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace WlbPrep {
    [StructLayout(LayoutKind.Sequential)]
    public struct FileInformation {
        public uint Attributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME CreationTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastAccessTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWriteTime;
        public uint VolumeSerial, SizeHigh, SizeLow, NumberOfLinks, IndexHigh, IndexLow;
    }
    public static class NativeFile {
        [DllImport("kernel32.dll", SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetFileInformationByHandle(
            SafeFileHandle handle, out FileInformation information);
    }
}
'@
    }
}

function Assert-WlbSingleLink {
    param([string]$Path)
    Initialize-WlbLinkInspector
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $info = New-Object WlbPrep.FileInformation
        $ok = [WlbPrep.NativeFile]::GetFileInformationByHandle($stream.SafeFileHandle, [ref]$info)
        Assert-WlbCondition $ok "Cannot inspect hardlink count: $Path"
        Assert-WlbCondition ($info.NumberOfLinks -eq 1) "Hardlink rejected: $Path"
    } finally { $stream.Dispose() }
}

function Assert-WlbPath {
    param([string]$Path, [switch]$MustExist, [switch]$MustBeAbsent, [switch]$File)
    Assert-WlbCondition (-not [string]::IsNullOrWhiteSpace($Path)) 'Empty path'
    Assert-WlbCondition ($Path -notmatch '(^|[\\/])\.\.?([\\/]|$)') 'Dot/traversal segment rejected'
    Assert-WlbCondition ($Path -notmatch '[*?]') 'Wildcard rejected'
    Assert-WlbCondition ($Path -match '^[Dd]:[\\/]') 'Only absolute D: paths permitted'
    Assert-WlbCondition ($Path.Substring(2) -notmatch ':') 'Alternate stream rejected'
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $prefix = $script:WlbRoot + '\'
    Assert-WlbCondition (($full -eq $script:WlbRoot) -or $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) 'Path outside authorized root'
    $cursor = $full
    while (-not [string]::IsNullOrEmpty($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            Assert-WlbCondition (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "Reparse point rejected: $cursor"
            if (-not $item.PSIsContainer) { Assert-WlbSingleLink $cursor }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
    if ($MustExist) { Assert-WlbCondition (Test-Path -LiteralPath $full) "Missing path: $full" }
    if ($MustBeAbsent) { Assert-WlbCondition (-not (Test-Path -LiteralPath $full)) "Existing destination rejected: $full" }
    if ($File) { Assert-WlbCondition ([IO.File]::Exists($full)) "Expected file: $full" }
    return $full
}

function Get-WlbHash {
    param([string]$Path)
    $checked = Assert-WlbPath $Path -MustExist -File
    return (Get-FileHash -LiteralPath $checked -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-WlbJsonElement {
    param($Element, [int]$Depth = 0)
    Assert-WlbCondition ($Depth -le 64) 'JSON nesting exceeds limit'
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($property in $Element.EnumerateObject()) {
            Assert-WlbCondition ($seen.Add($property.Name)) "Duplicate/case-colliding JSON key: $($property.Name)"
            Assert-WlbJsonElement $property.Value ($Depth + 1)
        }
    } elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        foreach ($value in $Element.EnumerateArray()) { Assert-WlbJsonElement $value ($Depth + 1) }
    }
}

function Read-WlbJson {
    param([string]$Path)
    $checked = Assert-WlbPath $Path -MustExist -File
    Assert-WlbCondition ((Get-Item -LiteralPath $checked).Length -le 1048576) 'JSON file exceeds 1 MiB'
    $raw = [IO.File]::ReadAllText($checked)
    $document = [System.Text.Json.JsonDocument]::Parse([string]$raw)
    try { Assert-WlbJsonElement $document.RootElement } finally { $document.Dispose() }
    return ($raw | ConvertFrom-Json -AsHashtable -Depth 64)
}

function Assert-WlbKeys {
    param($Object, [string[]]$Expected, [string]$Context)
    Assert-WlbCondition ($Object -is [Collections.IDictionary]) "Expected JSON object: $Context"
    Assert-WlbCondition ($Object.Count -eq $Expected.Count) "Unexpected key count: $Context"
    foreach ($key in $Expected) {
        Assert-WlbCondition ($Object.Contains($key)) "Missing key $key in $Context"
        Assert-WlbCondition (@($Object.Keys | Where-Object { $_ -ceq $key }).Count -eq 1) "Key case mismatch: $Context/$key"
    }
}

# Stage03D-1 static contracts only. Values stay untyped at the parameter boundary:
# a [bool], [int] or [string] parameter would coerce the input before validation.
function Assert-WlbJsonType {
    param($Value, [ValidateSet('Integer','Boolean','String','Array','StringArray','Null')][string]$Type, [string]$Context)
    $valid = switch ($Type) {
        'Integer' { ($Value -is [int]) -or ($Value -is [long]) }
        'Boolean' { $Value -is [bool] }
        'String' { $Value -is [string] }
        'Array' { ($Value -is [array]) -and ($Value.Rank -eq 1) }
        'StringArray' {
            $arrayValid = ($Value -is [array]) -and ($Value.Rank -eq 1)
            if ($arrayValid) {
                foreach ($element in $Value) {
                    if ($element -isnot [string]) { $arrayValid = $false; break }
                }
            }
            $arrayValid
        }
        'Null' { $null -eq $Value }
    }
    Assert-WlbCondition $valid "Expected JSON $Type at $Context"
}

function Assert-WlbObjectContract {
    param($Object, [Collections.IDictionary]$Contract, [string]$Context)
    Assert-WlbKeys $Object @($Contract.Keys) $Context
    foreach ($key in $Contract.Keys) {
        $childContext = "$Context/$key"
        if ($Contract[$key] -is [Collections.IDictionary]) {
            Assert-WlbObjectContract $Object[$key] $Contract[$key] $childContext
        } else {
            Assert-WlbJsonType -Value $Object[$key] -Type $Contract[$key] -Context $childContext
        }
    }
}

function Assert-WlbPoc0Graph {
    param($Graph)
    $contract = @{
        '1' = @{ class_type='String'; inputs=@{ width='Integer'; height='Integer'; batch_size='Integer'; color='Integer' } }
        '2' = @{ class_type='String'; inputs=@{ images='Array'; filename_prefix='String' } }
    }
    Assert-WlbObjectContract $Graph $contract 'graph'
    Assert-WlbCondition ($Graph['1'].class_type -ceq 'EmptyImage') 'Wrong source node'
    Assert-WlbCondition ($Graph['2'].class_type -ceq 'SaveImage') 'Wrong output node'
    Assert-WlbCondition ($Graph['1'].inputs.width -eq 640 -and $Graph['1'].inputs.height -eq 360 -and $Graph['1'].inputs.batch_size -eq 1 -and $Graph['1'].inputs.color -eq 3368601) 'Calibration parameters changed'
    $link = $Graph['2'].inputs.images
    Assert-WlbCondition ($link.Count -eq 2) 'Wrong image link length'
    Assert-WlbJsonType -Value $link[0] -Type String -Context 'graph/2/inputs/images/0'
    Assert-WlbJsonType -Value $link[1] -Type Integer -Context 'graph/2/inputs/images/1'
    Assert-WlbCondition ($link[0] -ceq '1' -and $link[1] -eq 0) 'Wrong image link'
    Assert-WlbCondition ($Graph['2'].inputs.filename_prefix -ceq 'POC0-CALIBRATION-001/calibration') 'Output prefix changed'
}

function Assert-WlbExecutorPolicy {
    param($Policy)
    # Closed shape for the existing PREPARATION policy, including nested objects.
    # Validating these declarations does not implement their operational controls.
    $contract = @{
        schema_version='String'; root='String'; gate_authorized='String'; execution_enabled='Boolean'
        endpoint='String'; allowed_submit_method='String'; allowed_submit_route='String'; post_is_dry_run='Boolean'
        allowed_nodes='StringArray'; allowed_job_id='String'; max_active_jobs='Integer'; auto_retry='Boolean'
        approval=@{
            issuer='String'; must_exist='Boolean'; must_be_unexpired='Boolean'; one_use='Boolean'
            bindings='StringArray'; consume_before_submit='Boolean'; atomic_consumption_implementation='String'
            on_uncertain_submit='String'; approval_creation_by_launcher='Boolean'
        }
        deny='StringArray'
        path_policy=@{
            canonical_absolute_root_only='Boolean'; reject_traversal='Boolean'; reject_reparse_points='Boolean'
            reject_hardlinks='Boolean'; reject_alternate_streams='Boolean'; reject_existing_job_output='Boolean'
            no_overwrite='Boolean'; future_writes='String'; toctou_enforcement='String'; quarantine_scope='String'
        }
        budget=@{
            min_available_ram_gib='Integer'; min_commit_headroom_gib='Integer'; max_incremental_commit_gib='Integer'
            max_process_private_gib='Integer'; max_incremental_vram_gib='Integer'; startup_timeout_seconds='Integer'
            job_timeout_seconds='Integer'; output_log_cap_mib='Integer'
        }
        monitor=@{
            implementation='String'; budget_kind='String'; missing_or_stale_telemetry='String'; gpu_exclusivity='String'
            foreign_gpu_jobs='String'; polling_interval=@{status='String'; value='Null'; reason='String'}
        }
        future_runtime=@{
            python_candidate='String'; python_execution_authorized='Boolean'; main_candidate='String'; snapshot_exists='Boolean'
            working_directory='String'; cli='StringArray'; actual_temp_subdirectory='String'; gpu_only_scope='String'
            cache_redirects='String'; startup_or_import_validation='String'
        }
        logging=@{
            local_only='Boolean'; no_tokens_or_credentials='Boolean'; no_external_upload='Boolean'
            output_embedded_prompt_metadata='Boolean'; preserve_failure_evidence='Boolean'
        }
        security_limitations=@{
            os_sandbox='Boolean'; network_egress_enforcement='Boolean'; same_windows_account_is_strong_isolation='Boolean'
            offline_flag_is_complete_firewall='Boolean'; custom_node_import_trust_boundary='Boolean'; access_control_validation='String'
        }
    }
    Assert-WlbObjectContract $Policy $contract 'policy'
    Assert-WlbCondition ($Policy.allowed_nodes.Count -eq 2 -and $Policy.allowed_nodes[0] -ceq 'EmptyImage' -and $Policy.allowed_nodes[1] -ceq 'SaveImage') 'Node allowlist mismatch'
}
