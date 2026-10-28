# WHAT LIES BTWN — Stage03G / G4 telemetry decision package

Date: 2026-10-13; timezone for user-facing dates: Europe/Bucharest.
PASSIVE_CAPABILITIES_MEASURED_WITH_LIMITATIONS. G4 STRICT PREFLIGHT = BLOCKED.
No runtime/model was started, no operational parameter or authority was enabled.

## Available interfaces and what they prove

| Metric | Implemented source | Scope and limitation |
| --- | --- | --- |
| Available physical RAM | Windows PSAPI GetPerformanceInfo | Global page-based snapshot, 4,096-byte page granularity observed; not per-process resident RAM |
| Commit/limit/headroom | Same PSAPI snapshot | Global committed virtual memory and limit, not equivalent to physical RAM or pagefile use |
| Private bytes | .NET Process.PrivateMemorySize64 for a selected PID | Process private allocation; not working set. Process tuple must remain consistent |
| CPU | .NET Process.TotalProcessorTime.Ticks | Cumulative user+kernel CPU; delta/elapsed ratio is an estimate, may exceed one core. No CPU cap |
| NVIDIA VRAM used/free/total | Existing System32/nvidia-smi.exe, fixed read-only flags | Driver-reported global MiB; no PID attribution, no proved sampling accuracy or peak guarantee |
| GPU per-process bytes | NVIDIA query-compute-apps | All 31 process rows in native cold observation returned N/A; unavailable is null, never zero |
| Windows GPU memory | GPUProcessMemory/GPUAdapterMemory CIM counters | 67 PID/LUID accounting rows and 4 adapter keys in native cold observation; RTX mapping and residency interpretation NOT_VERIFIED |
| Potential competing work | .NET process-name snapshot; NVIDIA/WDDM GPU actors | Candidate names are not proof of render activity; GPU actor coverage is incomplete and exclusivity is not proved |
| Port 8189 | GetExtendedTcpTable IPv4/IPv6, passive; CIM crosscheck | No listener observed at the sampled times. A later listener can appear; no active connection, bind or listener was performed |
| Evidence/output/log/temp bytes | Bounded enumeration of four fixed project paths | Logical file lengths, not physical allocation or an atomic filesystem snapshot; races/unreadable/link paths block |
| Clock | Stopwatch/QPC plus UTC receipt timestamps | Monotonic within the collection process and clock ID; UTC alone is not used for deadlines |

The current actual image/PID fingerprint is a read-only observation, not evidence
that the executor launched that process or possesses valid stop authority. The
exe SHA covers the on-disk image, not loaded memory, stdlib or DLL authentication.

## GPU findings

NVIDIA GeForce RTX 5080 Laptop GPU, driver 617.42, UUID
GPU-REDACTED. Global total reported: 16,303 MiB.
Native cold sample: used 3,174 MiB, free 12,830 MiB; the remaining 299 MiB is an
unclassified difference, not silently treated as free, a leak or an accounting bug.
The collector validates nonnegative/consistent totals without requiring
used+free=total. Reported VRAM quantum is 1 MiB; this is display/report granularity,
not proved physical accuracy or evidence that millisecond peaks can be captured.

Windows counters offer genuine PID/LUID accounting values even though NVIDIA
process VRAM is N/A. They are not marked impossible or equated to zero. However,
four adapter identities appear, and matching a large dedicated-memory counter
to NVIDIA merely by magnitude is insufficient. No LUID-to-UUID/PCI mapping was
established and no load/renderer was run to validate a residency interpretation.
Accordingly, reliable RTX-specific per-process VRAM remains NOT_VERIFIED.
Several desktop/utility actors were observed; a single global delta cannot
identify which actor allocated memory. GPU utilization is global and the driver
measurement window is not demonstrated by this experiment.

Provider generation timestamps for WDDM data were not established. Receipt
time/collector completion only bounds time spent reading, not hidden provider
cache age. The code preserves this distinction and strict preflight blocks it.

## Measured finite sampling experiments

There were two source versions, each with one cold observation and 12 scheduled
samples per interval. Total: 48 scheduled samples + 2 cold observations. No failed
query was automatically retried. Initial source is preserved at
tests/stage03g/evidence/runtime-monitor-cim-at-benchmark.ps1; native source SHA256
matches the final canonical RuntimeMonitor hash.

| Collector version | Candidate cadence | Collection min–max | Mean | Empirical p95 | Overruns |
| --- | ---: | ---: | ---: | ---: | ---: |
| Initial sequential CIM | 250 ms | 1,042–1,295 ms | 1,154.3 ms | 1,295 ms | 12/12 |
| Initial sequential CIM | 500 ms | 1,062–1,217 ms | 1,144.5 ms | 1,217 ms | 12/12 |
| Native TCP + .NET process names | 250 ms | 171–246 ms | 214.6 ms | 246 ms | 0/12 |
| Native TCP + .NET process names | 500 ms | 199–247 ms | 227.3 ms | 247 ms | 0/12 |

