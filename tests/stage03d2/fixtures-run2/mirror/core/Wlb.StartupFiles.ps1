#requires -Version 7.4
# Actual harmless mutex/file mechanics restricted to Stage03D2 TEST namespaces.
# Real startup evidence/approval namespaces are deliberately not writable through this module.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Wlb.Common.ps1')

function Assert-WlbStartupTestPath {
    param([string]$Path,[switch]$MustExist,[switch]$File)
    $full=Assert-WlbPath $Path -MustExist:$MustExist -File:$File
    $scope=Join-Path $script:WlbRoot 'tests\stage03d2'
    Assert-WlbCondition ($full.StartsWith($scope+'\',[StringComparison]::OrdinalIgnoreCase)) 'Startup file mechanics limited to own Stage03D2 tests'
    return $full
}

function Initialize-WlbStartupNative {
    if($null -eq ('WlbStartup.ReadOnlyNative' -as [type])){
        Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace WlbStartup {
 [StructLayout(LayoutKind.Sequential)] public struct Info {
  public uint Attributes;
  public System.Runtime.InteropServices.ComTypes.FILETIME Creation,Access,Write;
  public uint Volume,SizeHigh,SizeLow,Links,IndexHigh,IndexLow;
 }
 public static class ReadOnlyNative {
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFileW(string name,uint access,uint share,IntPtr security,uint creation,uint flags,IntPtr template);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle handle,out Info info);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetFinalPathNameByHandleW(SafeFileHandle handle,StringBuilder path,uint size,uint flags);
  public static SafeFileHandle OpenDirectory(string path){
   var h=CreateFileW(path,0x80000000,3,IntPtr.Zero,3,0x02200000,IntPtr.Zero);
   if(h.IsInvalid){h.Dispose();throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());}return h;
  }
  static Info Information(SafeFileHandle h){Info i;if(!GetFileInformationByHandle(h,out i))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());if((i.Attributes&0x400)!=0)throw new InvalidOperationException("Reparse handle rejected");return i;}
  public static string Identity(SafeFileHandle h){var i=Information(h);return i.Volume.ToString("X8")+":"+i.IndexHigh.ToString("X8")+i.IndexLow.ToString("X8");}
  public static uint LinkCount(SafeFileHandle h){return Information(h).Links;}
  public static string FinalPath(SafeFileHandle h){var b=new StringBuilder(32768);var n=GetFinalPathNameByHandleW(h,b,32768,0);if(n==0||n>=32768)throw new InvalidOperationException("Handle path unavailable");var p=b.ToString();if(p.StartsWith(@"\\?\"))p=p.Substring(4);return p;}
 }
}
'@
    }
}

function New-WlbTestPathGuard {
    param([string]$Path)
    $full=Assert-WlbStartupTestPath $Path
    Initialize-WlbStartupNative
    $directories=[Collections.Generic.List[string]]::new()
    $cursor=[IO.Path]::GetDirectoryName($full)
    while($cursor -and $cursor.StartsWith($script:WlbRoot,[StringComparison]::OrdinalIgnoreCase)){$directories.Add($cursor);if($cursor -eq $script:WlbRoot){break};$cursor=[IO.Path]::GetDirectoryName($cursor)}
    $handles=[Collections.Generic.List[object]]::new()
    try{
        for($i=$directories.Count-1;$i -ge 0;$i--){
            $directory=$directories[$i];$h=[WlbStartup.ReadOnlyNative]::OpenDirectory($directory)
            $actual=[WlbStartup.ReadOnlyNative]::FinalPath($h)
            if(-not $actual.Equals($directory,[StringComparison]::OrdinalIgnoreCase)){$h.Dispose();throw 'BLOCKED: Directory alias/replacement rejected'}
            $handles.Add([pscustomobject]@{handle=$h;path=$directory;identity=[WlbStartup.ReadOnlyNative]::Identity($h)})
        }
        [pscustomobject]@{path=$full;directories=@($handles)}
    }catch{foreach($item in $handles){$item.handle.Dispose()};throw}
}

function Close-WlbTestPathGuard {
    param($Guard)
    foreach($entry in $Guard.directories){$entry.handle.Dispose()}
}

function Assert-WlbTestPathGuard {
    param($Guard)
    foreach($entry in $Guard.directories){Assert-WlbCondition ([WlbStartup.ReadOnlyNative]::Identity($entry.handle) -ceq $entry.identity -and [WlbStartup.ReadOnlyNative]::FinalPath($entry.handle).Equals($entry.path,[StringComparison]::OrdinalIgnoreCase)) 'Directory handle identity changed'}
}

function Write-WlbTestNewFile {
    param([string]$Path,[byte[]]$Bytes,[switch]$InjectIncompleteWrite,[scriptblock]$BeforeUse)
    Assert-WlbCondition ($Bytes.Length -le 1048576) 'Bounded test startup evidence only'
    $guard=New-WlbTestPathGuard $Path
    try{
        if($BeforeUse){& $BeforeUse}
        Assert-WlbTestPathGuard $guard
        $stream=[IO.File]::Open($guard.path,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        try{
            Assert-WlbTestPathGuard $guard
            Assert-WlbCondition ([WlbStartup.ReadOnlyNative]::FinalPath($stream.SafeFileHandle).Equals($guard.path,[StringComparison]::OrdinalIgnoreCase)) 'Opened file destination changed'
            Assert-WlbCondition ([WlbStartup.ReadOnlyNative]::LinkCount($stream.SafeFileHandle) -eq 1) 'File hardlink rejected'
            $identity=[WlbStartup.ReadOnlyNative]::Identity($stream.SafeFileHandle)
            if($InjectIncompleteWrite){$length=[Math]::Min(3,$Bytes.Length);$stream.Write($Bytes,0,$length);$stream.Flush($true);throw 'BLOCKED: Injected incomplete write; evidence retained; no retry'}
            $stream.Write($Bytes,0,$Bytes.Length);$stream.Flush($true);$stream.Position=0
            $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant()
            [pscustomobject]@{path=$guard.path;identity=$identity;sha256=$hash;bytes=$Bytes.Length;complete=$true;test_only=$true}
        }finally{$stream.Dispose()}
    }finally{Close-WlbTestPathGuard $guard}
}

function Read-WlbTestPinnedFile {
    param($Fingerprint)
    $guard=New-WlbTestPathGuard $Fingerprint.path
    try{
        $stream=[IO.File]::Open($guard.path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        try{
            Assert-WlbCondition ([WlbStartup.ReadOnlyNative]::Identity($stream.SafeFileHandle) -ceq $Fingerprint.identity) 'File replaced since fingerprint'
            Assert-WlbCondition ([WlbStartup.ReadOnlyNative]::LinkCount($stream.SafeFileHandle) -eq 1 -and $stream.Length -le 1048576) 'Invalid pinned file size/link'
            $bytes=[byte[]]::new($stream.Length);$stream.ReadExactly($bytes)
            $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
            Assert-WlbCondition ($hash -ceq $Fingerprint.sha256) 'Pinned bytes changed'
            [pscustomobject]@{path=$guard.path;sha256=$hash;immutable_bytes=$bytes;test_only=$true}
        }finally{$stream.Dispose()}
    }finally{Close-WlbTestPathGuard $guard}
}

function New-WlbTestStartupLease {
    param([string]$Namespace)
    $namespacePath=Assert-WlbStartupTestPath $Namespace -MustExist
    $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($namespacePath.ToLowerInvariant()))).Substring(0,24)
    $name='Local\Wlb.Stage03D2.Test.'+$hash
    $mutex=[Threading.Mutex]::new($false,$name);$acquired=$false
    try{
        try{$acquired=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$acquired=$true;throw 'BLOCKED: Abandoned executor mutex; reconcile without implicit restart'}
        Assert-WlbCondition $acquired 'Concurrent executor mutex already owned'
        $reservation=Join-Path $namespacePath 'reservation.test.json'
        $bytes=[Text.Encoding]::UTF8.GetBytes('{"schema_version":"wlb-startup-test-reservation/0.1","test_only":true,"state":"RESERVED_NO_EXECUTION"}')
        $fingerprint=Write-WlbTestNewFile $reservation $bytes
        [pscustomobject]@{mutex=$mutex;mutex_name=$name;reservation=$fingerprint;test_only=$true}
    }catch{if($acquired){$mutex.ReleaseMutex()};$mutex.Dispose();throw}
}

function Close-WlbTestStartupLease {
    param($Lease)
    $Lease.mutex.ReleaseMutex();$Lease.mutex.Dispose()
    # Persistent reservation is retained; this never returns consent or implicitly retries.
}
