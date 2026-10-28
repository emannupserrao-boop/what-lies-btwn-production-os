# Finalizes preserved Stage03C evidence without rerunning tests or touching original artifacts.
#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$TestRoot=Join-Path $Root 'tests\stage03c'
$EvidenceRoot=Join-Path $TestRoot 'evidence'
function Write-NewText([string]$Path,[string]$Text) {
    if(-not $Path.StartsWith($Root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Evidence write outside root'}
    if([IO.File]::Exists($Path)) {
        if([IO.File]::ReadAllText($Path) -ceq $Text){return}
        throw 'Existing evidence differs; refusing overwrite'
    }
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($Text)
    $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
function Save-Json([string]$Path,$Value){Write-NewText $Path ($Value | ConvertTo-Json -Depth 100)}
$component=@(Get-Content -LiteralPath (Join-Path $EvidenceRoot 'test-results.json') -Raw | ConvertFrom-Json -AsHashtable)
$composite=@(Get-Content -LiteralPath (Join-Path $EvidenceRoot 'composite-results.json') -Raw | ConvertFrom-Json -AsHashtable)
$all=@($component)+@($composite)
if($all.Count -ne 218){throw 'Unexpected result count; review report must be reconciled'}
Save-Json (Join-Path $EvidenceRoot 'ALL_TEST_RESULTS.json') $all
$matrix=@('# Stage03C consolidated TEST_MATRIX','', 'Component and composite rows are distinct checks; repeated defects are identified in the main report. Static-only PASS rows do not imply runtime enforcement.','', '| ID | Class | Expectation | Actual | Classification | Evidence kind | Fixture |','| --- | --- | --- | --- | --- | --- | --- |')
foreach($row in $all){
    $cells=@($row.id,$row.classification,$row.expectation,$row.actual,$row.status,$row.evidence_kind,$row.fixture) | ForEach-Object {([string]$_).Replace('|','\|').Replace("`r",' ').Replace("`n",' ')}
    $matrix+='| '+($cells -join ' | ')+' |'
}
Write-NewText (Join-Path $EvidenceRoot 'ALL_TEST_MATRIX.md') ($matrix -join "`n")
$before=@(Get-Content -LiteralPath (Join-Path $EvidenceRoot 'originals-before.json') -Raw | ConvertFrom-Json -AsHashtable)
foreach($row in $before){if($row.last_write_utc -is [datetime]){$row.last_write_utc=$row.last_write_utc.ToUniversalTime().ToString('o')}}
$after=@(foreach($row in $before){
    $path=Join-Path $Root $row.path;$item=Get-Item -LiteralPath $path -Force
    [ordered]@{path=$row.path;bytes=$item.Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();last_write_utc=$item.LastWriteTimeUtc.ToString('o');unchanged=($row.bytes -eq $item.Length -and $row.sha256 -ceq (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -and $row.last_write_utc -ceq $item.LastWriteTimeUtc.ToString('o'))}
})
if(@($after | Where-Object {-not $_.unchanged}).Count){throw 'Original artifact preservation check failed'}
Save-Json (Join-Path $EvidenceRoot 'originals-final.json') $after
$gates=@(foreach($relative in @('approvals','jobs','workflows\approved','runtimes')){[ordered]@{path=Join-Path $Root $relative;exists=Test-Path -LiteralPath (Join-Path $Root $relative)}})
if(@($gates | Where-Object {$_.exists}).Count){throw 'Unexpected real execution namespace exists'}
$policy=Get-Content -LiteralPath (Join-Path $Root 'policy\executor-policy.json') -Raw | ConvertFrom-Json -AsHashtable
$manifest=Get-Content -LiteralPath (Join-Path $Root 'manifests\draft\POC0-CALIBRATION-001.json') -Raw | ConvertFrom-Json -AsHashtable
if($policy.execution_enabled -ne $false -or $manifest.state -cne 'DRAFT' -or $manifest.approval_contract.record_created -ne $false){throw 'Original gate state changed'}
$gatesEvidence=[ordered]@{namespaces=$gates;execution_enabled=$policy.execution_enabled;manifest_state=$manifest.state;approval_record_created=$manifest.approval_contract.record_created;launcher_invoked=$false;network_invoked=$false;gpu_job_started=$false;python_invoked=$false;image_generated=$false}
Save-Json (Join-Path $EvidenceRoot 'closed-gates-final.json') $gatesEvidence
$summary=[ordered]@{stage03c_status='COMPLETE_WITH_LIMITATIONS';runtime_startup_status='BLOCKED';total_checks=$all.Count;counts=@($all | Group-Object status | ForEach-Object {[ordered]@{status=$_.Name;count=$_.Count}});original_count=$before.Count;original_total_bytes=($before | ForEach-Object {$_.bytes} | Measure-Object -Sum).Sum;original_unchanged_count=@($after | Where-Object {$_.unchanged}).Count;reported_hash_comparisons=12;reported_mismatches=0;receipt_external_hash_comparison='NOT_TESTED';next_gate='WAITING_HUMAN_REVIEW';harness_incidents=@('Component run: all 203 checks saved before summary dictionary aggregation error; aggregation corrected in test harness only; no rerun of preserved component tests','Composite attempt 1: missing fixture manifest parent before first case; 10 partial files preserved under composite; corrected run used composite-run2 and completed 15 cases','Finalizer attempt 1: JSON timestamp auto-conversion to DateTime caused false string comparison failure; read-only diagnosis confirmed all hashes/bytes/timestamps unchanged; normalized loaded timestamps and retained identical consolidated files without overwrite')}
Save-Json (Join-Path $EvidenceRoot 'summary.json') $summary
$ledger=Get-Content -LiteralPath (Join-Path $EvidenceRoot 'command-ledger-final-source.json') -Raw | ConvertFrom-Json -AsHashtable
Save-Json (Join-Path $EvidenceRoot 'COMMANDS.json') $ledger
$commands=@('# Stage03C command and file-edit ledger','','All shell commands below were issued through exec_command. Nested commands are preserved in the three saved test/finalization scripts. No real launcher, Python, server, network client or GPU job was invoked.','')
foreach($entry in $ledger.commands){
    $commands+='## '+$entry.id+' — '+$entry.purpose
    $commands+=''
    $commands+='Result: '+$entry.result
    $commands+=''
    $commands+='```powershell'
    $commands+=$entry.cmd
    $commands+='```'
    $commands+=''
}
$commands+='## File-edit tool operations';$commands+=''
foreach($entry in $ledger.file_edits){$commands+='- '+$entry}
$commands+=''
$commands+='No tool-driven write outside the Production OS root; supporting contract/attachment reads are enumerated above. Source-only AST extraction via scriptblock creation is fixed to original validator predicates; graph classes and approval fixture text are data and are never executed as code.'
Write-NewText (Join-Path $EvidenceRoot 'COMMANDS.md') ($commands -join "`n")
$inventoryPath=Join-Path $EvidenceRoot 'CREATED_FILES.csv'
$attestationPath=Join-Path $EvidenceRoot 'NO_MUTATION_ATTESTATION.md'
$originalSet=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($row in $before){$null=$originalSet.Add((Join-Path $Root $row.path))}
$known=@(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Where-Object {-not $originalSet.Contains($_.FullName)} | ForEach-Object {$_.FullName})
$createdPaths=@($known)+@($inventoryPath,$attestationPath)
$createdPaths=@($createdPaths | Sort-Object -Unique)
$attestation=@('# Stage03C NO_MUTATION_ATTESTATION','', 'Date: 2026-10-13; Europe/Bucharest.','', ('Original artifacts: '+$before.Count+'; total bytes: '+$summary.original_total_bytes+'; final SHA-256, size and UTC last-write-time preservation: 13/13 unchanged.'),'', ('Files created: '+$createdPaths.Count+'. Every absolute path is listed below and in CREATED_FILES.csv.'),'', 'All directed file creations are within the Production OS root. All code changes concern newly created test harnesses or explicit fixture mutations; no Stage03B artifact was edited. The incomplete first composite fixture is preserved. No cleanup/deletion occurred.','', 'Original policy.execution_enabled=false; manifest.state=DRAFT; approval_contract.record_created=false. Real approvals, jobs, workflows\approved and runtimes namespaces remain absent. Test-only copied trees are not approved or runtime artifacts.','', 'No real launcher invocation, approval activation/consumption, Python, ComfyUI/LTX startup, GPU job, image generation, external API/network request, install/download, shared environment/production-asset change, host ACL/firewall/registry/service/global environment change or Git operation. Read-only Get-Acl inspections and fixed in-process native handle-query compilation were performed. This is an operation attestation and original-artifact proof, not a host-wide before/after comparison or an OS sandbox claim.','', 'Commands and file-edit tool operations: COMMANDS.md / COMMANDS.json; nested script operations: Invoke-Stage03CValidation.ps1, Invoke-CompositeFixtureTests.ps1, Complete-Stage03CEvidence.ps1.','', 'The inventory and this attestation list themselves but omit their own bytes/hash to avoid circular evidence. Other files receive actual raw-byte SHA-256.','', '## Created files','')
foreach($path in $createdPaths){$attestation+='- `'+$path+'`'}
$attestation+='';$attestation+='NEXT_GATE: WAITING_HUMAN_REVIEW. Stage03D not performed.'
Write-NewText $attestationPath ($attestation -join "`n")
$inventory=@(foreach($path in $createdPaths){
    if($path -in @($inventoryPath,$attestationPath)){[pscustomobject]@{absolute_path=$path;bytes='';sha256='';note='Listed; self-referential metadata excluded'}}
    else{$item=Get-Item -LiteralPath $path -Force;[pscustomobject]@{absolute_path=$path;bytes=$item.Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();note='Created in Stage03C; actual final raw bytes'}}
})
Write-NewText $inventoryPath (($inventory | ConvertTo-Csv -NoTypeInformation) -join "`n")
$actualCreated=@(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Where-Object {-not $originalSet.Contains($_.FullName)})
if($actualCreated.Count -ne $createdPaths.Count){throw 'Created-file inventory mismatch'}
$report=Join-Path $Root 'STAGE03C_REVIEW_REPORT.md'
$proposal=Join-Path $Root 'STAGE03D_REMEDIATION_PROPOSAL.md'
foreach($path in @($report,$proposal)){if(-not(Test-Path -LiteralPath $path)){throw 'Required delivery document missing'}}
$allPreserved=@(foreach($row in $before){$item=Get-Item -LiteralPath (Join-Path $Root $row.path) -Force;($item.Length -eq $row.bytes -and (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $row.sha256 -and $item.LastWriteTimeUtc.ToString('o') -ceq $row.last_write_utc)})
if($allPreserved -contains $false){throw 'Final delivery preservation failed'}
[ordered]@{summary=$summary;created_files=$createdPaths.Count;inventory_count_matches=$true;originals_unchanged=13;report_sha256=(Get-FileHash -LiteralPath $report -Algorithm SHA256).Hash.ToLowerInvariant();proposal_sha256=(Get-FileHash -LiteralPath $proposal -Algorithm SHA256).Hash.ToLowerInvariant();stage03d_implemented=$false} | ConvertTo-Json -Depth 10
