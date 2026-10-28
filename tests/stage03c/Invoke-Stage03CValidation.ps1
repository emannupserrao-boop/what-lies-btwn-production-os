# Stage 03C isolated test harness. No launcher, Python, REST, process start or GPU invocation.
# Component blocks are extracted from the unchanged original AST; no test contains a submit adapter.
# Run once: evidence uses CreateNew, and is deliberately preserved.
#requires -Version 7.4
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = 'D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$TestRoot = Join-Path $Root 'tests\stage03c'
$FixtureRoot = Join-Path $TestRoot 'fixtures'
$EvidenceRoot = Join-Path $TestRoot 'evidence'
$Originals = @('core\Invoke-WlbJob.ps1','core\Test-WlbManifest.ps1','core\Test-WlbOutput.ps1','core\Wlb.Common.ps1','policy\shot-manifest.schema.json','policy\executor-policy.json','policy\runtime-lock.json','workflows\draft\poc0-calibration.api.json','manifests\draft\POC0-CALIBRATION-001.json','bible\character-bible.v0.1.json','README.md','spec\FUTURE_EXECUTION_CONTRACT.md','STAGE03B_PREP_RECEIPT.md')
foreach ($folder in @($Root, (Join-Path $Root 'tests'), $TestRoot)) {
    $item = Get-Item -LiteralPath $folder -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Test root has a reparse point' }
}
$null = New-Item -ItemType Directory -Path $FixtureRoot,$EvidenceRoot
function Write-NewText([string]$Path,[string]$Text) {
    if (-not $Path.StartsWith($TestRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside test namespace' }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $stream = [IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
}
function Save-Json([string]$Path,$Value) { Write-NewText $Path ($Value | ConvertTo-Json -Depth 100) }
function Inventory {
    @($Originals | ForEach-Object {
        $path = Join-Path $Root $_
        $item = Get-Item -LiteralPath $path -Force
        [ordered]@{path=$_;bytes=$item.Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();last_write_utc=$item.LastWriteTimeUtc.ToString('o')}
    })
}
$before = Inventory
Save-Json (Join-Path $EvidenceRoot 'originals-before.json') $before
$Results = [Collections.Generic.List[object]]::new()
function Add-Result([string]$Id,[string]$Class,[string]$Expected,[string]$Actual,[string]$Status,[string]$Mode,[string]$Fixture='') {
    $Results.Add([ordered]@{id=$Id;classification=$Class;expectation=$Expected;actual=$Actual;status=$Status;evidence_kind=$Mode;fixture=$Fixture})
}
function Expect-Reject([string]$Id,[string]$Class,[scriptblock]$Action,[string]$Expected='Reject unsafe fixture',[string]$Fixture='',[string]$ErrorPattern='') {
    try { $out = @(& $Action); Add-Result $Id $Class $Expected ('ACCEPTED: '+($out | ConvertTo-Json -Depth 8 -Compress)) 'FAIL' 'EXECUTED_COMPONENT' $Fixture }
    catch {
        $actual=$_.Exception.Message
        $status=if ($ErrorPattern -and $actual -notmatch $ErrorPattern) {'FAIL'} else {'PASS'}
        Add-Result $Id $Class $Expected $actual $status 'EXECUTED_COMPONENT' $Fixture
    }
}
function New-Manifest { [IO.File]::ReadAllText((Join-Path $Root 'manifests\draft\POC0-CALIBRATION-001.json')) | ConvertFrom-Json -AsHashtable }
function New-Graph { [IO.File]::ReadAllText((Join-Path $Root 'workflows\draft\poc0-calibration.api.json')) | ConvertFrom-Json -AsHashtable }
$schemaPath=Join-Path $Root 'policy\shot-manifest.schema.json'
$schemaRaw=[IO.File]::ReadAllText($schemaPath)
$schema=$schemaRaw | ConvertFrom-Json -AsHashtable
$manifestRaw=[IO.File]::ReadAllText((Join-Path $Root 'manifests\draft\POC0-CALIBRATION-001.json'))
$runtime=[IO.File]::ReadAllText((Join-Path $Root 'policy\runtime-lock.json')) | ConvertFrom-Json -AsHashtable
$policy=[IO.File]::ReadAllText((Join-Path $Root 'policy\executor-policy.json')) | ConvertFrom-Json -AsHashtable
$bible=[IO.File]::ReadAllText((Join-Path $Root 'bible\character-bible.v0.1.json')) | ConvertFrom-Json -AsHashtable
$receipt=[IO.File]::ReadAllText((Join-Path $Root 'STAGE03B_PREP_RECEIPT.md'))
$reported = [Collections.Generic.List[object]]::new()
foreach ($row in $before) {
    $full=Join-Path $Root $row.path
    $pattern='(?m)^\| '+[regex]::Escape($full)+' \| ([0-9]+) \| ([a-f0-9]{64}) \|'
    $match=[regex]::Match($receipt,$pattern)
    if ($match.Success) {
        $ok=([long]$match.Groups[1].Value -eq $row.bytes -and $match.Groups[2].Value -ceq $row.sha256)
        $reported.Add([ordered]@{path=$row.path;reported_bytes=[long]$match.Groups[1].Value;reported_sha256=$match.Groups[2].Value;matches=$ok})
        Add-Result ('INVENTORY-'+$row.path) 'INVENTORY' 'Match Stage03B receipt bytes/hash' ($row | ConvertTo-Json -Compress) $(if($ok){'PASS'}else{'FAIL'}) 'EXECUTED_HASH'
    } else {
        $reported.Add([ordered]@{path=$row.path;reported_bytes=$null;reported_sha256=$null;matches=$null})
        Add-Result ('INVENTORY-'+$row.path) 'INVENTORY' 'Compute receipt hash; external reference unavailable here' ($row | ConvertTo-Json -Compress) 'NOT_TESTED' 'EXECUTED_HASH'
    }
}
Save-Json (Join-Path $EvidenceRoot 'receipt-comparison.json') @($reported)
$sourcePaths=@(
    [ordered]@{path='D:\What Lies Btwn\WHAT_LIES_BTWN_STAGE03A_PRODUCTION_OS_FOUNDATION_DESIGN_v0.1.txt';expected=$runtime.source_contracts.stage03a_sha256},
    [ordered]@{path='D:\What Lies Btwn\WLB_PRODUCTION_OS_STAGE03B_CORE_PREP_v0.1.txt';expected=$runtime.source_contracts.stage03b_sha256},
    [ordered]@{path=(New-Manifest).provenance.source_report;expected=(New-Manifest).provenance.source_report_sha256})
foreach ($entry in $sourcePaths) {
    $entry.actual=(Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash.ToLowerInvariant()
    $entry.matches=$entry.actual -ceq $entry.expected
    Add-Result ('SOURCE-'+[IO.Path]::GetFileName($entry.path)) 'BINDINGS' 'Source contract/report hash agrees' ($entry | ConvertTo-Json -Compress) $(if($entry.matches){'PASS'}else{'FAIL'}) 'EXECUTED_HASH'
}
Save-Json (Join-Path $EvidenceRoot 'source-hashes.json') $sourcePaths
$astEvidence=[Collections.Generic.List[object]]::new()
foreach ($relative in $Originals | Where-Object { $_ -like '*.ps1' }) {
    $tokens=$null; $parseErrors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root $relative),[ref]$tokens,[ref]$parseErrors)
    $commands=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true) | ForEach-Object { [ordered]@{line=$_.Extent.StartLineNumber;command=$_.GetCommandName();text=$_.Extent.Text} })
    $members=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst]},$true) | ForEach-Object { [ordered]@{line=$_.Extent.StartLineNumber;text=$_.Extent.Text} })
    $astEvidence.Add([ordered]@{file=$relative;parse_errors=@($parseErrors | ForEach-Object {$_.Message});commands=$commands;member_calls=$members})
    Add-Result ('SYNTAX-'+$relative) 'STATIC_ANALYSIS' 'Zero parser diagnostics' ('Parser diagnostics: '+@($parseErrors).Count) $(if(@($parseErrors).Count -eq 0){'PASS'}else{'FAIL'}) 'EXECUTED_PARSER'
}
Save-Json (Join-Path $EvidenceRoot 'powershell-ast.json') @($astEvidence)
$analyzer=@(Get-Module -ListAvailable PSScriptAnalyzer)
Add-Result 'ANALYSIS-PSScriptAnalyzer' 'STATIC_ANALYSIS' 'Optional installed analyzer' ('Installed module count: '+$analyzer.Count+'; manual AST/source analysis performed') $(if($analyzer.Count){'NOT_TESTED'}else{'NOT_TESTED'}) 'TOOL_AVAILABILITY'
. (Join-Path $Root 'core\Wlb.Common.ps1')
foreach ($relative in $Originals | Where-Object {$_ -like '*.json'}) {
    $null=Read-WlbJson (Join-Path $Root $relative)
    Add-Result ('JSON-'+$relative) 'MANIFEST' 'Strict local JSON parsing' 'Parsed by original Read-WlbJson with key/size/depth guards' 'PASS' 'EXECUTED_ORIGINAL'
}
try {
    $actual=& (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode StaticReview
    Save-Json (Join-Path $EvidenceRoot 'original-static-review.json') $actual
    Add-Result 'BASELINE-STATIC' 'MANIFEST' 'Original unchanged baseline passes preparation check, remains nonexecutable' ($actual | ConvertTo-Json -Compress) $(if(-not $actual.executable){'PASS'}else{'FAIL'}) 'EXECUTED_ORIGINAL'
} catch { Add-Result 'BASELINE-STATIC' 'MANIFEST' 'Original baseline passes' $_.Exception.Message 'FAIL' 'EXECUTED_ORIGINAL' }
Expect-Reject 'BASELINE-EXECUTION-ELIGIBILITY' 'EXECUTOR' { & (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode ExecutionEligibility } 'Always blocked in G1' '' 'BLOCKED: G1 preparation only'
foreach ($entry in $runtime.prepared_artifacts.GetEnumerator()) {
    $actual=Get-WlbHash (Join-Path $Root $entry.Key)
    Add-Result ('BIND-'+$entry.Key) 'BINDINGS' 'Runtime prepared artifact SHA256 matches' $actual $(if($actual -ceq $entry.Value){'PASS'}else{'FAIL'}) 'EXECUTED_HASH'
}
# Local schema references only; external references are inspected, never dereferenced in tests.
$references=@([regex]::Matches($schemaRaw,'"\$ref"\s*:\s*"([^"]+)"') | ForEach-Object {$_.Groups[1].Value})
foreach ($reference in $references | Select-Object -Unique) {
    $name=$reference.Replace('#/definitions/','')
    $ok=$reference.StartsWith('#/definitions/') -and $schema.definitions.Contains($name)
    Add-Result ('SCHEMA-REF-'+$name) 'MANIFEST' 'Resolve local schema definition' $reference $(if($ok){'PASS'}else{'FAIL'}) 'STATIC_PLUS_LOCAL_LOOKUP'
}
Add-Result 'SCHEMA-BASELINE' 'MANIFEST' 'Baseline validates local draft schema' ([string]($manifestRaw | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) 'PASS' 'EXECUTED_ORIGINAL'
function Test-ManifestFixture([string]$Id,[scriptblock]$Mutation) {
    $value=New-Manifest
    & $Mutation $value
    $path=Join-Path $FixtureRoot ($Id+'.json')
    Save-Json $path $value
    Expect-Reject $Id 'MANIFEST' { $raw=[IO.File]::ReadAllText($path); $null=Read-WlbJson $path; if (-not ($raw | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) { throw 'Manifest schema rejected' } } 'Reject invalid manifest via original JSON reader and local schema' $path
}
foreach ($key in $schema.required) {
    Test-ManifestFixture ('A-MISSING-'+$key) {param($m) $m.Remove($key)}
}
$mutations=[ordered]@{
    'A-WRONG-REVISION-TYPE'={param($m) $m.revision='1'};
    'A-WRONG-WIDTH-TYPE'={param($m) $m.parameters.width='640'};
    'A-WRONG-BOOL-TYPE'={param($m) $m.output.overwrite='false'};
    'A-WRONG-ARRAY-TYPE'={param($m) $m.models=@{}}
    'A-INVALID-JOB'={param($m) $m.job_id='..\OTHER'};
    'A-INVALID-STATE'={param($m) $m.state='EXECUTE_NOW'};
    'A-EXTRA-KEY'={param($m) $m.unexpected='value'};
    'A-NESTED-MISSING'={param($m) $m.parameters.Remove('color')};
    'A-NESTED-EXTRA'={param($m) $m.parameters.extra=$true};
    'A-INCONSISTENT-WIDTH'={param($m) $m.parameters.width=641};
    'A-INCONSISTENT-BATCH'={param($m) $m.parameters.batch_size=2};
    'A-INCONSISTENT-COLOR'={param($m) $m.parameters.color=0};
    'A-INCONSISTENT-ASPECT'={param($m) $m.parameters.aspect='9:16'};
    'A-MALFORMED-NA'={param($m) $m.parameters.prompt.value='active text'};
    'A-UNKNOWN-ESSENTIAL'={param($m) $m.parameters.width='UNKNOWN'};
    'A-OWNER-CONFIRMED-NULL'={param($m) $m.owner.identity_status='CONFIRMED'};
    'A-OWNER-UNKNOWN-IDENTITY'={param($m) $m.owner.identity='Somebody'};
    'A-HASH-INVALID-SYNTAX'={param($m) $m.workflow.sha256='not-a-sha256'};
    'A-MODEL-ADDED'={param($m) $m.models=@(@{sha256=('0'*64);path='NOT_A_REAL_MODEL'})};
    'A-INPUT-ADDED'={param($m) $m.source_assets=@(@{sha256=('0'*64);path='NOT_A_REAL_INPUT'})};
    'A-REFERENCE-ADDED'={param($m) $m.parameters.reference_frames=@('NOT_A_REAL_FRAME')};
    'A-CAP-INCREASE'={param($m) $m.budget.max_incremental_commit_gib=5};
    'A-PREMATURE-APPROVAL'={param($m) $m.approval_contract.record_created=$true};
    'C-WORKFLOW-OUTSIDE'={param($m) $m.workflow.path='D:\elsewhere\workflow.json'};
    'C-WORKFLOW-UNAPPROVED'={param($m) $m.workflow.path=Join-Path $Root 'workflows\other\arbitrary.json'};
    'C-MANIFEST-OUTPUT-OUTSIDE'={param($m) $m.output.directory='D:\elsewhere\output'};
    'C-MANIFEST-OVERWRITE'={param($m) $m.output.overwrite=$true};
    'D-MANIFEST-NODE-ADDED'={param($m) $m.workflow.allowed_nodes=@('EmptyImage','SaveImage','ProviderNode')}
}
foreach ($entry in $mutations.GetEnumerator()) { Test-ManifestFixture $entry.Key $entry.Value }
foreach ($entry in @(
    @{id='A-MALFORMED-JSON';text='{"job_id":';pattern='Parse'},
    @{id='A-DUPLICATE-KEY';text='{"job_id":"a","job_id":"b"}';pattern='Duplicate/case-colliding'},
    @{id='A-CASE-COLLISION';text='{"job_id":"a","JOB_ID":"b"}';pattern='Duplicate/case-colliding'},
    @{id='A-NESTED-DUPLICATE';text='{"outer":{"x":1,"x":2}}';pattern='Duplicate/case-colliding'},
    @{id='A-OVERSIZE-JSON';text=(' '*1048577);pattern='exceeds 1 MiB'},
    @{id='A-DEPTH-JSON';text=(('['*66)+'0'+(']'*66));pattern='maximum configured depth|JSON nesting exceeds limit|Parse'})) {
    $path=Join-Path $FixtureRoot ($entry.id+'.json');Write-NewText $path $entry.text
    Expect-Reject $entry.id 'MANIFEST' {Read-WlbJson $path} 'Reject malformed/ambiguous/oversize/deep JSON' $path $entry.pattern
}
$invalidSchema=$schemaRaw.Replace('#/definitions/hash','#/definitions/DOES_NOT_EXIST')
$path=Join-Path $FixtureRoot 'A-invalid-local-schema.json';Write-NewText $path $invalidSchema
Expect-Reject 'A-INVALID-LOCAL-SCHEMA-REF' 'MANIFEST' {$manifestRaw | Test-Json -SchemaFile $path -ErrorAction Stop} 'Reject unresolved local reference' $path
Test-ManifestFixture 'A-INVALID-SCHEMA-VERSION' {param($m) $m.schema_version='wlb-shot-manifest/999'}
Test-ManifestFixture 'A-UNEXPECTED-SCHEMA-REF' {param($m) $m['$schema']='urn:NOT_REAL'}
# Hash-binding predicates copied verbatim from source statements; paths point ONLY at fixtures.
$manifest=New-Manifest; $graphPath=Join-Path $FixtureRoot 'A-modified-workflow.json'
$graphFixture=New-Graph;$graphFixture['1'].inputs.width=641;Save-Json $graphPath $graphFixture
Expect-Reject 'A-MODIFIED-WORKFLOW-HASH' 'BINDINGS' {Assert-WlbCondition ($manifest.workflow.sha256 -ceq (Get-WlbHash $graphPath)) 'Workflow hash mismatch'} 'Changed raw workflow bytes rejected against unchanged manifest binding' $graphPath 'Workflow hash mismatch'
foreach ($entry in @(@{id='A-MODIFIED-POLICY';relative='policy\executor-policy.json';hash=$manifest.binding.policy_sha256},@{id='A-MODIFIED-RUNTIME';relative='policy\runtime-lock.json';hash=$manifest.binding.runtime_lock_sha256},@{id='A-MODIFIED-BIBLE';relative='bible\character-bible.v0.1.json';hash=$manifest.binding.character_bible_sha256},@{id='A-MODIFIED-CORE';relative='core\Wlb.Common.ps1';hash=$runtime.prepared_artifacts['core\Wlb.Common.ps1']})) {
    $path=Join-Path $FixtureRoot ($entry.id+'.txt')
    Write-NewText $path ([IO.File]::ReadAllText((Join-Path $Root $entry.relative))+"`n ")
    Expect-Reject $entry.id 'BINDINGS' {Assert-WlbCondition ($entry.hash -ceq (Get-WlbHash $path)) 'Bound artifact hash mismatch'} 'Reject changed bound raw bytes' $path 'hash mismatch'
}
Add-Result 'A-MODEL-HASH-VALIDATION' 'MANIFEST' 'Verify real model hashes for future model workflows' 'POC models must be empty; no model hash validator implemented' 'NOT_IMPLEMENTED' 'STATIC_FUTURE_OPTIONAL'
Add-Result 'A-INPUT-HASH-VALIDATION' 'MANIFEST' 'Verify real external-input hashes for future workflows' 'POC source_assets must be empty; no input hash validator implemented' 'NOT_IMPLEMENTED' 'STATIC_FUTURE_OPTIONAL'
# Exact original graph-validation statements (AST selected, no arbitrary node execution).
$tokens=$null;$errors=$null
$validatorAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'core\Test-WlbManifest.ps1'),[ref]$tokens,[ref]$errors)
$graphStatements=@($validatorAst.EndBlock.Statements | Where-Object {$_.Extent.StartLineNumber -ge 38 -and $_.Extent.EndLineNumber -le 47})
$graphText=($graphStatements | ForEach-Object {$_.Extent.Text}) -join "`n"
$graphCheck=[scriptblock]::Create($graphText)
Write-NewText (Join-Path $FixtureRoot 'Extracted-GraphPredicates.ps1') $graphText
$graph=New-Graph;& $graphCheck
Add-Result 'D-BASELINE-GRAPH' 'WORKFLOW' 'Closed EmptyImage -> SaveImage graph matches POC0' 'Exact original graph assertions passed; 640x360, batch 1, 3368601 (0x336699), link [1,0], fixed save prefix' 'PASS' 'EXECUTED_EXTRACTED_PREDICATES'
$graphMutations=[ordered]@{
    'D-UNKNOWN-NODE'={param($g) $g['1'].class_type='UnknownNode'};
    'D-MODEL-LOADER'={param($g) $g['1'].class_type='CheckpointLoaderSimple'};
    'D-CUSTOM-NODE'={param($g) $g['1'].class_type='CustomDangerousNode'};
    'D-PROVIDER-NODE'={param($g) $g['1'].class_type='ProviderAPINode'};
    'D-NETWORK-NODE'={param($g) $g['1'].class_type='HTTPRequest'};
    'D-COMMAND-NODE'={param($g) $g['1'].class_type='ExecuteShellCommand'};
    'D-SAMPLER'={param($g) $g['1'].class_type='KSampler'};
    'D-ADDITIONAL-NODE'={param($g) $g['3']=@{class_type='EmptyImage';inputs=@{}}};
    'D-UNEXPECTED-INPUT'={param($g) $g['1'].inputs.url='urn:NOT_A_NETWORK_REQUEST'};
    'D-UNEXPECTED-DESTINATION'={param($g) $g['2'].inputs.filename_prefix='..\escape'};
    'D-UNEXPECTED-LINK'={param($g) $g['2'].inputs.images=@('3',0)};
    'D-MODIFIED-CALIBRATION'={param($g) $g['1'].inputs.color=0};
    'D-STRING-WIDTH'={param($g) $g['1'].inputs.width='640'};
    'D-ARRAY-WIDTH'={param($g) $g['1'].inputs.width=@(640)};
    'D-STRING-BATCH'={param($g) $g['1'].inputs.batch_size='1'};
    'D-STRING-LINK-SLOT'={param($g) $g['2'].inputs.images=@('1','0')}
}
foreach ($entry in $graphMutations.GetEnumerator()) {
    $graph=New-Graph;& $entry.Value $graph
    $path=Join-Path $FixtureRoot ($entry.Key+'.json');Save-Json $path $graph
    Expect-Reject $entry.Key 'WORKFLOW' {& $graphCheck} 'Reject unsafe or incorrectly typed graph' $path
}
# Path guard tests call ONLY original helper, and never open an outside-root artifact.
$existing=Join-Path $FixtureRoot 'C-existing-destination.txt';Write-NewText $existing 'OWNED TEST FIXTURE; never overwrite'
$pathCases=[ordered]@{
    'C-RELATIVE-TRAVERSAL'='..\outside';
    'C-INROOT-TRAVERSAL'=($FixtureRoot+'\..\escape');
    'C-DOT-SEGMENT'=($FixtureRoot+'\.\new');
    'C-ABSOLUTE-OUTSIDE'='D:\outside\new';
    'C-PREFIX-SIBLING'='D:\WHAT-LIES-BTWN-PRODUCTION-OS-EVIL\new';
    'C-UNC'='\\NOT_A_REAL_SERVER\share\new';
    'C-EXTENDED-DEVICE'=('\\?\'+$FixtureRoot+'\new');
    'C-DRIVE-RELATIVE'='D:relative';
    'C-WRONG-DRIVE'='C:\outside\new';
    'C-ADS'=($existing+':alternate');
    'C-WILDCARD'=($FixtureRoot+'\*');
    'C-EMPTY'=''
}
foreach ($entry in $pathCases.GetEnumerator()) { Expect-Reject $entry.Key 'PATH' {Assert-WlbPath $entry.Value} 'Reject unauthorized or ambiguous path before file access' $entry.Value }
Expect-Reject 'C-COLLISION' 'PATH' {Assert-WlbPath $existing -MustBeAbsent} 'Reject existing destination' $existing 'Existing destination rejected'
Expect-Reject 'C-OVERWRITE-ATTEMPT' 'PATH' {Assert-WlbPath $existing -MustBeAbsent -File} 'Reject existing file via no-overwrite precheck (no write attempted)' $existing 'Existing destination rejected'
$alternate=$FixtureRoot.ToLowerInvariant().Replace('\','/')+'/C-new-absent'
$normalized=Assert-WlbPath $alternate -MustBeAbsent
Add-Result 'C-ALTERNATE-SEPARATORS-CASE' 'PATH' 'Canonicalize legitimate contained case/slash spelling' $normalized 'PASS' 'EXECUTED_ORIGINAL' $alternate
foreach ($kind in @('JUNCTION','SYMLINK','HARDLINK')) { Add-Result ('C-'+$kind) 'PATH' 'Reject link/reparse escape' 'No link object created; source has ancestor reparse-bit and file handle link-count checks, actual escape rejection untested' 'NOT_TESTED' 'STATIC_INFERENCE_ONLY' }
Add-Result 'C-TOCTOU' 'PATH' 'Enforce containment at actual open/create/rename' 'Validation/hash/read close and reopen handles; no atomic write/reservation API exists' 'NOT_IMPLEMENTED' 'STATIC_SOURCE'
Add-Result 'C-ATOMIC-NO-OVERWRITE' 'PATH' 'CreateNew + durable flush + rename without overwrite' 'Only existence precheck implemented; no executor write operation implemented' 'NOT_IMPLEMENTED' 'STATIC_SOURCE'
# Authorization-only extracted predicates. NOT a launcher invocation. No actual approval namespace is created.
$tokens=$null;$errors=$null
$launcherAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'core\Invoke-WlbJob.ps1'),[ref]$tokens,[ref]$errors)
$approvalText=(@($launcherAst.EndBlock.Statements | Where-Object {$_.Extent.StartLineNumber -ge 18 -and $_.Extent.EndLineNumber -le 35}) | ForEach-Object {$_.Extent.Text}) -join "`n"
$approvalCheck=[scriptblock]::Create($approvalText)
$terminal=@($launcherAst.EndBlock.Statements | Where-Object {$_.Extent.StartLineNumber -eq 40})[0].Extent.Text
Write-NewText (Join-Path $FixtureRoot 'Extracted-ApprovalPredicates.ps1') ($approvalText+"`n"+$terminal)
$ApprovalId=[guid]'00000000-0000-4000-8000-000000000003';$JobId='POC0-CALIBRATION-001'
$manifestPath=Join-Path $Root 'manifests\draft\POC0-CALIBRATION-001.json'
$graphPath=Join-Path $Root 'workflows\draft\poc0-calibration.api.json'
$lockPath=Join-Path $Root 'policy\runtime-lock.json';$policyPath=Join-Path $Root 'policy\executor-policy.json'
function New-UntrustedApprovalFixture {
    # Deliberately fabricated identity; never represents valid human authorization.
    [ordered]@{schema_version='wlb-approval/0.1';approval_id=$ApprovalId.ToString('D');job_id=$JobId;manifest_sha256=(Get-WlbHash $manifestPath);graph_sha256=(Get-WlbHash $graphPath);runtime_lock_sha256=(Get-WlbHash $lockPath);policy_sha256=(Get-WlbHash $policyPath);scope='ONE_GPU_JOB_ONLY';status='UNUSED';approved_by='FORGED_UNAUTHENTICATED_TEST_IDENTITY';expires_at_utc='2099-01-01T00:00:00Z'}
}
Expect-Reject 'B-MISSING-APPROVAL' 'AUTHORIZATION' {Read-WlbJson (Join-Path $FixtureRoot 'B-NONEXISTENT-APPROVAL.json')} 'Missing approval remains blocked (fixture path only)' '' 'Missing path'
$approvalMutations=[ordered]@{
    'B-EXPIRED'={param($a) $a.expires_at_utc='2000-01-01T00:00:00Z'};
    'B-DIFFERENT-JOB'={param($a) $a.job_id='OTHER-JOB'};
    'B-MODIFIED-MANIFEST'={param($a) $a.manifest_sha256=('0'*64)};
    'B-MODIFIED-GRAPH'={param($a) $a.graph_sha256=('0'*64)};
    'B-MODIFIED-RUNTIME'={param($a) $a.runtime_lock_sha256=('0'*64)};
    'B-MODIFIED-POLICY'={param($a) $a.policy_sha256=('0'*64)};
    'B-CONSUMED-STATUS'={param($a) $a.status='CONSUMED'};
    'B-WRONG-SCOPE'={param($a) $a.scope='ARBITRARY_JOB'};
    'B-UNKNOWN-OWNER'={param($a) $a.approved_by='UNKNOWN'};
    'B-WRONG-ID'={param($a) $a.approval_id='00000000-0000-4000-8000-000000000004'};
    'B-MALFORMED-EXPIRY'={param($a) $a.expires_at_utc='2099-01-01'}
}
foreach ($entry in $approvalMutations.GetEnumerator()) {
    $approval=New-UntrustedApprovalFixture;& $entry.Value $approval
    $path=Join-Path $FixtureRoot ($entry.Key+'-UNTRUSTED-FIXTURE.json');Save-Json $path $approval
    Expect-Reject $entry.Key 'AUTHORIZATION' {& $approvalCheck} 'Reject invalid untrusted approval fields/bindings' $path
}
$approval=New-UntrustedApprovalFixture
$path=Join-Path $FixtureRoot 'B-FORGED-UNTRUSTED-NOT-AUTHORITY.json';Save-Json $path $approval
try {
    & $approvalCheck
    Add-Result 'B-FORGED-AUTHENTICITY' 'AUTHORIZATION' 'Authenticate operator issuance' 'Fabricated approved_by passed all extracted predicates; NO approval consumed or activated; original unconditional gate still blocks' 'NOT_IMPLEMENTED' 'EXECUTED_EXTRACTED_PREDICATES' $path
} catch { Add-Result 'B-FORGED-AUTHENTICITY' 'AUTHORIZATION' 'Authenticate operator issuance' $_.Exception.Message 'PASS' 'EXECUTED_EXTRACTED_PREDICATES' $path }
$terminalBlock=[scriptblock]::Create($terminal)
Expect-Reject 'B-TERMINAL-CLOSED-GATE' 'AUTHORIZATION' {& $terminalBlock} 'Unconditional final refusal even after predicates' '' 'BLOCKED: G4/G5 remain closed'
Add-Result 'B-ATOMIC-ONE-TIME-CONSUMPTION' 'AUTHORIZATION' 'Atomically consume approval once before submission' 'No state transition, atomic claim, durable record or consumed namespace implementation' 'NOT_IMPLEMENTED' 'STATIC_SOURCE'
Add-Result 'B-REPLAY-RESTORED-UNUSED' 'AUTHORIZATION' 'Reject reused approval whose file is restored to UNUSED' 'Only current status string checked; durable one-time consumption absent' 'NOT_IMPLEMENTED' 'STATIC_SOURCE'
Add-Result 'B-REAL-LAUNCHER-INVOCATION' 'AUTHORIZATION' 'Confirm runtime launcher refusal end to end' 'BLOCKED_PENDING_AUTHORIZATION: real launcher not invoked per explicit Stage03C prohibition; AST and terminal throw tested separately' 'BLOCKED' 'NOT_EXECUTED'
foreach ($entry in @(
    @{id='E-EXCLUSIVE-OWNERSHIP';actual='max_active_jobs=1 is checked; no mutex, owned process identity or engine/job reservation'},
    @{id='E-SINGLE-USE-CONSUMPTION';actual='No approval consumption implemented'},
    @{id='E-DUPLICATE-SUBMISSION';actual='No persistent submission ledger or cross-process deduplication'},
    @{id='E-AMBIGUOUS-TIMEOUT';actual='No HTTP timeout or uncertain-state reconciliation implementation'},
    @{id='E-INTERRUPTION-RECOVERY';actual='No durable state machine or crash recovery'},
    @{id='E-CANCELLATION-AUTHORIZATION';actual='No owned cancellation or process termination implementation'},
    @{id='E-NO-AUTO-RETRY-CONTROL';actual='auto_retry=false is validated, but no adapter/retry path exists; future transport default retry behavior untested'},
    @{id='E-RESOURCE-ENFORCEMENT';actual='Only policy/manifest constants checked; no telemetry, freshness, preflight, watchdog or abort implementation'})) {
    Add-Result $entry.id 'EXECUTOR' 'Required before corresponding separately authorized runtime operation' $entry.actual 'NOT_IMPLEMENTED' 'STATIC_SOURCE'
}
Add-Result 'E-CURRENT-SUBMIT-PATH' 'EXECUTOR' 'No current job submission path' 'AST/source contains no HTTP client/REST invocation or process start; unconditional final throw present' 'PASS' 'STATIC_INFERENCE'
Add-Result 'E-CURRENT-RETRY-PATH' 'EXECUTOR' 'No current automatic resubmission' 'No submission implementation or retry loop exists in original launcher' 'PASS' 'STATIC_INFERENCE'
foreach ($key in $policy.budget.Keys) {
    Add-Result ('RESOURCE-CONSTANT-'+$key) 'RESOURCE' 'Expected POC0 policy cap equals manifest/schema constant' ('policy='+$policy.budget[$key]+'; manifest='+(New-Manifest).budget[$key]+'; schema='+$schema.properties.budget.properties[$key].const) 'PASS' 'EXECUTED_LOCAL_LOOKUP'
}
Add-Result 'RESOURCE-OUTPUT-SIZE-PRECHECK' 'RESOURCE' 'Bound size of inspected output file' 'Output checker line 27 rejects >268435456 bytes after job; no aggregate output/log cap or write-time enforcement' 'PASS' 'STATIC_SOURCE_ONLY'
Add-Result 'RESOURCE-RUNTIME-MEASUREMENTS' 'RESOURCE' 'Measure actual RAM/commit/private bytes/VRAM/runtime' 'BLOCKED_PENDING_AUTHORIZATION: no runtime started or GPU telemetry queried; no claim that POC fits' 'BLOCKED' 'NOT_EXECUTED'
Add-Result 'QC-FULL-PNG-DECODE' 'QC' 'Validate complete PNG CRC/decode and every pixel 0x336699' 'Only signature/IHDR and dimensions checked, no IDAT/IEND/CRC/decode/color implementation; accepted=false' 'NOT_IMPLEMENTED' 'STATIC_SOURCE'
Add-Result 'QC-EVIDENCE-AUTHENTICITY' 'QC' 'Authenticate device/resource, prompt ID, completion and operator verdict' 'Receipt fields exist but resource_evidence/gpu_device_evidence/completed_at_utc contents are not validated; prompt_id only nonblank; accepted=false' 'NOT_IMPLEMENTED' 'STATIC_SOURCE'
Add-Result 'QC-REAL-OUTPUT' 'QC' 'Validate real output' 'No job receipt/output exists; checker not run against production paths and no image generated' 'BLOCKED' 'NOT_EXECUTED'
foreach ($entry in @(
    @{id='ISOLATION-PROCESS';actual='No dedicated child-process ownership or isolation implementation'},
    @{id='ISOLATION-OS';actual='Policy explicitly os_sandbox=false; no OS boundary implementation'},
    @{id='ISOLATION-EGRESS';actual='Policy explicitly network_egress_enforcement=false; offline and loopback are not general egress controls'},
    @{id='ISOLATION-ACL';actual='No ACL/ownership validation code; policy access_control_validation=NOT_VERIFIED'},
    @{id='ISOLATION-GPU';actual='No live foreign GPU job preflight or owned engine lock implementation'},
    @{id='ISOLATION-CACHE-REDIRECTS';actual='Process-local cache redirects marked NOT_IMPLEMENTED; shared venv future candidate has same-account write permissions'})) {
    Add-Result $entry.id 'ISOLATION' 'Enforce or explicitly accept boundary before startup' $entry.actual 'NOT_IMPLEMENTED' 'STATIC_SOURCE'
}
Add-Result 'RUNTIME-SNAPSHOT' 'RUNTIME' 'Pin runnable isolated source and dependency identity' 'snapshot_created=false, inventory=[], snapshot_sha256=null, Python binary_hash=null; no source/dependency runtime verified' 'NOT_IMPLEMENTED' 'STATIC_SOURCE'
$after=Inventory
Save-Json (Join-Path $EvidenceRoot 'originals-after-tests.json') $after
for($i=0;$i -lt $before.Count;$i++) {
    $ok=$before[$i].bytes -eq $after[$i].bytes -and $before[$i].sha256 -ceq $after[$i].sha256 -and $before[$i].last_write_utc -ceq $after[$i].last_write_utc
    Add-Result ('PRESERVATION-'+$before[$i].path) 'PRESERVATION' 'Original bytes/hash/write-time unchanged' ('unchanged='+$ok) $(if($ok){'PASS'}else{'FAIL'}) 'EXECUTED_HASH'
}
$environment=[ordered]@{powershell=$PSVersionTable.PSVersion.ToString();powershell_path=(Get-Process -Id $PID).Path;os=$PSVersionTable.OS;timezone='Europe/Bucharest';local_date='2026-10-13';psscriptanalyzer_installed=($analyzer.Count -gt 0);native_link_helper=('WlbPrep.NativeFile' -as [type]).FullName;native_helper_scope='Fixed in-process Add-Type; read-only GetFileInformationByHandle; no persistent assembly requested';launcher_invoked=$false;python_invoked=$false;network_invoked=$false;server_started=$false;gpu_job_started=$false;model_imported=$false}
Save-Json (Join-Path $EvidenceRoot 'environment-and-scope.json') $environment
Save-Json (Join-Path $EvidenceRoot 'test-results.json') @($Results)
$matrix=@('# Stage03C TEST_MATRIX','', 'Evidence: actual original validators or extracted original predicates; extraction is component proof only. No launcher invocation.','', '| ID | Class | Expectation | Actual | Status | Evidence kind | Fixture |','| --- | --- | --- | --- | --- | --- | --- |')
foreach($row in $Results) {
    $cells=@($row.id,$row.classification,$row.expectation,$row.actual,$row.status,$row.evidence_kind,$row.fixture) | ForEach-Object {([string]$_).Replace('|','\|').Replace("`r",' ').Replace("`n",' ')}
    $matrix+='| '+($cells -join ' | ')+' |'
}
Write-NewText (Join-Path $EvidenceRoot 'TEST_MATRIX.md') ($matrix -join "`n")
$summary=[ordered]@{total_tests=$Results.Count;counts=@($Results | Group-Object status | ForEach-Object {[ordered]@{status=$_.Name;count=$_.Count}});original_count=$before.Count;original_total_bytes=($before | ForEach-Object {$_.bytes} | Measure-Object -Sum).Sum;reported_hash_rows=$reported.Count;receipt_hash_external_reference='NOT_AVAILABLE';next_gate='WAITING_HUMAN_REVIEW'}
Save-Json (Join-Path $EvidenceRoot 'summary.json') $summary
$summary | ConvertTo-Json -Depth 8
