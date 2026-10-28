# Stage03F — Configuration and apparent dependency closure

Date: 2026-10-13 / Europe/Bucharest. Evidence is static text/filesystem only.
No Python, import, migration, frontend, server, CUDA or GPU operation was run.

## Alembic: correction of a possible mandatory-file assumption

EVIDENCE: snapshot app/database/db.py:73–82 builds an absolute path to
snapshot-root/alembic.ini and alembic_db, constructs Config(config_path), then
sets script_location and sqlalchemy.url programmatically. The database URL
comes from --database-url or the effective user directory: with the unchanged
future CLI, runtimes/core/state/user/comfyui.db. The original INI is absent from
the approved 619-file snapshot and was neither copied nor substituted.

EVIDENCE: the installed Alembic config.py:231–261 uses ConfigParser and
util/compat.py:126–130 calls ConfigParser.read. set_section_option:383–387 creates
a missing section before setting its value. ScriptDirectory.from_config uses
script_location; get_alembic_config explicitly supplies it. Snapshot
alembic_db/env.py consumes the resulting config section and does not require
logging.fileConfig(config.config_file_name). No application-specific mandatory
INI existence check was found on this inspected migration path.

STATIC INFERENCE, NOT_RUNTIME_PROOF: a missing INI is not, by itself, an
established mandatory startup failure on this exact code/package combination.
Absent INI options can be supplied by the existing programmatic setters; the
required options used by the inspected path are provided. This corrects the
interpretation that Config(path) inherently fails for a missing file. No claim
that all migrations/imports/dependency combinations will succeed is made.

EVIDENCE: main.py:468–503 calls init_db when dependencies_available() is true,
even if assets are disabled. Most initialization exceptions are logged without
exit when --enable-assets is absent. A "database is locked" exception exits;
the separate lock-acquisition case has conditional exit with assets enabled.
With --enable-assets, ordinary initialization failure is fatal. Missing optional
database imports are caught inside app/database/db.py, but filelock is imported
before that try block. The unchanged candidate CLI does not enable assets.

EVIDENCE: init_db dispatches file-backed versus in-memory SQLite.
--database-url sqlite:///:memory: uses metadata.create_all and bypasses Alembic
migrations; --database-url also bypasses legacy database relocation. These are
implemented options in code, NOT approved changes to the fixed startup plan.
No CLI/policy/budget was changed to adopt either option.

Potential side effects of a later startup remain untested: create directory/DB,
FileLock, WAL, migrations, backup/recovery, and legacy database relocation.
cli_args.py:273–275 derives the legacy location from its own __file__, pointing
to snapshot-root/user/comfyui.db in the copied code; that file is absent from the
allowlist. folder_paths.py and the explicit --user-directory select the separate
effective state/user directory. Neither path selection proves confinement of
all imports or third-party effects.

## Original INI: read-only assessment and conditional proposal

Source: D:\Musicas\Bitter-End-Visual-Local\ComfyUI\alembic.ini.
Size: 3,314 bytes. SHA256:
8e25f4b515644b0b7810344b4fec65025107ac8ea1da2d5195668bea28dae133.

Active content read:
- [alembic], script_location=alembic_db;
- prepend_sys_path=.; version_path_separator=os;
- sqlalchemy.url=sqlite:///user/comfyui.db;
- [post_write_hooks] with no active hooks.

No active remote DB URL, embedded credential or host-specific absolute path was
observed. Documentation URLs and example executable/hook settings are commented.
script_location and sqlalchemy.url are overridden by db.py; prepend_sys_path=.
depends on CWD and deserves review with the actual runtime candidate. Comments
mention revision templates, but startup upgrade does not establish a need to
create revisions or copy script.py.mako.

License evidence: source/snapshot root LICENSE is GNU GPLv3, SHA256
230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809.
Per-file exceptions/distribution rights are NOT_INDEPENDENTLY_VERIFIED. The INI
contains no separate license assertion. This is provenance evidence, not a legal
clearance for distribution or for third-party package resources.

RECOMMENDATION: add zero snapshot files now. Preserve the 619-file allowlist.
No replacement template was generated. If the operator later elects to include
the INI despite the static finding, the proposed single destination would be
D:\WHAT-LIES-BTWN-PRODUCTION-OS\runtimes\core\ComfyUI\alembic.ini, with the exact
source hash above, separately reviewed active options/license and explicit
allowlist/copy authorization. Reviewed adaptation would need a new, computed
hash; no adapted contents or hash are asserted here. Test then, in an authorized
scope: isolated DB path, no legacy production relocation, migration/config
behavior, expected CWD/sys.path, no hook/remote URL, and writes confined to the
approved state namespace. G4 is not opened by this proposal.

