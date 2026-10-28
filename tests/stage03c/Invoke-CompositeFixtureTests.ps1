# Stage03C deeper diagnostics: relocated test-only copies, original validation predicates unchanged.
# This is not Stage03D remediation. No original artifact is written and no launcher is invoked.
#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$TestRoot=Join-Path $Root 'tests\stage03c'
$CompositeRoot=Join-Path $TestRoot 'composite-run2'
$EvidenceRoot=Join-Path $TestRoot 'evidence'
$null=New-Item -ItemType Directory -Path $CompositeRoot
$Rows=[Collections.Generic.List[object]]::new()
$Locations=[Collections.Generic.List[object]]::new()
$Originals=@('core\Wlb.Common.ps1','core\Test-WlbManifest.ps1','core\Invoke-WlbJob.ps1','core\Test-WlbOutput.ps1','policy\shot-manifest.schema.json','policy\executor-policy.json','bible\character-bible.v0.1.json','workflows\draft\poc0-calibration.api.json','spec\FUTURE_EXECUTION_CONTRACT.md','policy\runtime-lock.json','manifests\draft\POC0-CALIBRATION-001.json')
function Write-NewText([string]$Path,[string]$Text) {
    if (-not $Path.StartsWith($TestRoot+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Test namespace required'}
    $parent=[IO.Path]::GetDirectoryName($Path)
    if(-not(Test-Path -LiteralPath $parent)) {$null=New-Item -ItemType Directory -Path $parent}
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($Text)
    $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)} finally {$stream.Dispose()}
}
function Hash([string]$Path) {(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Run-Case([string]$Id,[scriptblock]$Mutation,[bool]$RejectExpected,[string]$Expectation,[string]$ExpectedError='') {
    $CaseRoot=Join-Path $CompositeRoot $Id
    $null=New-Item -ItemType Directory -Path $CaseRoot
    $content=@{}
    foreach ($relative in $Originals) {
        $raw=[IO.File]::ReadAllText((Join-Path $Root $relative))
        if ($relative -like '*.json') {$raw=$raw.Replace($Root.Replace('\','\\'),$CaseRoot.Replace('\','\\'))}
        else {$raw=$raw.Replace($Root,$CaseRoot)}
        $content[$relative]=$raw
    }
    $graph=$content['workflows\draft\poc0-calibration.api.json'] | ConvertFrom-Json -AsHashtable
    $manifest=$content['manifests\draft\POC0-CALIBRATION-001.json'] | ConvertFrom-Json -AsHashtable
    $policy=$content['policy\executor-policy.json'] | ConvertFrom-Json -AsHashtable
    $runtime=$content['policy\runtime-lock.json'] | ConvertFrom-Json -AsHashtable
    $mode=@{rebind_graph=$true;existing_output=$false;tamper_core_after_binding=$false}
    & $Mutation $graph $manifest $policy $mode
    $content['workflows\draft\poc0-calibration.api.json']=$graph | ConvertTo-Json -Depth 100
    $content['policy\executor-policy.json']=$policy | ConvertTo-Json -Depth 100
    foreach ($relative in $Originals | Where-Object {$_ -notin @('policy\runtime-lock.json','manifests\draft\POC0-CALIBRATION-001.json')}) {
        $path=Join-Path $CaseRoot $relative
        $parent=[IO.Path]::GetDirectoryName($path)
        if (-not (Test-Path -LiteralPath $parent)) {$null=New-Item -ItemType Directory -Path $parent}
        Write-NewText $path $content[$relative]
    }
    foreach ($key in @($runtime.prepared_artifacts.Keys)) {$runtime.prepared_artifacts[$key]=Hash (Join-Path $CaseRoot $key)}
    $runtimePath=Join-Path $CaseRoot 'policy\runtime-lock.json'
    Write-NewText $runtimePath ($runtime | ConvertTo-Json -Depth 100)
    if($mode.rebind_graph){$manifest.workflow.sha256=Hash (Join-Path $CaseRoot 'workflows\draft\poc0-calibration.api.json')}
    $manifest.binding.policy_sha256=Hash (Join-Path $CaseRoot 'policy\executor-policy.json')
    $manifest.binding.runtime_lock_sha256=Hash $runtimePath
    $manifest.binding.character_bible_sha256=Hash (Join-Path $CaseRoot 'bible\character-bible.v0.1.json')
    Write-NewText (Join-Path $CaseRoot 'manifests\draft\POC0-CALIBRATION-001.json') ($manifest | ConvertTo-Json -Depth 100)
    if($mode.existing_output){$null=New-Item -ItemType Directory -Path $manifest.output.directory -Force}
    if($mode.tamper_core_after_binding){[IO.File]::AppendAllText((Join-Path $CaseRoot 'core\Wlb.Common.ps1'),"`n# controlled fixture-only comment change after fingerprint`n")}
    $predicateUnchanged=(Hash (Join-Path $CaseRoot 'core\Test-WlbManifest.ps1')) -ceq (Hash (Join-Path $Root 'core\Test-WlbManifest.ps1'))
    if(-not $predicateUnchanged){throw 'Fixture unexpectedly altered validator predicates'}
    $Locations.Add([ordered]@{case=$Id;root=$CaseRoot;validator_identical_to_original=$predicateUnchanged;adaptations='Root literals relocated in fixture helper/schema/policy/manifest/spec only; fixture hashes rebound; no validator predicate changed';existing_output_directory=$mode.existing_output;post_binding_comment_mutation=$mode.tamper_core_after_binding})
    try {
        $actual=& (Join-Path $CaseRoot 'core\Test-WlbManifest.ps1') -Mode StaticReview
        $status=if($RejectExpected){'FAIL'}else{'PASS'}
        $Rows.Add([ordered]@{id=$Id;classification='COMPOSITE';expectation=$Expectation;actual=($actual | ConvertTo-Json -Compress);status=$status;evidence_kind='EXECUTED_RELOCATED_VALIDATOR';fixture=$CaseRoot})
    }catch{
        $status=if($RejectExpected -and (-not $ExpectedError -or $_.Exception.Message -match $ExpectedError)){'PASS'}else{'FAIL'}
        $Rows.Add([ordered]@{id=$Id;classification='COMPOSITE';expectation=$Expectation;actual=$_.Exception.Message;status=$status;evidence_kind='EXECUTED_RELOCATED_VALIDATOR';fixture=$CaseRoot})
    }
}
Run-Case 'COMPOSITE-BASELINE' {param($g,$m,$p,$s)} $false 'Relocated baseline passes with executable=false'
Run-Case 'COMPOSITE-STRING-WIDTH' {param($g,$m,$p,$s) $g['1'].inputs.width='640'} $true 'Reject graph width string even with matching rebound fixture hash'
Run-Case 'COMPOSITE-ARRAY-WIDTH' {param($g,$m,$p,$s) $g['1'].inputs.width=@(640)} $true 'Reject graph width array even with matching rebound fixture hash'
Run-Case 'COMPOSITE-STRING-BATCH' {param($g,$m,$p,$s) $g['1'].inputs.batch_size='1'} $true 'Reject graph batch string even with matching rebound fixture hash'
Run-Case 'COMPOSITE-STRING-LINK' {param($g,$m,$p,$s) $g['2'].inputs.images=@('1','0')} $true 'Reject graph link slot string even with matching rebound fixture hash'
Run-Case 'COMPOSITE-POLICY-STRING-BOOL' {param($g,$m,$p,$s) $p.execution_enabled='false';$p.auto_retry='false'} $true 'Reject policy boolean strings'
Run-Case 'COMPOSITE-POLICY-STRING-BUDGET' {param($g,$m,$p,$s) $p.budget.max_incremental_commit_gib='4'} $true 'Reject incorrectly typed policy budget'
Run-Case 'COMPOSITE-POLICY-STRING-CONCURRENCY' {param($g,$m,$p,$s) $p.max_active_jobs='1'} $true 'Reject incorrectly typed policy concurrency'
Run-Case 'COMPOSITE-STALE-GRAPH-HASH' {param($g,$m,$p,$s) $g['1'].inputs.width=641;$s.rebind_graph=$false} $true 'Reject graph changed without updated manifest binding' 'Workflow hash mismatch'
Run-Case 'COMPOSITE-EXTRA-NODE' {param($g,$m,$p,$s) $g['3']=@{class_type='ProviderNode';inputs=@{}}} $true 'Reject additional graph node despite matching fixture fingerprint' 'Unexpected key count: graph'
Run-Case 'COMPOSITE-PROVIDER-NODE' {param($g,$m,$p,$s) $g['1'].class_type='ProviderNode'} $true 'Reject replaced provider node despite matching fixture fingerprint' 'Wrong source node'
Run-Case 'COMPOSITE-EXISTING-OUTPUT' {param($g,$m,$p,$s) $s.existing_output=$true} $true 'Reject existing fixture job output namespace' 'Existing destination rejected'
Run-Case 'COMPOSITE-REVIEWED-STATE' {param($g,$m,$p,$s) $m.state='REVIEWED'} $true 'Preparation validator still requires DRAFT' 'G1 artifact must remain DRAFT'
Run-Case 'COMPOSITE-ENABLED-POLICY' {param($g,$m,$p,$s) $p.execution_enabled=$true} $true 'Reject true execution policy' 'G1 policy must disable execution'
Run-Case 'COMPOSITE-CORE-TAMPER' {param($g,$m,$p,$s) $s.tamper_core_after_binding=$true} $true 'Reject fixture helper altered after lock fingerprint' 'Prepared artifact changed'
Write-NewText (Join-Path $EvidenceRoot 'composite-results.json') (@($Rows) | ConvertTo-Json -Depth 20)
Write-NewText (Join-Path $EvidenceRoot 'composite-fixture-adaptations.json') (@($Locations) | ConvertTo-Json -Depth 20)
@($Rows) | ConvertTo-Json -Depth 10
