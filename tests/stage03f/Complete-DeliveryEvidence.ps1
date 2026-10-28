#requires -Version 7.6
# Final readonly preservation audit and new Stage03F evidence/report files only.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS';$Stage=Join-Path $Root 'tests\stage03f';$Evidence=Join-Path $Stage 'evidence'
function Check([bool]$c,[string]$why){if(-not $c){throw "BLOCKED: $why"}}
function Hash([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
function Json([string]$p){return ,(Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
function WriteNew([string]$p,[string]$text){$permitted=$p.StartsWith($Stage+'\',[StringComparison]::OrdinalIgnoreCase) -or $p -ceq (Join-Path $Root 'STAGE03F_IMPLEMENTATION_RECEIPT.md');Check $permitted 'Report outside authorized evidence scope';$s=[IO.File]::Open($p,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write([Text.UTF8Encoding]::new($false).GetBytes($text));$s.Flush($true)}finally{$s.Dispose()}}
function Save([string]$p,$v){WriteNew $p (ConvertTo-Json -InputObject $v -Depth 60)}
$allowed=@('policy\startup-identity.json','core\Wlb.Startup.ps1','core\Start-WlbRuntime.ps1','policy\runtime-lock.json','manifests\draft\POC0-CALIBRATION-001.json')
$before=Json (Join-Path $Evidence 'all-existing-before.json');$changed=[Collections.Generic.List[object]]::new()
foreach($b in $before){$p=Join-Path $Root $b.relative_path;Check (Test-Path -LiteralPath $p) "Prior file missing: $p";$h=Hash $p;if($h -cne $b.sha256 -or (Get-Item -LiteralPath $p).Length -ne $b.bytes){Check ($b.relative_path -cin $allowed) "Out-of-scope mutation: $p";$changed.Add([pscustomobject]@{path=$p;relative_path=$b.relative_path;before_sha256=$b.sha256;after_sha256=$h})}}
Check ($changed.Count -eq 5) 'Exactly five authorized canonical changes expected'
Save (Join-Path $Evidence 'canonical-changes.json') @($changed)
$known=@{};foreach($b in $before){$known[$b.relative_path]=$true}
foreach($f in Get-ChildItem -LiteralPath $Root -Recurse -File -Force){$rel=$f.FullName.Substring($Root.Length+1);Check ($known.ContainsKey($rel) -or $rel.StartsWith('tests\stage03f\',[StringComparison]::OrdinalIgnoreCase) -or $rel -ceq 'STAGE03F_CONFIGURATION_ASSESSMENT.md') "Unexpected new path: $rel"}
. (Join-Path $Root 'core\Wlb.Startup.ps1')
$identity=Read-WlbJson (Join-Path $Root 'policy\startup-identity.json');$lock=Read-WlbJson (Join-Path $Root 'policy\runtime-lock.json')
Assert-WlbStagedRuntimeLock $lock $identity
$snapshot=Test-WlbStagedSnapshotContent $identity
$draft=& (Join-Path $Root 'core\Test-WlbManifest.ps1') -Mode StaticReview
$policy=Read-WlbJson (Join-Path $Root 'policy\startup-policy.json');Assert-WlbStartupPolicy $policy
Check ((Hash (Join-Path $Root 'policy\startup-policy.json')) -ceq 'e1db244a744f6ee228956d7fdd199c89737822299bab7785b58ba8c9e527795f') 'Startup policy modified'
Check ((Hash (Join-Path $Root 'core\Invoke-WlbJob.ps1')) -ceq '2278e14b700fe722c5ca6d7e2d6e2245c3b88b1288fdee006da2cdd415a5fe66') 'Job launcher modified'
foreach($p in @('approvals','jobs','workflows\approved')){Check (-not(Test-Path -LiteralPath (Join-Path $Root $p))) "Real authority/output namespace present: $p"}
$mPath=Join-Path $Root 'manifests\draft\POC0-CALIBRATION-001.json';$oldPath=Join-Path $Stage 'baseline\manifests\draft\POC0-CALIBRATION-001.json';$m=Json $mPath;$old=Json $oldPath
Check ([IO.File]::ReadAllText($mPath).Replace($m.binding.runtime_lock_sha256,$old.binding.runtime_lock_sha256) -ceq [IO.File]::ReadAllText($oldPath)) 'Manifest changed beyond runtime binding'
Check ($m.state -ceq 'DRAFT' -and -not $m.approval_contract.record_created) 'Draft/approval changed'
$externalSourceChecks=@(Import-Csv -LiteralPath (Join-Path $Evidence 'snapshot-checks-before.csv') | Where-Object {$_.side -ceq 'SOURCE'})
. (Join-Path $Root 'core\Wlb.StartupFiles.ps1');Initialize-WlbStartupNative
foreach($f in $externalSourceChecks){$s=[IO.File]::Open($f.path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read);try{$h=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($s)).ToLowerInvariant();Check ($h -ceq $f.sha256 -and $s.Length -eq [long]$f.bytes -and [WlbStartup.ReadOnlyNative]::Identity($s.SafeFileHandle) -ceq $f.file_identity -and [WlbStartup.ReadOnlyNative]::LinkCount($s.SafeFileHandle) -eq 1 -and [WlbStartup.ReadOnlyNative]::FinalPath($s.SafeFileHandle).Equals($f.path,[StringComparison]::OrdinalIgnoreCase)) 'Production source mutated/replaced'}finally{$s.Dispose()}}
$deps=Json (Join-Path $Root 'spec\G4_DEPENDENCY_METADATA.json');foreach($dep in $deps){foreach($f in $dep.metadata){Check ((Hash $f.path) -ceq $f.sha256) 'Pinned external metadata mutated'}}
$extraPins=Json (Join-Path $Evidence 'dependency-run2\configuration-source-pins.json');foreach($f in $extraPins){Check ((Hash $f.path) -ceq $f.sha256) 'Configuration/frontend source mutated'}
$review=Json (Join-Path $Evidence 'dependency-run2\dependency-metadata-review.json');foreach($dep in $review){Check ((Hash $dep.metadata_path) -ceq $dep.metadata_sha256) 'Reviewed metadata mutated'}
Check ((Hash $identity.python.path) -ceq $identity.python.sha256) 'Python entry fingerprint drift'
$directoryEvidence=Json (Join-Path $Root 'tests\stage03e\evidence\directory-identities.json')
foreach($d in $directoryEvidence){$h=[WlbStartup.ReadOnlyNative]::OpenDirectory($d.path);try{Check ([WlbStartup.ReadOnlyNative]::Identity($h) -ceq $d.identity -and [WlbStartup.ReadOnlyNative]::FinalPath($h).Equals($d.path,[StringComparison]::OrdinalIgnoreCase)) 'Stage03E parent directory replacement'}finally{$h.Dispose()}}
$suitePaths=@('tests\stage03f\evidence\run3\stage03f-results.json','tests\stage03f\regression\evidence\run2\test-results.json','tests\stage03f\evidence\final-file-results.json','tests\stage03f\evidence\final-contract-results.json','tests\stage03f\evidence\binding-results-run2.json','tests\stage03f\evidence\additional-results.json')
$rows=[Collections.Generic.List[object]]::new();$suites=[Collections.Generic.List[object]]::new()
foreach($rel in $suitePaths){$values=Json (Join-Path $Root $rel);$suites.Add([pscustomobject]@{path=Join-Path $Root $rel;rows=$values.Count;sha256=Hash (Join-Path $Root $rel)});foreach($v in $values){Check ($v.status -ceq 'PASS') 'Unresolved final test failure';$v['suite_path']=$rel;$rows.Add($v)}}
Check ($rows.Count -eq 190) 'Final expected test count changed'
Save (Join-Path $Evidence 'consolidated-results.json') @($rows)
$audit=[ordered]@{stage='03F';status='COMPLETE_WITH_LIMITATIONS';before_files=$before.Count;allowed_changed_files=5;preserved_files=$before.Count-5;snapshot=$snapshot;source_files_rechecked=619;dependency_metadata_pins_rechecked=48;requirement_metadata_rows=34;import_text_references=4407;external_configuration_pins_rechecked=$extraPins.Count;entry_python_hash_rechecked=$true;stage03e_directory_identities_rechecked=$directoryEvidence.Count;startup_policy_unchanged=$true;launcher_unchanged=$true;manifest_only_binding_changed=$true;consent='ABSENT';execution_enabled=$false;real_startup_enabled=$false;gpu_jobs_enabled=$false;g4='BLOCKED_NOT_AUTHORIZED';g5='NOT_AUTHORIZED';tests=190;executed_tests=185;recorded_rechecks=5;fail=0;suites=@($suites);operational_values_bound=$false;python_executed=$false;server_started=$false;network_calls=$false;gpu_executed=$false;snapshot_copy_repeated=$false;allowlist_expanded=$false;reservation_sha256=Hash (Join-Path $Root 'tests\stage03e\evidence\snapshot-reservation.json');next_gate='WAITING_HUMAN_REVIEW'}
Save (Join-Path $Evidence 'final-audit.json') $audit
$table=@('| Arquivo | SHA256 antes | SHA256 depois |','| --- | --- | --- |');foreach($c in $changed){$table+='| '+$c.path+' | '+$c.before_sha256+' | '+$c.after_sha256+' |'}
$report=@'
# WHAT LIES BTWN — STAGE03F_IMPLEMENTATION_RECEIPT

## A. STAGE03F_STATUS

COMPLETE_WITH_LIMITATIONS. Integração estática concluída; runtime NOT_VERIFIED.
Só cinco arquivos canônicos modificados. Testes/evidências novos no Stage03F.
Nenhum startup, Python, import, CUDA, GPU, cópia ou aprovação real.

Autorização do texto fornecido: AUTORIZO EXCLUSIVAMENTE STAGE 03F — INTEGRAÇÃO
DO ESTADO ESTÁTICO DO SNAPSHOT E ANÁLISE DE CONFIGURAÇÃO. O escopo não abre G4/G5.
Modelo/High solicitado registrado anteriormente; nenhuma ferramenta de preparação
altera ou autentica a configuração do modelo da sessão.

## B. VERIFIED_STAGE03E_BASELINE

619 arquivos, 9.533.695 bytes, 11 grupos; inventário efetivo SHA256
a7019b00d50a866729ebfc7806f91e7495bd69561783694bfff5198ffb35a8df.
Allowlist original SHA256 a8e69c205a7f98a1aa3bb34d399201a61e76c112c233f7202abc8b25ba2941eb.
Conferidos conteúdo/tamanho/paths/identidades/hardlink único das 619 origens e
619 destinos, 249 identidades de diretórios e 48 metadados fixados. Nenhum arquivo
ou diretório extra no snapshot. Zero drift antes das modificações. Os cinco
arquivos anteriores foram preservados em tests/stage03f/baseline, com hashes iguais.
2.908 arquivos preexistentes auditados; 2.903 preservados, exatamente cinco alterados.
Reserva persistente Stage03E preservada, sem recópia, limpeza ou substituição.

## C. EXACT_CHANGESET_WITH_BEFORE_AFTER_SHA256

__CHANGE_TABLE__

startup-identity representa existência física e conteúdo verificado, mantendo
runtime_started=false, compatibility NOT_VERIFIED e execution_authority=false.
Wlb.Startup aceita estado explícito, compara inventários/observações, verifica
bytes/identidades atuais e recusa alegações de compatibilidade no runtime-lock.
Start-WlbRuntime faz somente Plan/Admission estáticos com rehash; Admission
continua recusado. runtime-lock atualiza estado/pin efetivo e três hashes de
artefatos afetados. Manifesto: exclusivamente runtime_lock_sha256 mudou; DRAFT,
prompts, budgets, provenance e ausência de approval_id foram preservados.

## D. SNAPSHOT_STATE_INTEGRATION_EVIDENCE

STAGED_NOT_ACTIVATED: existe fisicamente, conferido contra allowlist; não
iniciado, não compatível por prova, sem consentimento G4 ou autoridade GPU.
Plan fornece esse estado separadamente de BLOCKED/NOT_VERIFIED/WAITING_HUMAN.
startup-policy byte-idêntico: real_startup_enabled=false, gpu_jobs_enabled=false,
consent_status=ABSENT. Executor execution_enabled=false, manifesto DRAFT,
launcher byte-idêntico com throw incondicional. Hashes não são autenticação
independente e identidades NTFS não são garantia eterna ou sandbox.

Evidências: baseline-summary.json, snapshot-checks-before.csv, plan.json de run3,
canonical-changes.json e final-audit.json em tests/stage03f/evidence. A verificação
final repetiu somente o rehash necessário após integração/testes, sem recópia.

## E. CONFIGURATION_AND_ALEMBIC_ASSESSMENT

Ver STAGE03F_CONFIGURATION_ASSESSMENT.md e dependency-run2/configuration-source-pins.json.
INI original: 3.314 bytes, SHA256 8e25f4b515644b0b7810344b4fec65025107ac8ea1da2d5195668bea28dae133.
Não copiado nem substituído. Inferência estática: ausência do INI não é falha
obrigatória demonstrada; Alembic tolera read de arquivo ausente e o código
fornece script_location/sqlalchemy.url programaticamente. Sem --enable-assets,
a maioria das falhas de init_db é registrada; casos de lock podem impedir
continuação. Banco em memória é opção existente, não adotada/autorizada.
Nenhuma conclusão de startup bem-sucedido decorre disso.

## F. DEPENDENCY_AND_IMPORT_GAP_MATRIX

Entry Python hash cobre só o executável do venv. pyvenv.cfg aponta interpretador
Python313 separado; stdlib/DLLs/bootstrap não autenticados. 34 requisitos têm
metadados presentes; 16 distribuições anteriores/48 arquivos rehashados. Há
4.407 referências textuais de import em 616 .py/.pyi; isso não é fechamento
completo nem resolução. Torch/torchaudio/torchvision/CUDA/native ABI, frontend,
DB/migrações/import side effects permanecem NOT_VERIFIED. Matriz e pins no
relatório de configuração; nenhuma instalação/correção de pacotes.

## G. NEGATIVE_AND_REGRESSION_TEST_RESULTS

190 PASS consolidados: 185 checks executados + 5 rechecks de evidência histórica.
54 Stage03F finais; 103 regressões D2/D1; 5 guardas de arquivos; 13 contratos
finais; 8 bindings completos; 2 concorrências novas e 5 rechecks adicionais.
Os harnesses D2 foram adaptados somente para namespaces próprios Stage03F;
labels legados de algumas linhas permanecem, mas nenhum arquivo histórico foi escrito.
103 regressões foram executadas antes da adição final do guarda runtime-lock;
54 checks Stage03F e 13 contratos finais verificaram a fonte final após essa adição.
Funções de tipos/recursos/propriedade dessas regressões não foram modificadas.

Casos: snapshot ausente/declarado não verificado; inventário incompleto/extra;
hash/size/path/ID/hardlink divergentes; estado desconhecido; compatibilidade sem
evidência; G4 sem consentimento; staged não autoriza; código de startup alterado
após pin; manifesto/lock divergentes; jobs habilitados e promoção DRAFT recusados.
Fixtures reais exercitam CreateNew/no-overwrite, substituição/tamper, reservas e
mutex. Mocks de recursos/propriedade não constituem evidência de runtime.

Tentativas preservadas: rodada inicial Stage03F 46 PASS/1 FAIL por expectativa
de mensagem; GUID omitido no launcher antigo causa erro de null antes da mensagem
esperada, sem submissão. GUID vazio recebe a recusa explícita. Rodada intermediária
48 PASS e final 54 PASS em namespaces distintos. Launcher não foi alterado.
Harness de bindings inicialmente abortou por enumeração mutável; leitor textual
de imports abortou ao tratar linha única como coleção. Scripts/tentativas iniciais
foram preservados, corrigidos apenas nos testes e repetidos em diretórios novos.
Esses abortos não são PASS nem runtime failures. Nenhum FAIL final foi omitido.

## H. TRUST_AND_AUTHORITY_REPORT

SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0 preservado. Nenhuma nova escolha solicitada.
Identidade textual não autentica operador independente; mesma conta pode alterar
código/policy, hashes não tornam isso sandbox. Sem mudança ACL/firewall/serviços.
Offline/loopback não são egress enforcement; imports de custom/native nodes
são fronteiras de execução. G2/G3/G4/G5/ALPHA continuam fechados.

## I. HUMAN_PARAMETERS_REMAINING

operator_identity, cpu_budget, polling_cadence_ms, telemetry_freshness_ms continuam
UNKNOWN/null. Nenhum valor de teste foi promovido. Budgets 8/10/4/4/2 GiB,
120 s/30 s e 256 MiB intactos; não são caps garantidos ou medidas observadas.

## J. MINIMUM_ADDITIONAL_FILES_PROPOSAL

Recomendação: zero novos arquivos no snapshot. A configuração Alembic não foi
provada obrigatória nesse caminho. Frontend está no venv, com metadata/index
observados; árvore completa de assets/licença não autenticada. Se inclusão futura
do INI for escolhida, exigir autorização distinta de allowlist/cópia, revisão de
opções/licença e testes isolados; path/hash/risco/destino estão no assessment.

Limitação legada: manifest.provenance.source_snapshot=NOT_CREATED é histórico G1
e está fixado pelo schema, fora do changeset. Estado atual consta de identity/lock;
não alterei schema/policy/spec para acomodar a integração. Eventual modernização
desses rótulos requer outro escopo, sem que isso conceda G4/G5.

## K. G4_READINESS_AND_BLOCKERS

BLOCKED / NOT_AUTHORIZED. Conteúdo e integração estática prontos; faltam identidade
efetiva Python/stdlib/DLLs/dependências/assets/compatibilidade, consentimento humano
G4, quatro parâmetros operacionais, observadores reais PID/time/image/porta/GPU,
telemetria/attribution/freshness, watchdog, start/stop exclusivo e protocolo de
tentativa única/recovery. Nenhum serviço operacional implementado nesta entrega.

## L. G5_STATUS = NOT_AUTHORIZED

G4 não ocorreu; job launcher bloqueado, sem approval real/consumo/POST/GPU/output.
Faltam autenticação/aprovação atômica/replay, engine/submissão/cancelamento, prazo
operacional e QC independente. Alpha Gen/MCP não avançaram.

## M. NO_OUT_OF_SCOPE_MUTATION_ATTESTATION

Somente cinco canônicos autorizados e novos testes/fixtures/evidências Stage03F.
619 fontes, 619 snapshot files, metadados/configs inspecionados, entry Python,
reserva Stage03E e todos os outros 2.903 arquivos anteriores rechecados intactos.
Snapshot não recebeu arquivo novo. Nenhum Python/import/CUDA, ComfyUI/server,
GPU/mídia, aquisição/instalação/modelo, rede/REST/commit, real approval, ACL/firewall,
serviço/global environment, MIRAE/PULSE/LTX ou encerramento real de processo.
PowerShell/.NET/Add-Type só para testes estáticos e mecânicas Windows locais.
A atestação cobre comandos/arquivos observados, não toda atividade independente
do Windows ou proteção futura após liberação dos handles.

## N. NEXT_GATE = WAITING_HUMAN_REVIEW

STOP_AFTER_DELIVERY. Sem avanço automático para startup/G4/G5/Alpha/MCP.
'@
WriteNew (Join-Path $Root 'STAGE03F_IMPLEMENTATION_RECEIPT.md') $report.Replace('__CHANGE_TABLE__',($table -join "`n"))
$newPaths=@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Where-Object {-not $known.ContainsKey($_.FullName.Substring($Root.Length+1))} | Sort-Object FullName | ForEach-Object {[pscustomobject]@{path=$_.FullName;bytes=$_.Length;sha256=Hash $_.FullName}})
WriteNew (Join-Path $Evidence 'new-files-inventory.csv') (($newPaths | ConvertTo-Csv -NoTypeInformation) -join "`r`n")
$delivery=[ordered]@{receipt_path=Join-Path $Root 'STAGE03F_IMPLEMENTATION_RECEIPT.md';receipt_sha256=Hash (Join-Path $Root 'STAGE03F_IMPLEMENTATION_RECEIPT.md');configuration_sha256=Hash (Join-Path $Root 'STAGE03F_CONFIGURATION_ASSESSMENT.md');inventory_sha256=Hash (Join-Path $Evidence 'new-files-inventory.csv');inventory_rows=$newPaths.Count;self_metadata_excluded=@('tests\stage03f\evidence\new-files-inventory.csv','tests\stage03f\evidence\delivery-integrity.json');self_hash_in_final_conversation=$true;canonical_changes=@($changed);next_gate='WAITING_HUMAN_REVIEW'}
Save (Join-Path $Evidence 'delivery-integrity.json') $delivery
$audit | Select-Object status,before_files,allowed_changed_files,preserved_files,tests,executed_tests,recorded_rechecks,fail,g4,g5,next_gate | ConvertTo-Json
$delivery | ConvertTo-Json -Depth 8