## Other non-Python resources

EVIDENCE: server.py:255–259 initializes the frontend unless --front-end-root is
set. The unchanged plan does not set that flag. frontend_management.py default
path imports comfyui_frontend_package and uses its static directory; index.html
is served and web.static registers that directory. The existing venv static
index.html was observed and hashed, outside the snapshot; the complete static
tree/package identity has not been authenticated. Required frontend distribution
version is 1.53.10 and its metadata states that version.

The code path for a non-default frontend may call GitHub/download an archive;
no such path was invoked or added to the fixed plan. Offline is not a general
Python egress boundary. Future startup must ensure the default local frontend
path and deny implicit acquisition.

Workflow-template and embedded-doc assets are referenced by optional server
routes. Their metadata is present; actual route/resource behavior is NOT_TESTED.
They are not demonstrated new snapshot-copy requirements for EmptyImage/SaveImage.
requirements.txt is read by frontend version checks and is already allowlisted.
README.md is referenced by pyproject for packaging, but no package build/install
is proposed. extra_model_paths.yaml is optional by source; it remains absent.
No additional non-Python snapshot file was proved indispensable by this review.
This is not a complete audit of arbitrary optional nodes or future workflows.

## Python and dependency matrix

| Component | Static evidence | Gap / execution consequence |
| --- | --- | --- |
| Venv entry executable | startup-identity pins D:\Musicas\Bitter-End-Visual-Local\.venv\Scripts\python.exe, SHA256 72b29481593c5da37c99248c82777fbfb56217ea7809b771bc760d0a9ecb179b | Entry hash is not the effective interpreter/stdlib/DLL identity |
| Interpreter candidate | pyvenv.cfg names C:\Users\user\AppData\Local\Programs\Python\Python313\python.exe; version 3.13.15; system-site-packages=false | Effective bootstrap, interpreter, stdlib and DLLs NOT_VERIFIED; no Python executed |
| 16 prior distributions | All 48 METADATA/WHEEL/RECORD hashes rechecked | RECORD text is not authentication of referenced native binaries |
| 34 declared requirement rows | Metadata present for all, including optional rows | No resolver result, complete transitive closure, import test or binary/ABI certification |
| Torch / torchaudio / torchvision | Declared 2.14.1+cu130 / 2.11.0+cu130 / 0.29.1+cu130 | CUDA/driver/native compatibility NOT_TESTED; torchvision declares torch>=2.14.0, satisfied textually; no equivalence inferred from CUDA suffix |
| Database | SQLAlchemy, Alembic, blake3 and filelock metadata observed | Mandatory versus caught imports differ; migrations/lock/WAL/legacy behavior untested |
| Pillow/NumPy/PyAV | Metadata observed | PNG/video/native codecs NOT_TESTED; no media decoded or produced |
| Frontend/templates/docs | Metadata observed; one frontend index hashed | Complete static assets/license/dependency identity and route behavior unverified |
| Native-node imports | 4,407 textual import references collected from 616 .py/.pyi files | Regex references are not Python AST closure or execution; native extras/import side effects remain a trust boundary |

Detailed evidence: tests/stage03f/evidence/dependency-run2/dependency-metadata-review.json,
import-references.csv and configuration-source-pins.json. All read source files
and metadata pinned there are rechecked unchanged by the delivery audit.

## Scope limitations

The old manifest provenance.source_snapshot=NOT_CREATED is retained as historical
G1 provenance because the unchanged schema pins that literal; the manifest change
is exclusively the new runtime-lock binding. Current physical/static state is
represented by startup-identity and runtime-lock. Changing the manifest schema,
executor policy or legacy specification is outside the five-file changeset and
is not silently performed. A future schema revision, if wanted, needs its own
scope. This legacy label never grants startup/render authority.

The unchanged job launcher omitting ApprovalId throws a null-valued-expression
error before its intended approval message. Passing Guid.Empty produces the
explicit missing-approval refusal. Both refuse submission. The code remains
byte-identical and no repair is authorized in this Stage03F changeset.

No operational values were chosen. Operator identity, CPU budget, cadence and
freshness remain UNKNOWN/null. SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0 is preserved;
no new request to choose a boundary and no independently authenticated identity,
ACL sandbox, egress enforcement, runtime compatibility or G4/G5 authority.
