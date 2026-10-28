# Stage03D2 — exact bounded Comfy source copy proposal

**DESIGN ONLY. No source snapshot was copied. Separate future copy authorization required.**

Origin: `D:\Musicas\Bitter-End-Visual-Local\ComfyUI`.
Planned destination: `D:\WHAT-LIES-BTWN-PRODUCTION-OS\runtimes\core\ComfyUI`.
Exact per-file source, destination, bytes, SHA-256 and group: `spec\G4_SNAPSHOT_COPY_INVENTORY.csv`.
Current candidate: **619 files, 9,533,695 measured bytes**, bounded below 2000 files / 64 MiB.
These bounds describe a review/copy proposal, not a runtime resource cap or permission to copy.

| Group | Files | Measured bytes | Inclusion / dependencies |
| --- | ---: | ---: | --- |
| root-startup-and-provenance | 14 | 346667 | Explicit main/nodes/server/execution/paths/helpers/version/protocol/cuda/hook Python modules plus LICENSE, requirements and pyproject metadata |
| comfy | 322 | 5505691 | Python and type-stub source package; imports include model architecture code even for a model-free graph; no weights |
| comfy_execution | 10 | 101273 | Core execution/progress/job source; presence does not authorize job submission |
| comfy_api | 39 | 309571 | Native extension/type interface package, including its Python input subpackage; this is not provider nodes or input assets |
| comfy_config | 2 | 9046 | Configuration-handling Python source, not user configuration data |
| comfy_extras | 166 | 2813213 | Built-in modules enumerated/imported during startup; substantial optional dependencies; no custom nodes or weights |
| app | 43 | 390713 | Frontend/assets/user/database infrastructure source; filesystem/init effects require later review |
| api_server | 7 | 6328 | Internal route support imported by server; network capability is residual risk, not authorization |
| middleware | 2 | 1792 | Native HTTP middleware source |
| utils | 5 | 5287 | Required native utility source |
| alembic_db | 9 | 44114 | Migration Python source; database/config prerequisites remain unresolved |

Each source file was hashed read-only. Included files/parents with reparse points are not
followed; included file hardlink count is checked. Only explicitly named root files and
`.py`/`.pyi` under the listed code directories are selected. Root models, custom_nodes,
comfy_api_nodes, .git, credentials, caches, input/output/user/temp, tests, examples and
unreviewed configuration/data are excluded. Nested `comfy/ldm/models` and
`comfy_api/input` contain **source code**, so their Python files are included; they are
not model weights or input assets. The first provisional 615-file exclusion list is retained
in test evidence, with the correction to these source-package exclusions documented.

License evidence: root LICENSE contains the GNU GPL Version 3 text; pyproject references
that license. No per-file exception or legal-distribution determination is inferred. A future
copy must retain LICENSE and review any relevant third-party/per-file notices. Source code
presence and distribution METADATA do not prove environment compatibility or binary trust.

Specific residual dependency gap: `alembic.ini` and other config/non-Python data are excluded
until their necessity and a credential-free template are reviewed. This candidate inventory
is exact and bounded, but **not certified runnable or an exhaustive proven import closure**.
Do not silently expand it during copy; revise the concrete list and obtain scope approval if
additional required files are found. No claim that startup fits the RAM/commit/VRAM thresholds.

The fixed CLI plan uses --disable-all-custom-nodes, --disable-partner-nodes and --offline.
Local source `comfy/cli_args.py` explicitly supports these; offline sets partner-node disable
and frontend CSP behavior. It is not a Python egress firewall. Native source still has a
server and routes, including job infrastructure; the supervised operator must keep creative
tools and unapproved clients from submitting to a future listener. No listener was started.

Python candidate entry executable:
`D:\Musicas\Bitter-End-Visual-Local\.venv\Scripts\python.exe`.
Static entry-file SHA-256:
`72b29481593c5da37c99248c82777fbfb56217ea7809b771bc760d0a9ecb179b`.
This identifies the virtualenv entry executable, not necessarily the underlying interpreter,
stdlib, DLLs or resulting process tree. They remain RUNTIME_NOT_VERIFIED. No Python ran.

Sixteen relevant installed distribution METADATA/WHEEL/RECORD inventories are in
`spec\G4_DEPENDENCY_METADATA.json`. These fingerprints identify metadata only; hashing
RECORD does not verify every installed binary listed in RECORD. No modules were imported,
packages installed or environments modified. Imports, native ABI/CUDA, frontend behavior,
provider disabling and actual cache/state writes require future scoped G4 validation.

Future copy acceptance: rehash the exact reviewed list, refuse changed source or links,
copy only explicit files using no-overwrite into the owned new namespace, retain licenses,
record actual snapshot fingerprints and stop on missing dependency/data or changed scope.
Copy approval does not authorize Python execution or startup.

NEXT_GATE = WAITING_HUMAN_REVIEW. STOP BEFORE COPY / G4 / G5 / ALPHA / MCP.
