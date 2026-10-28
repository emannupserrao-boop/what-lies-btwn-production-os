#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:WlbRoot = 'D:\WHAT-LIES-BTWN-PRODUCTION-OS\tests\stage03c\composite-run2\COMPOSITE-POLICY-STRING-BUDGET'

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
    param([Collections.IDictionary]$Object, [string[]]$Expected, [string]$Context)
    Assert-WlbCondition ($Object.Count -eq $Expected.Count) "Unexpected key count: $Context"
    foreach ($key in $Expected) {
        Assert-WlbCondition ($Object.Contains($key)) "Missing key $key in $Context"
        Assert-WlbCondition (@($Object.Keys | Where-Object { $_ -ceq $key }).Count -eq 1) "Key case mismatch: $Context/$key"
    }
}