The initial bottleneck was port CIM (~698–705 ms mean) plus process-name CIM
(~258–260 ms mean). Native port reads averaged 0.7–0.8 ms; process-name reads
12.4–14.8 ms. GPU observation averaged ~175 ms in the final experiment. Native
cold collection cost 1,184 ms, including first-use helpers/providers; do not
present warm performance as cold-start cost.

Native scheduling start lateness was at most 14 ms for 250 and 16 ms for 500.
All native warm reads completed within both candidate 1,000/2,000 ms receipt-age
limits; the initial pipeline exceeded 1,000 ms for all warm reads. Source/provider
generation freshness is still NOT_VERIFIED in either version. With only 12 samples,
nearest-rank p95 equals the observed maximum; this is not a population tail bound.
The measurements did not include Comfy startup, model loading or a 120 s watchdog.

CPU observations in the native benchmark show material collector cost: mean
observer CPU per collection ~201.8 ms at 250 and ~179.7 ms at 500, excluding
NVIDIA helper/CIM provider processes. Cumulative observer CPU delta over the
sample window produced estimates ~81.5%/~76.1% of one logical core; these
include observer activity beyond the individually bracketed calls and are not
system-wide percentages or an operational CPU budget. Representation is 100 ns,
not a demonstrated scheduler resolution. No CPU threshold was invented.

Native warm RAM available ranged approximately 6.42–6.67 GiB, below the 8 GiB
gate. Commit headroom remained approximately 28.29–28.34 GiB, above 10 GiB.
NVIDIA global used VRAM ranged 3,174–3,181 MiB; no process-specific allocation
was inferred from that small variation. These are dated observations, not
guarantees of current/future headroom.

## Conservative alternative — proposal only, NOT IMPLEMENTED AS AN EXCEPTION

If the operator later accepts a startup-only global-GPU supervision mode:

1. Restrict it to the approved model-free POC-0 startup, never G5 or Alpha.
2. Warm approved collectors before acquiring an immediate baseline; verify RAM
   >=8 GiB and commit headroom >=10 GiB, no heavy render and an explicitly
   reviewed set of background GPU actors. Unknown/new activity blocks.
3. Monitor global VRAM growth against the existing 2 GiB threshold. This includes
   unrelated activity and may conservatively abort; it is not the target's VRAM.
4. Retain total-commit delta <=4 GiB, own private bytes <=4 GiB, startup <=120 s,
   output/log/temp <=256 MiB; no cap increase, baseline reset, implicit retry or
   assumption that negative/global movements are attributable.
5. Treat unavailable/stale/inconsistent telemetry or lost process/port ownership
   as BLOCKED. Define what receipt freshness proxy is accepted for providers
   lacking generation timestamps; do not silently declare source age verified.
6. Use future authentic G4 consent and independently reviewed owned lifecycle
   adapters. Global telemetry and textual account/SID do not grant authority.

No such mode was added to startup-policy or the evaluator. Strict VRAM attribution
still blocks. NVIDIA CLI/CIM/API calls have measured costs but are not proved
hard-time-bounded; no automatic kill/cancellation path was introduced to force a
stalled native CLI to meet the deadline. That remains a watchdog design blocker.

## Human parameter proposals — do not bind to policy

| Parameter | Proposal for review | Current operational state |
| --- | --- | --- |
| operator_identity | Confirm observed WORKSTATION\user and SID S-1-5-21-REDACTED | UNKNOWN/null; technical observation is not human consent |
| cpu_budget | OBSERVE_ONLY for G4 startup-only, with scoped cumulative CPU/delta reporting | UNKNOWN/null; no numeric cap |
| polling_cadence_ms | 500 ms rather than the narrow measured margin at 250 ms | UNKNOWN/null; small sample, no startup load test |
| telemetry_freshness_ms | 2,000 ms as candidate receipt-age bound, subject to explicit provider-age proxy decision | UNKNOWN/null; not a generation-age guarantee |

SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0 stays selected. No new boundary choice is
requested and no strong isolation, egress firewall or independent authentication
is claimed. All four choices and any global-GPU exception require later explicit
operator decisions and a separately reviewed operational contract.

## Decision

G4 remains BLOCKED: RAM gate currently failed, RTX-specific per-process VRAM and
provider generation freshness unverified, exclusivity not proved, human values
and trusted consent absent, and real owned process/port/lifecycle/watchdog control
not implemented or tested. Python/runtime/stdlib/DLL/frontend/database compatibility
limitations from Stage03F remain. No real Process.Start/Process.Kill path exists.
Fixed read-only nvidia-smi utility invocations are passive queries, not runtime
startup; their subprocess/driver overhead is excluded from observer CPU where noted.

G5 remains NOT_AUTHORIZED. No job approval, REST, GPU generation or media exists.
WAITING_HUMAN_REVIEW. STOP_AFTER_DELIVERY.
