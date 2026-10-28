#requires -Version 7.6
# DXGI adapter descriptors only: no D3D device, GPU context, command queue or workload.
. (Join-Path $PSScriptRoot 'H.Common.ps1')
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
namespace WlbH {
 [StructLayout(LayoutKind.Sequential)] public struct Luid { public uint Low; public int High; }
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] public struct Desc {
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=128)] public string Description;
  public uint VendorId,DeviceId,SubSysId,Revision;
  public UIntPtr DedicatedVideoMemory,DedicatedSystemMemory,SharedSystemMemory;
  public Luid AdapterLuid; public uint Flags;
 }
 public class Adapter {
  public string Name,Luid,VendorHex,DeviceHex;
  public uint Flags; public ulong DedicatedCapacity,SharedCapacity;
 }
 public static class Dxgi {
  [DllImport("dxgi.dll",ExactSpelling=true)] static extern int CreateDXGIFactory1(ref Guid iid,out IntPtr factory);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int Enum1(IntPtr self,uint index,out IntPtr adapter);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int GetDesc1(IntPtr self,out Desc desc);
  static T Slot<T>(IntPtr p,int index) where T:Delegate { return Marshal.GetDelegateForFunctionPointer<T>(Marshal.ReadIntPtr(Marshal.ReadIntPtr(p),index*IntPtr.Size)); }
  public static Adapter[] Read(){
   var id=new Guid("770aae78-f26f-4dba-a829-253c83d1b387");IntPtr factory;
   Marshal.ThrowExceptionForHR(CreateDXGIFactory1(ref id,out factory));
   try{
    var read=Slot<Enum1>(factory,12);var results=new List<Adapter>();
    for(uint i=0;i<16;i++){
     IntPtr adapter;int hr=read(factory,i,out adapter);
     if(unchecked((uint)hr)==0x887a0002)return results.ToArray();
     Marshal.ThrowExceptionForHR(hr);
     try{Desc d;Marshal.ThrowExceptionForHR(Slot<GetDesc1>(adapter,10)(adapter,out d));
      results.Add(new Adapter{Name=d.Description,VendorHex=d.VendorId.ToString("X4"),DeviceHex=d.DeviceId.ToString("X4"),Luid="luid_0x"+unchecked((uint)d.AdapterLuid.High).ToString("X8")+"_0x"+d.AdapterLuid.Low.ToString("X8"),DedicatedCapacity=d.DedicatedVideoMemory.ToUInt64(),SharedCapacity=d.SharedSystemMemory.ToUInt64(),Flags=d.Flags});
     }finally{Marshal.Release(adapter);}
    }
    throw new InvalidOperationException("Adapter enumeration exceeds fixed 16 limit");
   }finally{Marshal.Release(factory);}
  }
 }
}
'@
$clock=[Diagnostics.Stopwatch]::StartNew();$utc=[DateTime]::UtcNow.ToString('o');$errors=@();$adapters=@()
try{$adapters=@([WlbH.Dxgi]::Read())}catch{$errors+=@($_.Exception.Message)}
$previous=Read-HJson (Join-Path $HEvidence 'gpu-diagnosis.json')
$rtx=@($adapters|Where-Object {$_.VendorHex -ceq '10DE' -and $_.Name -ceq 'NVIDIA GeForce RTX 5080 Laptop GPU'})
$mapped=@();if($rtx.Count -eq 1){$mapped=@($previous.canonical_gpu.windows_processes|Where-Object {$_.adapter_key.StartsWith($rtx[0].Luid,[StringComparison]::OrdinalIgnoreCase)})}
$smi=Join-Path $env:SystemRoot 'System32\nvidia-smi.exe';$pci=@();try{$pci=@(& $smi '--query-gpu=name,uuid,pci.bus_id,pci.device_id' '--format=csv,noheader,nounits' 2>&1);if($LASTEXITCODE -ne 0){throw 'PCI query failed'}}catch{$errors+=@($_.Exception.Message)}
Save-HNew 'dxgi-adapter-evidence.json' ([ordered]@{utc=$utc;duration_ms=$clock.ElapsedMilliseconds;adapters=$adapters;rtx_luid_descriptor_status=$(if($rtx.Count -eq 1){'OBSERVED_UNIQUE_DXGI_RTX_NAME_VENDOR_LUID'}else{'NOT_VERIFIED'});rtx_accounting_rows=$mapped;nvidia_pci_query=$pci;dxgi_luid_to_nvidia_uuid_direct_mapping='NOT_VERIFIED_NO_COMMON_UUID_FIELD';process_vram_residency='NOT_VERIFIED';provider_generation_age='NOT_VERIFIED';errors=$errors;created_d3d_device_or_workload=$false;descriptor_memory_values_are_capacity_not_usage=$true})
[pscustomobject]@{adapters=$adapters;rtx_rows=$mapped.Count;errors=$errors}|ConvertTo-Json -Depth 7
