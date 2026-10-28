#requires -Version 7.6
# Independent read-only snapshot/source/canonical audit. Writes only new Stage03E evidence/report files.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS'
$Evidence=Join-Path $Root 'tests\stage03e\evidence'
$Destination=Join-Path $Root 'runtimes\core\ComfyUI'
function Hash([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
function Json([string]$p){ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($p)) -AsHashtable -DateKind String}
function Check([bool]$Condition,[string]$Reason){if(-not $Condition){throw "BLOCKED: $Reason"}}
function WriteNew([string]$Path,[string]$Text){
 Check ($Path.StartsWith($Root+'\',[StringComparison]::OrdinalIgnoreCase)) 'Report outside project'
 $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$stream.Write([Text.UTF8Encoding]::new($false).GetBytes($Text));$stream.Flush($true)}finally{$stream.Dispose()}
}
$outcome=Json (Join-Path $Evidence 'copy-outcome.json')
Check ($outcome.snapshot_state -ceq 'STAGED_NOT_ACTIVATED' -and $outcome.files -eq 619 -and $outcome.bytes -eq 9533695) 'Copy outcome not complete'
$actualPath=Join-Path $Evidence 'actual-snapshot-inventory.csv'
Check ((Hash $actualPath) -ceq $outcome.actual_inventory_sha256) 'Actual inventory hash changed'
$allowlist=@(Import-Csv -LiteralPath (Join-Path $Root 'spec\G4_SNAPSHOT_COPY_INVENTORY.csv'))
$actual=@(Import-Csv -LiteralPath $actualPath)
$before=Json (Join-Path $Evidence 'source-before.json')
$sourceMap=@{};foreach($record in $before){$sourceMap[$record.relative_path]=$record}
$actualMap=@{};foreach($record in $actual){Check (-not $actualMap.ContainsKey($record.relative_path)) 'Duplicate actual inventory';$actualMap[$record.relative_path]=$record}
$directoryEvidence=Json (Join-Path $Evidence 'directory-identities.json')
. (Join-Path $Root 'core\Wlb.StartupFiles.ps1')
Initialize-WlbStartupNative
$held=[Collections.Generic.List[object]]::new()
$checks=[Collections.Generic.List[object]]::new()
try{
 foreach($record in $directoryEvidence){
  $handle=[WlbStartup.ReadOnlyNative]::OpenDirectory($record.path)
  try{Check ([WlbStartup.ReadOnlyNative]::Identity($handle) -ceq $record.identity -and [WlbStartup.ReadOnlyNative]::FinalPath($handle).Equals($record.path,[StringComparison]::OrdinalIgnoreCase)) 'Post-copy parent identity changed';$held.Add($handle)}catch{$handle.Dispose();throw}
 }
 foreach($row in $allowlist){
  Check ($actualMap.ContainsKey($row.relative_path)) 'Missing approved snapshot file'
  $snapshot=$actualMap[$row.relative_path];$source=$sourceMap[$row.relative_path]
  foreach($side in @('SOURCE','DESTINATION')){
   if($side -ceq 'SOURCE'){$path=$row.source;$expectedId=$source.file_identity}else{$path=$row.planned_destination;$expectedId=$snapshot.file_identity}
   $file=Get-Item -LiteralPath $path -Force
   Check (-not $file.PSIsContainer -and -not ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) 'File link/type changed'
   $stream=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
   try{
    $id=[WlbStartup.ReadOnlyNative]::Identity($stream.SafeFileHandle)
    $links=[WlbStartup.ReadOnlyNative]::LinkCount($stream.SafeFileHandle)
    $final=[WlbStartup.ReadOnlyNative]::FinalPath($stream.SafeFileHandle)
    $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant()
    Check ($id -ceq $expectedId -and $links -eq 1 -and $final.Equals($path,[StringComparison]::OrdinalIgnoreCase) -and $stream.Length -eq [long]$row.bytes -and $hash -ceq $row.sha256) "Independent $side integrity failure: $($row.relative_path)"
    $checks.Add([pscustomobject]@{side=$side;relative_path=$row.relative_path;path=$path;bytes=$stream.Length;sha256=$hash;file_identity=$id;hardlink_count=$links;status='PASS_CONTENT_SIZE_PATH_IDENTITY_ONLY'})
   }finally{$stream.Dispose()}
  }
 }
 $enumerated=@(Get-ChildItem -LiteralPath $Destination -File -Recurse -Force)
 Check ($enumerated.Count -eq 619 -and ($enumerated | Measure-Object Length -Sum).Sum -eq 9533695) 'Independent enumeration aggregate'
 foreach($file in $enumerated){Check ($actualMap.ContainsKey($file.FullName.Substring($Destination.Length+1))) 'Extra snapshot file'}
 $baseline=Json (Join-Path $Evidence 'all-existing-before.json')
 foreach($record in $baseline){Check ((Hash (Join-Path $Root $record.path)) -ceq $record.sha256 -and (Get-Item -LiteralPath (Join-Path $Root $record.path)).Length -eq $record.bytes) "Canonical/history baseline changed: $($record.path)"}
 $known=@{};foreach($record in $baseline){$known[$record.path]=$true}
 foreach($file in (Get-ChildItem -LiteralPath $Root -Recurse -File -Force)){$relative=$file.FullName.Substring($Root.Length+1);Check ($known.ContainsKey($relative) -or $relative.StartsWith('tests\stage03e\',[StringComparison]::OrdinalIgnoreCase) -or $file.FullName.StartsWith($Destination+'\',[StringComparison]::OrdinalIgnoreCase)) "Unexpected new path: $relative"}
 $startup=Json (Join-Path $Root 'policy\startup-policy.json')
 $executor=Json (Join-Path $Root 'policy\executor-policy.json')
 $identity=Json (Join-Path $Root 'policy\startup-identity.json')
 $lock=Json (Join-Path $Root 'policy\runtime-lock.json')
 $manifest=Json (Join-Path $Root 'manifests\draft\POC0-CALIBRATION-001.json')
 Check (-not $startup.real_startup_enabled -and -not $startup.gpu_jobs_enabled -and -not $executor.execution_enabled -and $startup.consent_status -ceq 'ABSENT' -and $manifest.state -ceq 'DRAFT') 'Execution authority changed'
 Check ($identity.snapshot.status -ceq 'NOT_CREATED' -and -not $identity.snapshot.exists -and $null -eq $identity.snapshot.actual_inventory_sha256 -and -not $lock.origin.snapshot_created) 'Canonical snapshot activated'
 foreach($name in $startup.human_parameters.Keys){Check ($startup.human_parameters[$name].status -ceq 'UNKNOWN' -and $null -eq $startup.human_parameters[$name].value) 'Human parameter bound without approval'}
 foreach($key in $lock.prepared_artifacts.Keys){Check ((Hash (Join-Path $Root $key)) -ceq $lock.prepared_artifacts[$key]) 'Existing artifact binding changed'}
 $dependencies=Json (Join-Path $Root 'spec\G4_DEPENDENCY_METADATA.json')
 foreach($dep in $dependencies){foreach($m in $dep.metadata){Check ((Hash $m.path) -ceq $m.sha256) 'Metadata changed before report'}}
 WriteNew (Join-Path $Evidence 'independent-integrity-checks.csv') ((($checks | ConvertTo-Csv -NoTypeInformation) -join "`r`n")+"`r`n")
 $summary=[ordered]@{stage='03E';verified_utc=[DateTime]::UtcNow.ToString('o');snapshot_state='STAGED_NOT_ACTIVATED';source_file_checks=619;destination_file_checks=619;bytes_each_side=9533695;groups=11;parent_directory_identities_rechecked=$directoryEvidence.Count;baseline_files_preserved=$baseline.Count;existing_changes=0;extra_snapshot_files=0;all_files_single_link=$true;actual_inventory_sha256=Hash $actualPath;integrity_pass_scope='CONTENT_SIZE_ALLOWLIST_PATH_FILE_IDENTITY_ONLY';imports='NOT_PERFORMED';startup='NOT_PERFORMED';python='NOT_EXECUTED';gpu='NOT_EXECUTED';compatibility='NOT_VERIFIED';g4='BLOCKED_NOT_AUTHORIZED';g5='NOT_AUTHORIZED';next_gate='WAITING_HUMAN_REVIEW'}
 WriteNew (Join-Path $Evidence 'independent-verification-summary.json') (ConvertTo-Json $summary -Depth 12)
 # Requirements/METADATA comparison is text-only, not a resolver/import/ABI test.
 $depRows=@();foreach($dep in $dependencies){$version=(@($dep.header | Where-Object {$_ -like 'Version:*'}) -join '; ') -replace '^Version:\s*','';$depRows+=[pscustomobject]@{name=$dep.name;version_from_metadata=$version;metadata_files=$dep.metadata.Count;verification='METADATA_HASH_ONLY';runtime='NOT_VERIFIED'}}
 WriteNew (Join-Path $Evidence 'dependency-review.json') (ConvertTo-Json -InputObject $depRows -Depth 8)
 $groupTable=@('| Grupo | Arquivos | Bytes |','|---|---:|---:|');foreach($group in ($actual | Group-Object group | Sort-Object Name)){$groupTable+='| '+$group.Name+' | '+$group.Count+' | '+[long](($group.Group | Measure-Object bytes -Sum).Sum)+' |'}
 $depTable=@('| Distribuição | Versão declarada em METADATA | Estado |','|---|---|---|');foreach($dep in $depRows){$depTable+='| '+$dep.name+' | '+$dep.version_from_metadata+' | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |'}
 $canonicalPaths=@('policy\startup-identity.json','policy\startup-policy.json','policy\runtime-lock.json','policy\executor-policy.json','manifests\draft\POC0-CALIBRATION-001.json','core\Invoke-WlbJob.ps1')
 $canonicalTable=@('| Arquivo canônico preservado | SHA-256 antes = depois |','|---|---|');foreach($path in $canonicalPaths){$canonicalTable+='| '+$path+' | '+(Hash (Join-Path $Root $path))+' |'}
 $report=@'
# WHAT LIES BTWN — STAGE03E_IMPLEMENTATION_RECEIPT

## A. STAGE03E_STATUS

COMPLETE_WITH_LIMITATIONS. Snapshot de conteúdo copiado e verificado: STAGED_NOT_ACTIVATED. Apenas preparação de código, sem autoridade de execução. G2/G3/G4/G5/ALPHA fechados. Os resultados PASS desta entrega significam exclusivamente integridade de bytes, tamanho, allowlist e identidade/caminhos observados; não representam imports, startup, GPU ou funcionamento do ComfyUI.

## B. EXACT_SOURCE_INVENTORY_VERIFICATION

Origem fixa: D:\Musicas\Bitter-End-Visual-Local\ComfyUI. Destino fixo: D:\WHAT-LIES-BTWN-PRODUCTION-OS\runtimes\core\ComfyUI. CSV original preservado como única allowlist, SHA-256 a8e69c205a7f98a1aa3bb34d399201a61e76c112c233f7202abc8b25ba2941eb. Validadas todas as 619 linhas, 619 origens e destinos únicos, 9.533.695 bytes, 11 grupos. Nenhuma expansão, lista substituta, download ou seleção automática.

Pins adicionais conferidos integralmente: G4_DEPENDENCY_METADATA.json 97710ef8f044f13c1eb2c570ba188a697ce301c17aa871ef573a0afbbaabe901; startup-identity.json 7f42355c74483f6965f6eb6e837b5ac09d71485fcde610882bc627c3dd420edb; startup-policy.json e1db244a744f6ee228956d7fdd199c89737822299bab7785b58ba8c9e527795f. Os oito inputs autoritativos foram lidos e analisados integralmente; CSV e JSON de dependências processados em todas as linhas/entradas. Recibo D2 preservado: b19aed5ac764b6d5acd7543d46033fe358d2f4eb15d684ddf2e9f545ec8db5ac. Baseline completo: 2.269 arquivos, zero divergências antes da cópia e zero alterações depois.

Preflight antes da criação do destino: arquivos presentes/legíveis, caminhos canônicos sob raízes fixas, tamanhos e hashes exatos, reparse/junction/symlink recusados, hardlink count=1, diretórios ancestrais validados e retidos por handles sem delete sharing, destino ausente. Todos os 619 handles de origem permaneceram abertos com FileShare.Read, negando escrita/exclusão convencional durante a tentativa. Espaço disponível e margem conservadora de conteúdo + 64 MiB registrados em precopy-verification.json; nenhuma política de recurso foi alterada. ValidateOnly passou sem criar destino/reserva; a cópia teve uma única tentativa.

__GROUP_TABLE__

## C. COPY_EXECUTION_RECEIPT

Tentativa __ATTEMPT__. Início UTC __START__; fim UTC __END__. O diretório do snapshot estava ausente. Mutex local dedicado à cópia e reserva persistente tests/stage03e/evidence/snapshot-reservation.json, criada com CreateNew, excluem outra tentativa deste procedimento; reserva não é aprovação nem consentimento G4/G5. Diretórios novos criados por CreateDirectoryW com erro se preexistentes, pais retidos e rechecados; somente diretórios derivados dos destinos aprovados. Nenhum link criado. Arquivos escritos exclusivamente via FileMode.CreateNew, escritor exclusivo, CopyTo a partir do handle validado, Flush(true), hash de saída e identidade por volume/file index. Cada fonte rechecada antes/depois da respectiva cópia; todas rechecadas ao final por handle retido e novo handle de caminho.

copy-execution-ledger.json registra os 619 pares, hashes, tamanhos, identidades de origem/destino e flush. copy-outcome.json registra tentativa, horários, diretórios criados e estado. Nenhuma falha ocorreu na tentativa. Código possui parada conservadora sem retry/overwrite/cleanup: falhas ficam PARTIAL_BLOCKED, com arquivos criados e cópias verificadas registrados, e reserva mantida. Caminhos de falha/interrupção/power loss não foram injetados nesta etapa; não se afirma prova dessas condições. O script de cópia não deve ser reexecutado contra o destino/reserva existente.

## D. ACTUAL_SNAPSHOT_INVENTORY_AND_SHA256

Inventário efetivo independente da listagem de cópia: D:\WHAT-LIES-BTWN-PRODUCTION-OS\tests\stage03e\evidence\actual-snapshot-inventory.csv. Obtido por enumeração real do destino após a cópia, novos handles de leitura, comparação de identidade com a criação, tamanho/hash e comparação com a allowlist. SHA-256: __ACTUAL_HASH__. Exatamente 619 arquivos e 9.533.695 bytes. Zero arquivos adicionais e nenhum diretório fora dos pais necessários da allowlist; nenhum .git, peso, custom node, cache ou conteúdo do usuário acrescentado. Logs/recibos/reserva ficam fora do snapshot.

Uma segunda verificação, em invocação PowerShell distinta após liberação dos handles da cópia, reabriu fontes e destino: 619 verificações de origem + 619 de destino, identidades/caminhos/hardlinks/bytes/hashes iguais. Evidências: independent-integrity-checks.csv e independent-verification-summary.json. Nenhum arquivo .py/.pyi foi executado/importado. O inventário efetivo inclui identidade local NTFS, portanto seu hash não é uma assinatura universal de distribuição nem autoridade de runtime.

## E. SOURCE_AND_DESTINATION_INTEGRITY

Os 619 conteúdos de origem preservados em tamanho/hash e identidade observada; source-before.json/source-after.json registram os pares. Os 2.269 arquivos preexistentes do Production OS preservados byte a byte; não houve changeset canônico nesta etapa. Evidências históricas C/D1/D2 intactas. Os 48 arquivos METADATA/WHEEL/RECORD das 16 dependências foram somente lidos/rehashados e permanecem iguais aos pins.

__CANONICAL_TABLE__

LIMITAÇÕES: identidades por volume/file index e checks representam observações do filesystem Windows durante os handles e a auditoria; file IDs podem ser reutilizados posteriormente e não são autenticação independente. Handles/ACLs herdadas não criam sandbox, isolamento forte ou proteção contra quem pode modificar código/política sob a mesma conta. Nenhuma ACL foi modificada; cópia cria arquivos novos com permissões herdadas, sem clonar permissões/metadata de produção. Flush(true) solicita persistência; falha elétrica/hardware não foi testada. Depois da liberação dos handles o conteúdo pode ser alterado por alguém autorizado no host; futura integração deve revalidar tudo. Leituras podem afetar metadados de acesso geridos pelo sistema; a preservação atestada é de conteúdo/tamanho/identidade observada, não de todo atributo/timestamp do host.

## F. LICENSE_AND_DEPENDENCY_LIMITATIONS

LICENSE foi copiado sem alteração: 35.823 bytes, SHA-256 230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809. A leitura integral do texto é preservada no arquivo; cabeçalho GNU GPL Version 3 e referência license.file=LICENSE em pyproject são evidências locais. Nenhuma conclusão jurídica de distribuição, auditoria per-file ou resolução de exceções foi realizada. pyproject.toml (2.092 bytes) e requirements.txt (557 bytes) estão explicitamente incluídos, com hashes do CSV; não são instalação/configuração do ambiente.

__DEP_TABLE__

As versões acima são declarações dos metadados, não imports nem verificação de binários/ABI. RECORD foi hashado como texto, não usado para certificar todos os binários listados. Os 16 pacotes não constituem fechamento completo das dependências declaradas ou dos imports; requirements também cita, por exemplo, workflow templates, embedded docs, torchsde, einops, tokenizers, sentencepiece, scipy, tqdm, av, requests e outras dependências. Nenhum pacote foi instalado/resolvido. Python/Torch/torchaudio/torchvision/CUDA/frontend/bibliotecas nativas permanecem RUNTIME_NOT_VERIFIED; o pin histórico da entrada Python em startup-identity não foi transformado em validação de interpretador/stdlib/DLLs.

## G. EXCLUDED_FILES_AND_UNRESOLVED_IMPORTS

Apenas os 619 arquivos do CSV foram copiados. Exclusões por ausência na allowlist: root models/pesos/checkpoints, custom_nodes, comfy_api_nodes/providers, .git, credenciais, caches, input/output/user/temp, ambiente Python e dados/configs/assets não aprovados. Diretórios nested comfy/ldm/models e comfy_api/input contêm Python aprovado; não são pesos nem dados de entrada. Outros exemplos/módulos explicitamente no CSV foram mantidos exatamente, sem seleção por nome. 616 arquivos .py/.pyi e três arquivos de proveniência/configuração declarativa (LICENSE, pyproject.toml, requirements.txt).

alembic.ini existe na origem (3.314 bytes), mas NÃO consta do CSV e NÃO foi copiado. app/database/db.py linhas 73–80 constrói caminho para esse arquivo e Config(config_path); o fechamento de configuração/migrações permanece pendente. Não se infere startup viável sem esse arquivo, nem falha necessariamente em todos os modos. pyproject referencia README.md, que não integra esta cópia; não houve instalação do pacote. Outros non-Python data/assets, frontend e efeitos de inicialização/imports permanecem não demonstrados. Qualquer necessidade de acrescentar arquivo requer revisão humana da allowlist em escopo distinto; não há correção automática de configuração/runtime.

## H. G4_READINESS_AND_REMAINING_BLOCKERS

A integridade desta cópia está verificada; G4 continua BLOCKED / NOT_AUTHORIZED. STAGED_NOT_ACTIVATED é evidência separada; startup-identity.snapshot.status=NOT_CREATED, exists=false e actual_inventory_sha256=null e runtime-lock.snapshot_created=false foram preservados intencionalmente como contrato canônico anterior não ativado. Essa diferença exige revisão futura explícita, não ajuste silencioso para aparentar prontidão.

Changeset candidato do próximo gate, NÃO aplicado: revisar a completude/necessidade de alembic.ini/non-code/license notices; integrar o inventário efetivo em startup-identity; revisar validação de identidade que atualmente exige NOT_CREATED/exists=false; atualizar somente bindings legitimamente afetados em runtime-lock e manifesto sem promover DRAFT; manter execução desabilitada até consentimento e controle operacional aprovados. Revisar candidato Python/stdlib/DLLs e dependências nativas. Não aumentar a allowlist ou copiar configurações nesta entrega.

Demais bloqueios: identidade humana/CPU budget/polling/freshness UNKNOWN; consentimento confiável específico de startup ausente; protocolo single-attempt/recovery, observadores reais de PID/creation time/executable/porta, start/stop exclusivo do processo próprio, exclusão real do executor, telemetria operacional RAM/commit/private/VRAM/GPU/disk, watchdog/deadline e validação supervisionada real não implementados/verificados. Limites 8/10/4/4/2 GiB, 120 s/30 s e 256 MiB preservados; thresholds não são hard caps. SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0 não demonstra isolamento OS/egress/REST; flags offline/loopback não bloqueiam todos os acessos. As 24 pendências operacionais anteriores continuam pendentes.

## I. G5_STATUS

NOT_AUTHORIZED. execution_enabled=false; gpu_jobs_enabled=false; real_startup_enabled=false; consent_status=ABSENT; manifesto DRAFT; launcher original byte-idêntico com recusa incondicional. Não houve G4, approval real, consumo de approval, POST/submissão HTTP, job GPU, cancelamento ou geração. Aprovação/consumo atômico/replay/submissão/monitoramento de job/outputs permanecem bloqueios futuros. G2/G3/ALPHA igualmente fechados.

## J. NO_OUT_OF_SCOPE_MUTATION_ATTESTATION

Alterações realizadas: criação dos 619 arquivos aprovados no snapshot, diretórios pais necessários e arquivos novos de procedimento/evidência/relatório Stage03E dentro do Production OS. Zero alterações dos 2.269 arquivos anteriores; nenhuma fonte ou ambiente de produção alterado. Inventário de novos artefatos: tests/stage03e/evidence/stage03e-new-files.csv, com hashes; dois arquivos de metadados auto-referentes excluídos e explicados em delivery-integrity.json. Todas as fontes inspecionadas e metadados das dependências rechecados. Nenhum arquivo externo à allowlist no snapshot.

PowerShell/.NET e helpers Windows locais fizeram somente validação/IO de cópia/relatórios; Add-Type compilou helpers fixos em memória do processo, sem instalação ou execução de conteúdo ComfyUI/Python. Nenhum Python/import/CUDA, servidor, GPU, API externa/REST, download, instalação, produção MIRAE/PULSE/LTX, aprovação G4/G5, alteração ACL/firewall/registro/serviços/global environment ou operação Git commit/merge/push/tag. Não houve encerramento de processo. Não se afirma auditoria omnisciente de todo o host: preservação externa cobre os 619 arquivos envolvidos e os 48 metadados lidos. Direitos de host e escopo supervisionado não foram ampliados.

## K. NEXT_GATE

WAITING_HUMAN_REVIEW. STOP_AFTER_DELIVERY. Snapshot STAGED_NOT_ACTIVATED; não prosseguir automaticamente a integração, imports, startup, G4/G5, Alpha Gen ou MCP. Uma cópia íntegra não é autorização ou prova de compatibilidade operacional.
'@
 $report=$report.Replace('__GROUP_TABLE__',($groupTable -join "`n")).Replace('__DEP_TABLE__',($depTable -join "`n")).Replace('__CANONICAL_TABLE__',($canonicalTable -join "`n")).Replace('__ATTEMPT__',$outcome.attempt_id).Replace('__START__',$outcome.start_utc).Replace('__END__',$outcome.end_utc).Replace('__ACTUAL_HASH__',$outcome.actual_inventory_sha256)
 WriteNew (Join-Path $Root 'STAGE03E_IMPLEMENTATION_RECEIPT.md') $report
 ConvertTo-Json $summary -Depth 12
}catch{
 $failure=[ordered]@{snapshot_state='PARTIAL_BLOCKED';verification_error=$_.Exception.Message;copy_not_retried=$true;no_cleanup_or_overwrite=$true;next_gate='WAITING_HUMAN_REVIEW'}
 try{WriteNew (Join-Path $Evidence ('verification-failure-'+[Guid]::NewGuid().ToString()+'.json')) (ConvertTo-Json $failure -Depth 8)}catch{Write-Output 'Verification failure evidence could not be written'}
 throw
}finally{foreach($handle in $held){$handle.Dispose()}}
