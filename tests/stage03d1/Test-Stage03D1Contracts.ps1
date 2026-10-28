# Stage03D-1: only static validation and owned fixture copies. Never invoke launcher/runtime.
#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$Stage=Join-Path $Root 'tests\stage03d1'
$FixtureRoot=Join-Path $Stage 'fixtures-run2'
$EvidenceRoot=Join-Path $Stage 'evidence\run2'
$CaseRootBase=Join-Path $Stage 'composite-run2'
if(Test-Path -LiteralPath $FixtureRoot){throw 'Use a fresh test namespace; no evidence overwrite'}
$null=New-Item -ItemType Directory -Path $FixtureRoot,$CaseRootBase,$EvidenceRoot
function Write-NewText([string]$Path,[string]$Text){
    if(-not $Path.StartsWith($Stage+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Fixture write outside Stage03D1'}
    $parent=[IO.Path]::GetDirectoryName($Path)
    if(-not(Test-Path -LiteralPath $parent)){$null=New-Item -ItemType Directory -Path $parent}
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($Text)
    $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
function Save-Json([string]$Path,$Value){Write-NewText $Path (ConvertTo-Json -InputObject $Value -Depth 100)}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Clone-Graph{[IO.File]::ReadAllText((Join-Path $Root 'workflows\draft\poc0-calibration.api.json')) | ConvertFrom-Json -AsHashtable}
function Clone-Policy{[IO.File]::ReadAllText((Join-Path $Root 'policy\executor-policy.json')) | ConvertFrom-Json -AsHashtable}
$Rows=[Collections.Generic.List[object]]::new()
$Adaptations=[Collections.Generic.List[object]]::new()
function Record([string]$Id,[string]$Category,[string]$Expectation,[string]$Actual,[string]$Status,[string]$Kind,[string]$Fixture=''){
    $Rows.Add([ordered]@{id=$Id;category=$Category;expectation=$Expectation;actual=$Actual;status=$Status;evidence_kind=$Kind;fixture=$Fixture})
}
function Expect-Reject([string]$Id,[string]$Category,[scriptblock]$Action,[string]$Pattern,[string]$Fixture=''){
    try{$out=@(& $Action);Record $Id $Category 'Reject unsafe/malformed fixture' ('ACCEPTED: '+($out | ConvertTo-Json -Depth 12 -Compress)) 'FAIL' 'EXECUTED_STATIC_VALIDATION' $Fixture}
    catch{$status=if($_.Exception.Message -match $Pattern){'PASS'}else{'FAIL'};Record $Id $Category 'Reject unsafe/malformed fixture at expected guard' $_.Exception.Message $status 'EXECUTED_STATIC_VALIDATION' $Fixture}
}
. (Join-Path $Root 'core\Wlb.Common.ps1')
$actual=& (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode StaticReview
Record 'BASELINE-STATIC' 'BASELINE' 'Current DRAFT passes; executable=false; no approval/submission' ($actual | ConvertTo-Json -Compress) $(if(-not $actual.executable -and $actual.approval -ceq 'ABSENT' -and $actual.submission -ceq 'NOT_PERFORMED'){'PASS'}else{'FAIL'}) 'EXECUTED_ORIGINAL'
Expect-Reject 'BASELINE-EXECUTION-ELIGIBILITY' 'GATES' {& (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode ExecutionEligibility} 'BLOCKED: G1 preparation only'
Assert-WlbPoc0Graph (Clone-Graph)
Record 'D-BASELINE-GRAPH' 'GRAPH' 'Canonical graph remains unchanged/valid' '640x360; batch 1; 3368601; link ["1",0]; fixed prefix' 'PASS' 'EXECUTED_CURRENT_HELPER'
Assert-WlbExecutorPolicy (Clone-Policy)
Record 'POLICY-BASELINE' 'POLICY' 'Unchanged existing policy passes strict shape/type contract' 'PASS; declarations remain preparation-only and operational gaps persist' 'PASS' 'EXECUTED_CURRENT_HELPER'
# Replay all Stage03C graph, manifest and path cases relevant to strict contract remediation.
$previous=@(Get-Content -LiteralPath (Join-Path $Root 'tests\stage03c\evidence\ALL_TEST_RESULTS.json') -Raw | ConvertFrom-Json -AsHashtable)
$schemaPath=Join-Path $Root 'policy\shot-manifest.schema.json'
foreach($old in $previous){
    if($old.classification -eq 'WORKFLOW' -and $old.fixture -and $old.id -like 'D-*'){
        $path=Join-Path $FixtureRoot ($old.id+'.json');[IO.File]::Copy($old.fixture,$path,$false)
        Expect-Reject $old.id 'STAGE03C-GRAPH-REPLAY' {Assert-WlbPoc0Graph (Read-WlbJson $path)} 'BLOCKED:' $path
    }elseif($old.classification -eq 'MANIFEST' -and $old.evidence_kind -eq 'EXECUTED_COMPONENT' -and $old.fixture){
        $path=Join-Path $FixtureRoot ($old.id+'.json');[IO.File]::Copy($old.fixture,$path,$false)
        if($old.id -eq 'A-INVALID-LOCAL-SCHEMA-REF'){
            $raw=[IO.File]::ReadAllText((Join-Path $Root 'manifests\draft\POC0-CALIBRATION-001.json'))
            Expect-Reject $old.id 'STAGE03C-SCHEMA-REPLAY' {$raw | Test-Json -SchemaFile $path -ErrorAction Stop} 'Cannot parse|schema|reference' $path
        }elseif($old.id -in @('A-MALFORMED-JSON','A-DUPLICATE-KEY','A-CASE-COLLISION','A-NESTED-DUPLICATE','A-OVERSIZE-JSON','A-DEPTH-JSON')){
            Expect-Reject $old.id 'STAGE03C-JSON-REPLAY' {Read-WlbJson $path} 'BLOCKED:|Exception calling "Parse"' $path
        }else{
            Expect-Reject $old.id 'STAGE03C-MANIFEST-REPLAY' {$null=Read-WlbJson $path; if(-not([IO.File]::ReadAllText($path) | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)){throw 'Manifest schema rejected'}} 'schema|JSON is not valid' $path
        }
    }
}
# Graph scalar adversarial coverage: actual JSON round trips, not PowerShell parameter coercion.
$numericNames=@('width','height','batch_size','color')
foreach($name in $numericNames){
    $baseline=Clone-Graph;$value=$baseline['1'].inputs[$name]
    foreach($kind in @('STRING','ARRAY','OBJECT','BOOLEAN','NULL','FLOAT')){
        $graph=Clone-Graph
        $graph['1'].inputs[$name]=switch($kind){'STRING'{[string]$value};'ARRAY'{,@($value)};'OBJECT'{@{value=$value}};'BOOLEAN'{$true};'NULL'{$null};'FLOAT'{[double]$value}}
        $id='GRAPH-'+$name+'-'+$kind;$path=Join-Path $FixtureRoot ($id+'.json');Save-Json $path $graph
        Expect-Reject $id 'GRAPH-TYPE' {Assert-WlbPoc0Graph (Read-WlbJson $path)} ('Expected JSON Integer at graph/1/inputs/'+$name) $path
    }
}
$linkMutations=[ordered]@{
    'GRAPH-LINK-STRING'={param($g) $g['2'].inputs.images='1,0'}
    'GRAPH-LINK-OBJECT'={param($g) $g['2'].inputs.images=@{'0'='1';'1'=0}}
    'GRAPH-LINK-EMPTY'={param($g) $g['2'].inputs.images=@()}
    'GRAPH-LINK-SHORT'={param($g) $g['2'].inputs.images=@('1')}
    'GRAPH-LINK-LONG'={param($g) $g['2'].inputs.images=@('1',0,0)}
    'GRAPH-LINK-NODE-NUMBER'={param($g) $g['2'].inputs.images=@(1,0)}
    'GRAPH-LINK-NODE-ARRAY'={param($g) $g['2'].inputs.images=@(@('1'),0)}
    'GRAPH-LINK-SLOT-ARRAY'={param($g) $g['2'].inputs.images=@('1',@(0))}
    'GRAPH-LINK-SLOT-OBJECT'={param($g) $g['2'].inputs.images=@('1',@{value=0})}
    'GRAPH-LINK-SLOT-BOOLEAN'={param($g) $g['2'].inputs.images=@('1',$false)}
    'GRAPH-LINK-SLOT-NULL'={param($g) $g['2'].inputs.images=@('1',$null)}
    'GRAPH-LINK-SLOT-FLOAT'={param($g) $g['2'].inputs.images=@('1',0.0)}
    'GRAPH-NODE-CLASS-ARRAY'={param($g) $g['1'].class_type=@('EmptyImage')}
    'GRAPH-PREFIX-ARRAY'={param($g) $g['2'].inputs.filename_prefix=@('POC0-CALIBRATION-001/calibration')}
    'GRAPH-INPUTS-ARRAY'={param($g) $g['1'].inputs=@($g['1'].inputs)}
    'GRAPH-NODE-ARRAY'={param($g) $g['1']=@($g['1'])}
}
foreach($entry in $linkMutations.GetEnumerator()){
    $graph=Clone-Graph;& $entry.Value $graph
    $path=Join-Path $FixtureRoot ($entry.Key+'.json');Save-Json $path $graph
    Expect-Reject $entry.Key 'GRAPH-LINK-SHAPE' {Assert-WlbPoc0Graph (Read-WlbJson $path)} 'BLOCKED:' $path
}
# Discover every existing nested object/leaf, then challenge required keys and scalar types.
function Describe-Policy($Object,[string[]]$Segments=@()){
    [pscustomobject]@{kind='OBJECT';segments=$Segments}
    foreach($key in $Object.Keys){
        $path=@($Segments)+@([string]$key)
        if($Object[$key] -is [Collections.IDictionary]){Describe-Policy $Object[$key] $path}
        else{[pscustomobject]@{kind='LEAF';segments=$path;value=$Object[$key]}}
    }
}
function Policy-Parent($Object,[string[]]$Segments){
    $cursor=$Object
    for($i=0;$i -lt $Segments.Count-1;$i++){$cursor=$cursor[$Segments[$i]]}
    return ,$cursor
}
function Policy-Object($Object,[string[]]$Segments){$cursor=$Object;foreach($key in $Segments){$cursor=$cursor[$key]};return ,$cursor}
$graphObjects=@(Describe-Policy (Clone-Graph) | Where-Object {$_.kind -eq 'OBJECT'})
foreach($descriptor in $graphObjects){
    $node=Policy-Object (Clone-Graph) $descriptor.segments
    foreach($key in $node.Keys){
        $graph=Clone-Graph;$target=Policy-Object $graph $descriptor.segments;$null=$target.Remove($key)
        $id='GRAPH-MISSING-'+((@($descriptor.segments)+@($key)) -join '-')
        $path=Join-Path $FixtureRoot ($id+'.json');Save-Json $path $graph
        Expect-Reject $id 'GRAPH-REQUIRED-KEY' {Assert-WlbPoc0Graph (Read-WlbJson $path)} 'Unexpected key count|Missing key' $path
    }
    $graph=Clone-Graph;$target=Policy-Object $graph $descriptor.segments;$target['unexpected_stage03d1']=$true
    $id='GRAPH-EXTRA-'+$(if($descriptor.segments.Count){$descriptor.segments -join '-'}else{'ROOT'})
    $path=Join-Path $FixtureRoot ($id+'.json');Save-Json $path $graph
    Expect-Reject $id 'GRAPH-EXTRA-KEY' {Assert-WlbPoc0Graph (Read-WlbJson $path)} 'Unexpected key count' $path
    foreach($kind in @('ARRAY','STRING','NULL','NUMBER','BOOLEAN')){
        $graph=Clone-Graph;$target=Policy-Object $graph $descriptor.segments
        $replacement=switch($kind){'ARRAY'{,@($target)};'STRING'{'NOT_AN_OBJECT'};'NULL'{$null};'NUMBER'{0};'BOOLEAN'{$false}}
        if($descriptor.segments.Count){$parent=Policy-Parent $graph $descriptor.segments;$parent[$descriptor.segments[-1]]=$replacement}else{$graph=$replacement}
        $id='GRAPH-OBJECT-TYPE-'+$(if($descriptor.segments.Count){$descriptor.segments -join '-'}else{'ROOT'})+'-'+$kind
        $path=Join-Path $FixtureRoot ($id+'.json');Save-Json $path $graph
        Expect-Reject $id 'GRAPH-OBJECT-SHAPE' {Assert-WlbPoc0Graph (Read-WlbJson $path)} 'Expected JSON object' $path
    }
}
$descriptors=@(Describe-Policy (Clone-Policy))
foreach($descriptor in $descriptors){
    if($descriptor.kind -eq 'OBJECT'){
        $node=Policy-Object (Clone-Policy) $descriptor.segments
        foreach($key in $node.Keys){
            $policy=Clone-Policy;$target=Policy-Object $policy $descriptor.segments;$null=$target.Remove($key)
            $id='POLICY-MISSING-'+((@($descriptor.segments)+@($key)) -join '-')
            $path=Join-Path $FixtureRoot ($id+'.json');Save-Json $path $policy
            Expect-Reject $id 'POLICY-REQUIRED-KEY' {Assert-WlbExecutorPolicy (Read-WlbJson $path)} 'Unexpected key count|Missing key' $path
        }
        $policy=Clone-Policy;$target=Policy-Object $policy $descriptor.segments;$target['unexpected_stage03d1']=$true
        $id='POLICY-EXTRA-'+$(if($descriptor.segments.Count){$descriptor.segments -join '-'}else{'ROOT'})
        $path=Join-Path $FixtureRoot ($id+'.json');Save-Json $path $policy
        Expect-Reject $id 'POLICY-EXTRA-KEY' {Assert-WlbExecutorPolicy (Read-WlbJson $path)} 'Unexpected key count' $path
        foreach($kind in @('ARRAY','STRING','NULL','NUMBER','BOOLEAN')){
            $policy=Clone-Policy;$target=Policy-Object $policy $descriptor.segments
            $replacement=switch($kind){'ARRAY'{,@($target)};'STRING'{'NOT_AN_OBJECT'};'NULL'{$null};'NUMBER'{0};'BOOLEAN'{$false}}
            if($descriptor.segments.Count){$parent=Policy-Parent $policy $descriptor.segments;$parent[$descriptor.segments[-1]]=$replacement}else{$policy=$replacement}
            $id='POLICY-OBJECT-TYPE-'+$(if($descriptor.segments.Count){$descriptor.segments -join '-'}else{'ROOT'})+'-'+$kind
            $path=Join-Path $FixtureRoot ($id+'.json');Save-Json $path $policy
            Expect-Reject $id 'POLICY-OBJECT-SHAPE' {Assert-WlbExecutorPolicy (Read-WlbJson $path)} 'Expected JSON object' $path
        }
    }else{
        $types=if($descriptor.value -is [bool]){@('STRING','ARRAY','OBJECT','NULL','NUMBER')}
            elseif($descriptor.value -is [int] -or $descriptor.value -is [long]){@('STRING','ARRAY','OBJECT','NULL','BOOLEAN','FLOAT')}
            elseif($descriptor.value -is [array]){@('STRING','OBJECT','NULL','NUMBER','NULL-ELEMENT','NUMBER-ELEMENT')}
            elseif($descriptor.value -is [string]){@('ARRAY','OBJECT','NULL','NUMBER','BOOLEAN')}
            else{@('STRING','ARRAY','OBJECT','NUMBER','BOOLEAN')}
        foreach($kind in $types){
            $policy=Clone-Policy;$target=Policy-Parent $policy $descriptor.segments;$last=$descriptor.segments[-1]
            $target[$last]=switch($kind){'STRING'{[string]$descriptor.value};'ARRAY'{,@($descriptor.value)};'OBJECT'{@{value=$descriptor.value}};'NULL'{$null};'NUMBER'{0};'BOOLEAN'{$false};'FLOAT'{[double]$descriptor.value};'NULL-ELEMENT'{,@($null)};'NUMBER-ELEMENT'{,@(123)}}
            $id='POLICY-TYPE-'+($descriptor.segments -join '-')+'-'+$kind
            $path=Join-Path $FixtureRoot ($id+'.json');Save-Json $path $policy
            Expect-Reject $id 'POLICY-SCALAR-TYPE' {Assert-WlbExecutorPolicy (Read-WlbJson $path)} 'Expected JSON' $path
        }
    }
}
# Paths: relocated fixtures only, no external access or privileged link creation.
$existing=Join-Path $FixtureRoot 'path-existing.txt';Write-NewText $existing 'Own collision fixture; never overwrite'
foreach($old in $previous | Where-Object {$_.classification -eq 'PATH' -and $_.status -eq 'PASS' -and $_.id -ne 'C-ALTERNATE-SEPARATORS-CASE'}){
    $path=[string]$old.fixture
    if($old.id -in @('C-COLLISION','C-OVERWRITE-ATTEMPT')){Expect-Reject $old.id 'PATH-REGRESSION' {Assert-WlbPath $existing -MustBeAbsent} 'Existing destination rejected' $existing}
    else{$path=$path.Replace((Join-Path $Root 'tests\stage03c\fixtures'),$FixtureRoot);Expect-Reject $old.id 'PATH-REGRESSION' {Assert-WlbPath $path} 'BLOCKED:' $path}
}
$alternate=$FixtureRoot.ToLowerInvariant().Replace('\','/')+'/not-created'
$normalized=Assert-WlbPath $alternate -MustBeAbsent
Record 'C-ALTERNATE-SEPARATORS-CASE' 'PATH-REGRESSION' 'Legal contained spelling normalizes' $normalized 'PASS' 'EXECUTED_CURRENT_HELPER' $alternate
# Full-validator fixtures: all 15 Stage03C composite cases, plus additional binding/contract controls.
$files=@('core\Wlb.Common.ps1','core\Test-WlbManifest.ps1','core\Invoke-WlbJob.ps1','core\Test-WlbOutput.ps1','policy\shot-manifest.schema.json','policy\executor-policy.json','bible\character-bible.v0.1.json','workflows\draft\poc0-calibration.api.json','spec\FUTURE_EXECUTION_CONTRACT.md','policy\runtime-lock.json','manifests\draft\POC0-CALIBRATION-001.json')
function Composite([string]$Id,[scriptblock]$Mutation,[bool]$Reject,[string]$Pattern='BLOCKED:'){
    $caseRoot=Join-Path $CaseRootBase $Id
    $content=@{}
    foreach($relative in $files){
        $raw=[IO.File]::ReadAllText((Join-Path $Root $relative))
        if($relative -like '*.json'){$raw=$raw.Replace($Root.Replace('\','\\'),$caseRoot.Replace('\','\\'))}else{$raw=$raw.Replace($Root,$caseRoot)}
        $content[$relative]=$raw
    }
    $graph=$content['workflows\draft\poc0-calibration.api.json'] | ConvertFrom-Json -AsHashtable
    $policy=$content['policy\executor-policy.json'] | ConvertFrom-Json -AsHashtable
    $manifest=$content['manifests\draft\POC0-CALIBRATION-001.json'] | ConvertFrom-Json -AsHashtable
    $runtime=$content['policy\runtime-lock.json'] | ConvertFrom-Json -AsHashtable
    $settings=@{rebind_graph=$true;existing_output=$false;core_tamper=$false;policy_tamper=$false;runtime_tamper=$false;missing_lock_key=$false;wrap_graph=$false;wrap_policy=$false}
    & $Mutation $graph $manifest $policy $settings
    $content['workflows\draft\poc0-calibration.api.json']=$graph | ConvertTo-Json -Depth 100
    $content['policy\executor-policy.json']=$policy | ConvertTo-Json -Depth 100
    if($settings.wrap_graph){$content['workflows\draft\poc0-calibration.api.json']='['+$content['workflows\draft\poc0-calibration.api.json']+']'}
    if($settings.wrap_policy){$content['policy\executor-policy.json']='['+$content['policy\executor-policy.json']+']'}
    foreach($relative in $files | Where-Object {$_ -notin @('policy\runtime-lock.json','manifests\draft\POC0-CALIBRATION-001.json')}){Write-NewText (Join-Path $caseRoot $relative) $content[$relative]}
    foreach($key in @($runtime.prepared_artifacts.Keys)){$runtime.prepared_artifacts[$key]=Hash (Join-Path $caseRoot $key)}
    if($settings.missing_lock_key){$null=$runtime.prepared_artifacts.Remove('core\Invoke-WlbJob.ps1')}
    $lockPath=Join-Path $caseRoot 'policy\runtime-lock.json';Save-Json $lockPath $runtime
    if($settings.rebind_graph){$manifest.workflow.sha256=Hash (Join-Path $caseRoot 'workflows\draft\poc0-calibration.api.json')}
    $manifest.binding.policy_sha256=Hash (Join-Path $caseRoot 'policy\executor-policy.json')
    $manifest.binding.runtime_lock_sha256=Hash $lockPath
    $manifest.binding.character_bible_sha256=Hash (Join-Path $caseRoot 'bible\character-bible.v0.1.json')
    Save-Json (Join-Path $caseRoot 'manifests\draft\POC0-CALIBRATION-001.json') $manifest
    if($settings.existing_output){$null=New-Item -ItemType Directory -Path $manifest.output.directory -Force}
    if($settings.core_tamper){[IO.File]::AppendAllText((Join-Path $caseRoot 'core\Wlb.Common.ps1'),"`n# Own fixture mutation after fingerprint`n")}
    if($settings.policy_tamper){[IO.File]::AppendAllText((Join-Path $caseRoot 'policy\executor-policy.json'),"`n ")}
    if($settings.runtime_tamper){[IO.File]::AppendAllText($lockPath,"`n ")}
    $identical=(Hash (Join-Path $caseRoot 'core\Test-WlbManifest.ps1')) -ceq (Hash (Join-Path $Root 'core\Test-WlbManifest.ps1'))
    if(-not $identical){throw 'Fixture accidentally changed validation predicates'}
    $Adaptations.Add([ordered]@{id=$Id;case_root=$caseRoot;validator_identical_to_current=$identical;only_adaptations='Root relocation and own fixture fingerprints; controlled malformed input/byte changes; no predicate repair'})
    if($Reject){Expect-Reject $Id 'COMPOSITE' {& (Join-Path $caseRoot 'core\Test-WlbManifest.ps1') -Mode StaticReview} $Pattern $caseRoot}
    else{
        try{$out=& (Join-Path $caseRoot 'core\Test-WlbManifest.ps1') -Mode StaticReview;Record $Id 'COMPOSITE' 'Relocated canonical baseline remains nonexecutable' ($out | ConvertTo-Json -Compress) $(if(-not $out.executable){'PASS'}else{'FAIL'}) 'EXECUTED_RELOCATED_VALIDATOR' $caseRoot}
        catch{Record $Id 'COMPOSITE' 'Relocated baseline passes' $_.Exception.Message 'FAIL' 'EXECUTED_RELOCATED_VALIDATOR' $caseRoot}
    }
}
Composite 'COMPOSITE-BASELINE' {param($g,$m,$p,$s)} $false
Composite 'COMPOSITE-STRING-WIDTH' {param($g,$m,$p,$s) $g['1'].inputs.width='640'} $true 'Expected JSON Integer at graph/1/inputs/width'
Composite 'COMPOSITE-ARRAY-WIDTH' {param($g,$m,$p,$s) $g['1'].inputs.width=@(640)} $true 'Expected JSON Integer at graph/1/inputs/width'
Composite 'COMPOSITE-STRING-BATCH' {param($g,$m,$p,$s) $g['1'].inputs.batch_size='1'} $true 'Expected JSON Integer at graph/1/inputs/batch_size'
Composite 'COMPOSITE-STRING-LINK' {param($g,$m,$p,$s) $g['2'].inputs.images=@('1','0')} $true 'Expected JSON Integer at graph/2/inputs/images/1'
Composite 'COMPOSITE-POLICY-STRING-BOOL' {param($g,$m,$p,$s) $p.execution_enabled='false';$p.auto_retry='false'} $true 'Expected JSON Boolean at policy/'
Composite 'COMPOSITE-POLICY-STRING-BUDGET' {param($g,$m,$p,$s) $p.budget.max_incremental_commit_gib='4'} $true 'Expected JSON Integer at policy/budget/max_incremental_commit_gib'
Composite 'COMPOSITE-POLICY-STRING-CONCURRENCY' {param($g,$m,$p,$s) $p.max_active_jobs='1'} $true 'Expected JSON Integer at policy/max_active_jobs'
Composite 'COMPOSITE-STALE-GRAPH-HASH' {param($g,$m,$p,$s) $g['1'].inputs.width=641;$s.rebind_graph=$false} $true 'Workflow hash mismatch'
Composite 'COMPOSITE-EXTRA-NODE' {param($g,$m,$p,$s) $g['3']=@{class_type='ProviderNode';inputs=@{}}} $true 'Unexpected key count: graph'
Composite 'COMPOSITE-PROVIDER-NODE' {param($g,$m,$p,$s) $g['1'].class_type='ProviderNode'} $true 'Wrong source node'
Composite 'COMPOSITE-EXISTING-OUTPUT' {param($g,$m,$p,$s) $s.existing_output=$true} $true 'Existing destination rejected'
Composite 'COMPOSITE-REVIEWED-STATE' {param($g,$m,$p,$s) $m.state='REVIEWED'} $true 'G1 artifact must remain DRAFT'
Composite 'COMPOSITE-ENABLED-POLICY' {param($g,$m,$p,$s) $p.execution_enabled=$true} $true 'G1 policy must disable execution'
Composite 'COMPOSITE-CORE-TAMPER' {param($g,$m,$p,$s) $s.core_tamper=$true} $true 'Prepared artifact changed'
Composite 'COMPOSITE-POLICY-HASH-TAMPER' {param($g,$m,$p,$s) $s.policy_tamper=$true} $true 'Policy hash mismatch'
Composite 'COMPOSITE-RUNTIME-HASH-TAMPER' {param($g,$m,$p,$s) $s.runtime_tamper=$true} $true 'Runtime lock hash mismatch'
Composite 'COMPOSITE-POLICY-MISSING' {param($g,$m,$p,$s) $p.Remove('execution_enabled')} $true 'Unexpected key count: policy'
Composite 'COMPOSITE-POLICY-EXTRA' {param($g,$m,$p,$s) $p.arbitrary_url='urn:NOT_A_REAL_REQUEST'} $true 'Unexpected key count: policy'
Composite 'COMPOSITE-POLICY-NESTED-EXTRA' {param($g,$m,$p,$s) $p.budget.extra=1} $true 'Unexpected key count: policy/budget'
Composite 'COMPOSITE-POLICY-ALLOWLIST-SINGLE-STRING' {param($g,$m,$p,$s) $p.allowed_nodes=@('EmptyImage,SaveImage')} $true 'Node allowlist mismatch'
Composite 'COMPOSITE-POLICY-CAP-DRIFT' {param($g,$m,$p,$s) $p.budget.max_incremental_commit_gib=5} $true 'Budget changed'
Composite 'COMPOSITE-MANIFEST-FLOAT-BUDGET' {param($g,$m,$p,$s) $m.budget.max_incremental_commit_gib=4.0} $true 'Expected JSON Integer at manifest/budget/'
Composite 'COMPOSITE-MANIFEST-OUTSIDE-WORKFLOW' {param($g,$m,$p,$s) $m.workflow.path='D:\NOT_AUTHORIZED\workflow.json'} $true 'schema|JSON is not valid'
Composite 'COMPOSITE-MANIFEST-OUTSIDE-OUTPUT' {param($g,$m,$p,$s) $m.output.directory='D:\NOT_AUTHORIZED\output'} $true 'schema|JSON is not valid'
Composite 'COMPOSITE-MISSING-LOCK-KEY' {param($g,$m,$p,$s) $s.missing_lock_key=$true} $true 'Unexpected key count: runtime/prepared_artifacts'
Composite 'COMPOSITE-GRAPH-ROOT-ARRAY' {param($g,$m,$p,$s) $s.wrap_graph=$true} $true 'Expected JSON object: graph'
Composite 'COMPOSITE-POLICY-ROOT-ARRAY' {param($g,$m,$p,$s) $s.wrap_policy=$true} $true 'Expected JSON object: policy'
# Parse and inspect the unchanged launcher's terminal refusal; do not invoke the launcher.
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'core\Invoke-WlbJob.ps1'),[ref]$tokens,[ref]$errors)
$terminal=$ast.EndBlock.Statements[-1]
$closed=@($errors).Count -eq 0 -and $terminal -is [Management.Automation.Language.ThrowStatementAst] -and $terminal.Extent.Text -match 'G4/G5 remain closed'
Record 'LAUNCHER-UNCONDITIONAL-REFUSAL' 'GATES' 'Unchanged original launcher ends in unconditional refusal' $terminal.Extent.Text $(if($closed){'PASS'}else{'FAIL'}) 'STATIC_AST'
foreach($relative in @('core\Wlb.Common.ps1','core\Test-WlbManifest.ps1')){
    $tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root $relative),[ref]$tokens,[ref]$errors)
    Record ('SYNTAX-'+$relative) 'SYNTAX' 'Zero diagnostics' ('Diagnostics: '+@($errors).Count) $(if(@($errors).Count -eq 0){'PASS'}else{'FAIL'}) 'EXECUTED_PARSER'
}
# Operational gaps retain their prior classifications. No runtime/control implementation was added.
foreach($old in $previous | Where-Object {$_.status -in @('NOT_IMPLEMENTED','NOT_TESTED','BLOCKED')}){
    Record $old.id 'REMAINING-CONTROL' $old.expectation $old.actual $old.status 'RETAINED_STAGE03C_ASSESSMENT_NOT_EXECUTED'
}
Save-Json (Join-Path $EvidenceRoot 'test-results.json') @($Rows)
Save-Json (Join-Path $EvidenceRoot 'composite-adaptations.json') @($Adaptations)
$matrix=@('# Stage03D1 regression matrix','','PASS for negative cases means rejected at the expected static guard. Operational gaps retain prior statuses; they are not newly tested or implemented.','','| ID | Category | Expectation | Actual | Status | Evidence | Fixture |','| --- | --- | --- | --- | --- | --- | --- |')
foreach($row in $Rows){$cells=@($row.id,$row.category,$row.expectation,$row.actual,$row.status,$row.evidence_kind,$row.fixture) | ForEach-Object {([string]$_).Replace('|','\|').Replace("`r",' ').Replace("`n",' ')};$matrix+='| '+($cells -join ' | ')+' |'}
Write-NewText (Join-Path $EvidenceRoot 'REGRESSION_TEST_MATRIX.md') ($matrix -join "`n")
$closureIds=@('D-STRING-WIDTH','D-ARRAY-WIDTH','D-STRING-BATCH','D-STRING-LINK-SLOT','COMPOSITE-POLICY-STRING-BOOL','COMPOSITE-POLICY-STRING-BUDGET','COMPOSITE-POLICY-STRING-CONCURRENCY')
$closure=@(foreach($id in $closureIds){$closureRows=@($Rows | Where-Object {$_.id -ceq $id});if($closureRows.Count -ne 1){throw ('Closure row missing/duplicate: '+$id)};[ordered]@{id=$id;status=$closureRows[0].status;actual=$closureRows[0].actual;fixture=$closureRows[0].fixture}})
Save-Json (Join-Path $EvidenceRoot 'seven-distinct-closure.json') $closure
$mapping=@(foreach($old in $previous){$match=@($Rows | Where-Object {$_.id -ceq $old.id});[ordered]@{id=$old.id;stage03c_status=$old.status;stage03d1_status=if($match.Count){$match[0].status}else{'NOT_REEXECUTED_HISTORICAL_ONLY'};coverage=if($match.Count){$match[0].evidence_kind}else{'Historical inventory/provenance/other-component checks remain preserved; current bindings and preservation separately verified'}}})
Save-Json (Join-Path $EvidenceRoot 'stage03c-coverage-map.json') $mapping
$summary=[ordered]@{total_rows=$Rows.Count;executed_checks=@($Rows | Where-Object {$_.evidence_kind -ne 'RETAINED_STAGE03C_ASSESSMENT_NOT_EXECUTED'}).Count;retained_assessments=@($Rows | Where-Object {$_.evidence_kind -eq 'RETAINED_STAGE03C_ASSESSMENT_NOT_EXECUTED'}).Count;counts=@($Rows | ForEach-Object {[pscustomobject]$_} | Group-Object status | ForEach-Object {[ordered]@{status=$_.Name;count=$_.Count}});seven_distinct_closed=@($closure | Where-Object {$_.status -eq 'PASS'}).Count;composite_cases=$Adaptations.Count;launcher_invoked=$false;runtime_started=$false;network_invoked=$false;gpu_job=$false}
Save-Json (Join-Path $EvidenceRoot 'test-summary.json') $summary
$summary | ConvertTo-Json -Depth 10
if(@($Rows | Where-Object {$_.status -eq 'FAIL'}).Count){exit 1}
