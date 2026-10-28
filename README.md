# WHAT LIES BTWN — Production OS

**The foundation of a fail-closed, auditable pipeline for producing AI-generated visuals for my music project, WHAT LIES BTWN.**

WHAT LIES BTWN is my music project. This repository holds the **production OS** being built to sit between me and a local ComfyUI render stack: render jobs are described by manifests and validated against strict schemas and policies, and each stage is opened only through a gate with its own evidence (hashes, telemetry, receipts) and an explicit human authorization.

**Current status:** preparation and validation. The validators, startup/supervision harnesses and their tests exist; **real render execution is still intentionally blocked** — the job launcher refuses every submission until the execution gate is approved.

> Built by Emannuel Serrão. Stage documents are mostly in Portuguese/English. ComfyUI itself is an external dependency and is **not** included here.

## Design principles

- **Fail-closed by default.** The job launcher (`core/Invoke-WlbJob.ps1`) currently refuses every submission by design (no execution path exists yet), and future submissions require every check to pass; missing data is typed as `null` with a stated reason, never guessed.
- **Gates (G1…G4).** Each stage (03B → 03J) has a decision package, an implementation receipt and a test matrix. A stage only starts after the operator's written authorization.
- **Strict validation.** Manifest schema, workflow graph and path checks (`core/Test-WlbManifest.ps1`), duplicate-JSON-key detection, Windows reparse-point / hard-link detection (`core/Wlb.Common.ps1`), PNG header and hash checks on outputs (`core/Test-WlbOutput.ps1`).
- **Supervised runtime (test harnesses).** A supervisor process launches a separate worker without shell, profile or arbitrary commands (`Wlb.Supervisor.ps1`, `Wlb.WorkerProcess.ps1`), with telemetry and resource monitoring (`Wlb.RuntimeMonitor.ps1`, `Wlb.TelemetryWorker.ps1`).
- **Reproducibility.** A runtime lock and SHA-256 inventories pin the exact source artifacts; a character bible (`bible/`) keeps visual identity consistent across shots.

## Layout

```
core/       PowerShell modules: manifest/output validation, startup, supervisor, worker, telemetry
policy/     executor policy, runtime lock, startup identity/policy, shot-manifest JSON schema
spec/       future execution contract and dependency metadata
workflows/  draft ComfyUI workflows
bible/      character bible (visual identity)
tests/      per-stage test harnesses and fixtures (stage03c … stage03j)
STAGE03*    decision packages, receipts and test matrices for each gate
```

## Stack

PowerShell · Python · ComfyUI (external) · JSON Schema · Windows process supervision

*This public copy omits machine-specific evidence dumps (process/ACL snapshots) and the vendored ComfyUI runtime; hashes recorded in historical receipts refer to the original private workspace.*

## License

All rights reserved.
