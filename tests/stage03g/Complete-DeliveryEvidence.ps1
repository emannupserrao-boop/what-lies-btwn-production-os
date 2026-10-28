#requires -Version 7.6
# New Stage03G evidence plus readonly audit; does not invoke collectors again.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\WHAT-LIES-BTWN-PRODUCTION-OS';$Stage=Join-Path $Root 'tests\stage03g';$Evidence=Join-Path $Stage 'evidence'
function Check([bool]$v,[string]$why){if(-not $v){throw "BLOCKED: $why"}}
function Hash([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
function Json([string]$p){return ,(Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -AsHashtable -NoEnumerate -DateKind String)}
function WriteNew([string]$p,[string]$text){Check ($p.StartsWith($Stage+'\',[StringComparison]::OrdinalIgnoreCase) -or $p -ceq (Join-Path $Root 'STAGE03G_IMPLEMENTATION_RECEIPT.md')) 'Outside delivery scope';$s=[IO.File]::Open($p,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write([Text.UTF8Encoding]::new($false).GetBytes($text));$s.Flush($true)}finally{$s.Dispose()}}
function Save([string]$p,$v){WriteNew $p (ConvertTo-Json -InputObject $v -Depth 70)}
$before=Json (Join-Path $Evidence 'all-existing-before.json')
$allowed=@('core\Wlb.RuntimeMonitor.ps1','policy\runtime-lock.json','manifests\draft\POC0-CALIBRATION-001.json')
$changes=[Collections.Generic.List[object]]::new();$known=@{}
foreach($b in $before){$known[$b.path]=$true;Check (Test-Path -LiteralPath $b.path) 'Prior file missing';$hash=Hash $b.path;if($hash -cne $b.sha256 -or (Get-Item -LiteralPath $b.path).Length -ne $b.bytes){Check ($b.relative_path -cin $allowed) ('Out-of-scope drift: '+$b.path);$changes.Add([ordered]@{path=$b.path;relative_path=$b.relative_path;before_sha256=$b.sha256;after_sha256=$hash})}}
Check ($changes.Count -eq 3) 'Three legitimate existing changes expected'
foreach($f in Get-ChildItem -LiteralPath $Root -Force -Recurse -File){Check ($known.ContainsKey($f.FullName) -or $f.FullName.StartsWith($Stage+'\',[StringComparison]::OrdinalIgnoreCase) -or $f.FullName -ceq (Join-Path $Root 'STAGE03G_G4_TELEMETRY_DECISION_PACKAGE.md')) ('Unexpected new file: '+$f.FullName)}
$oldLock=Json (Join-Path $Stage 'baseline\policy\runtime-lock.json');$lock=Json (Join-Path $Root 'policy\runtime-lock.json')
$comparison=Json (Join-Path $Root 'policy\runtime-lock.json');$comparison.prepared_artifacts['core\Wlb.RuntimeMonitor.ps1']=$oldLock.prepared_artifacts['core\Wlb.RuntimeMonitor.ps1']
Check ((ConvertTo-Json -InputObject $comparison -Depth 70 -Compress) -ceq (ConvertTo-Json -InputObject $oldLock -Depth 70 -Compress)) 'Runtime lock changed beyond one artifact binding'
$mPath=Join-Path $Root 'manifests\draft\POC0-CALIBRATION-001.json';$oldM=Join-Path $Stage 'baseline\manifests\draft\POC0-CALIBRATION-001.json';$m=Json $mPath;$old=Json $oldM
Check ([IO.File]::ReadAllText($mPath).Replace($m.binding.runtime_lock_sha256,$old.binding.runtime_lock_sha256) -ceq [IO.File]::ReadAllText($oldM)) 'Manifest changed beyond binding'
foreach($key in $lock.prepared_artifacts.Keys){Check ((Hash (Join-Path $Root $key)) -ceq $lock.prepared_artifacts[$key]) 'Artifact hash binding drift'}
Check ($m.state -ceq 'DRAFT' -and -not $m.approval_contract.record_created) 'Draft/approval changed'
$policy=Json (Join-Path $Root 'policy\startup-policy.json');$executor=Json (Join-Path $Root 'policy\executor-policy.json');$identity=Json (Join-Path $Root 'policy\startup-identity.json')
Check (-not $policy.real_startup_enabled -and -not $policy.gpu_jobs_enabled -and -not $executor.execution_enabled -and $policy.consent_status -ceq 'ABSENT') 'Execution gate drift'
foreach($p in $policy.human_parameters.Values){Check ($p.status -ceq 'UNKNOWN' -and $null -eq $p.value) 'Operational value bound'}
Check ($policy.boundary_mode -ceq 'SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0' -and $identity.snapshot.status -ceq 'STAGED_NOT_ACTIVATED') 'Boundary/snapshot state drift'
foreach($p in @('approvals','jobs','workflows\approved')){Check (-not(Test-Path -LiteralPath (Join-Path $Root $p))) 'Real approval/job/promotion namespace created'}
Check ((Hash (Join-Path $Root 'tests\stage03e\evidence\snapshot-reservation.json')) -ceq '90c3a8e185a7695f6412c399164d27ca02bd99e8fd99b6c1a8f198f3d6078514') 'Persistent snapshot reservation drift'
Check ((Hash (Join-Path $Root 'tests\stage03e\evidence\actual-snapshot-inventory.csv')) -ceq 'a7019b00d50a866729ebfc7806f91e7495bd69561783694bfff5198ffb35a8df') 'Snapshot inventory drift'
$native=Json (Join-Path $Evidence 'native\sampling-summary.json');$initial=Json (Join-Path $Evidence 'sampling-summary.json')
Check ($native.collector_source_sha256 -ceq (Hash (Join-Path $Root 'core\Wlb.RuntimeMonitor.ps1'))) 'Native benchmark not bound to final source'
Check ($native.total_samples -eq 24 -and $initial.total_samples -eq 24) 'Unexpected sampling scope'
$suites=@('tests\stage03g\evidence\passive-contract-results.json','tests\stage03g\regression\evidence\run2\test-results.json','tests\stage03g\evidence\final-contract-results.json','tests\stage03g\evidence\f-regression-results.json')
$rows=[Collections.Generic.List[object]]::new();$suiteSummary=@()
foreach($path in $suites){$r=Json (Join-Path $Root $path);foreach($row in $r){Check ($row.status -ceq 'PASS') 'Unresolved test failure';$row['suite_path']=$path;$rows.Add($row)};$suiteSummary+=@([ordered]@{path=Join-Path $Root $path;rows=$r.Count;sha256=Hash (Join-Path $Root $path)})}
Check ($rows.Count -eq 198) 'Test count changed'
Save (Join-Path $Evidence 'consolidated-results.json') @($rows)
Save (Join-Path $Evidence 'canonical-changes.json') @($changes)
$cold=Json (Join-Path $Evidence 'native\cold-sample.json');$live=Json (Join-Path $Evidence 'native\live-preflight.json');$session=Json (Join-Path $Evidence 'native\observed-session.json')
Check ($live.state -ceq 'BLOCKED' -and -not $live.authorized_to_execute) 'Live measurement granted authority'
$audit=[ordered]@{stage='03G';status='COMPLETE_WITH_LIMITATIONS';g4_feasibility='BLOCKED';prior_files=$before.Count;changed_existing=3;preserved_prior=$before.Count-3;snapshot_files_unchanged=619;allowlist_expanded=$false;snapshot_copy_repeated=$false;policy_unchanged=$true;startup_entry_unchanged=$true;g5_launcher_unchanged=$true;four_human_parameters='UNKNOWN_NULL';boundary_mode=$policy.boundary_mode;test_rows=198;stored_measurement_rechecks=1;tests_fresh_checks=197;failed=0;suites=$suiteSummary;sampling_scheduled=48;cold_samples=2;source_native_sha256=$native.collector_source_sha256;global_vram_available=$true;nvidia_process_vram_available=(@($cold.gpu.nv_processes | Where-Object {$null -ne $_.vram_bytes}).Count -gt 0);windows_pid_luid_accounting_available=$true;rtx_pid_residency_mapping='NOT_VERIFIED';provider_generation_freshness='NOT_VERIFIED';real_runtime_started=$false;real_target_process_killed=$false;active_connection_or_listener=$false;python_imports_or_cuda=$false;real_consent_created_or_consumed=$false;gpu_job_or_media=$false;installations_or_host_settings=$false;readonly_nvidia_cli_queries=$true;g4='BLOCKED_NOT_AUTHORIZED';g5='NOT_AUTHORIZED';next_gate='WAITING_HUMAN_REVIEW'}
Save (Join-Path $Evidence 'final-audit.json') $audit
$table=@('| Arquivo | SHA256 antes | SHA256 depois |','| --- | --- | --- |');foreach($c in $changes){$table+='| '+$c.path+' | '+$c.before_sha256+' | '+$c.after_sha256+' |'}
$report=@'
# WHAT LIES BTWN — STAGE03G_IMPLEMENTATION_RECEIPT

## A. STAGE03G_STATUS

COMPLETE_WITH_LIMITATIONS. G4_TELEMETRY_FEASIBILITY=BLOCKED em modo estrito;
coleta passiva real validada localmente. G2/G3/G4/G5/ALPHA fechados.
Autorização recebida no texto do usuário permite implementação/telemetria local
delimitada/fixtures, não runtime, modelos, configuração host, consentimento ou jobs.
Stage03F reconciliado: 190 PASS anteriores lidos, final-audit e arquivos requeridos
inspecionados/rehashados; sem drift não explicado. Baseline 3.165 arquivos preservado
antes dos edits; três backups e proposed-changeset.json criados primeiro.

## B. EXACT_CHANGESET_AND_HASHES

__CHANGE_TABLE__

RuntimeMonitor: mantém byte/semântica das funções legadas de resource/mock watchdog;
acrescenta PSAPI RAM/commit, métricas/tuple de PID e CPU, NV global/process queries,
WDDM accounting, tabela TCP nativa IPv4/IPv6, concorrentes por nome, disco escopado,
QPC/timestamps, preflight estrito separado e solicitação de parada somente mock.
Runtime-lock: só hash desse artefato atualizado. Manifesto: só binding runtime-lock.
Schema/Bible/workflow/StartupPolicy/StartupIdentity/Startup entry/G5 executor intactos.
Novos paths limitados a tests/stage03g e dois relatórios de evidência na raiz.
Inventário absoluto de todos os arquivos novos: evidence/new-files-inventory.csv.

## C. REAL_TELEMETRY_CAPABILITIES

RAM/commit/headroom: GLOBAL Windows PSAPI, páginas 4.096 bytes observadas.
Private bytes e CPU cumulativa: atribuídos ao PID observado com creation UTC,
image path/on-disk SHA e rechecagem de identidade. CPU ratio é estimativa, sem cap;
private bytes não são working set. Disco mede comprimentos lógicos nos quatro
paths fixos; ausentes são registrados como ausentes, sem criá-los. Relógio QPC
monotônico e receipt UTC; leituras sequenciais não são uma transação global.
Observação não concede ownership de lançamento/parada ou identidade humana.

## D. VRAM_ATTRIBUTION_FINDINGS

RTX 5080 Laptop, NVIDIA 617.42, total reportado 16.303 MiB. NV global disponível;
31 PIDs no cold nativo, todos com used_gpu_memory=N/A. Windows oferece 67 linhas
PID/LUID e quatro adapters de contabilidade dedicada/shared/committed, sem mapa
validado RTX UUID/LUID ou prova de residência. Não confundir N/A com zero nem
contabilidade com VRAM individual autenticada. Quantum NV de 1 MiB não comprova
precisão física/peak. Diferença total-used-free=299 MiB fica não classificada.
Alternativa global supervisionada startup-only proposta separadamente no pacote
de decisão, sem exceção implementada, sem alterar 2 GiB e sem equivalência a PID.

## E. RESOURCE_SAMPLING_BENCHMARK

50 coletas reais: duas versões × (1 cold + 12 em 250 ms + 12 em 500 ms).
Inicial CIM: mean 1.154,3/1.144,5 ms; p95 1.295/1.217 ms; 12/12 overruns por
cadência; 1.000 ms excedido em todas as leituras warm. Bottleneck: porta/processos.
Depois de substituir somente essas fontes por APIs Windows/.NET passivas:
250 ms: 171–246 ms, mean 214,6, p95 246, start lateness max 14, 0/12 overruns.
500 ms: 199–247 ms, mean 227,3, p95 247, start lateness max 16, 0/12 overruns.
Cold nativo: 1.184 ms. Warm passa receipt-age 1.000/2.000 ms; geração dos providers
continua NOT_VERIFIED. p95 com n=12 é o máximo observado, não tail bound amplo.
Sampling-summary/samples-* originais preservados; versão nova em evidence/native.
Native benchmark source SHA coincide com o canônico final. Não foram retries de
falha: dois experimentos finitos de versões distintas, sem repetição de query falha.

## F. PROCESS_AND_PORT_OBSERVATION

PID/creation/image/hash/private/CPU verificados somente em observadores PowerShell,
nunca em Comfy iniciado por esta etapa. Porta 8189 sem listeners nas observações,
nativa e CIM concordantes; sem conexão/bind/listen. Casos ocupados IPv4/IPv6 foram
somente tabelas binárias sintéticas. Verificar tuple não autentica lifecycle;
real process ownership/stop/port observation para Comfy continua não testado.
Named mutex/CreateNew/held parent fixtures são testes próprios, não lock G4 ativo.

## G. CPU_AND_OPERATOR_IDENTITY_EVIDENCE

Conta WORKSTATION\user, SID S-1-5-21-REDACTED,
lidos do token Windows e registrados sem bind, autenticação independente ou consentimento.
CPU vem de TotalProcessorTime (user+kernel); representação 100 ns não é resolução
comprovada. Métricas excluem processos helper NVIDIA/provider CIM. Ratio de um core
no experimento nativo ~81,5%/76,1%; não é percentual do host nem cap operacional.
Proposta CPU OBSERVE_ONLY, sem teto numérico, somente para revisão humana.

## H. MOCK_AND_REGRESSION_RESULTS

198 PASS: 68 contratos/coletas/AST/fixtures passivos; 103 D1/D2 relevantes;
13 contratos finais; 14 F. Um dos 198 registros rechecka medição real já armazenada
nesta etapa; 197 são checks frescos, não 198 execuções do runtime. Todos final PASS.
Inclui ausente/unavailable, stale/idade, tipos, inconsistência, atribuição impossível,
concorrência, thresholds exatos/excedidos, contador reverso, clock/domain/deadline,
PID falso/reciclado, port occupied/unknown, CPU sem cap, mock owned stop/foreign deny,
watchdog injetado, hashes/paths/nós/DRAFT e recusa G4/G5. Sem target/start/kill/listener.
Regressões gravam só Stage03G; rótulos legados de algumas linhas não alteram scope.
Mock positivo retorna FEASIBILITY_THRESHOLDS_ONLY/authorized=false, nunca autoridade.

## I. LIMITATIONS_AND_UNAVAILABLE_METRICS

Não há NV VRAM por PID; WDDM mapping/residência/idade-generation não validados.
Exclusividade não comprovada: desktop/utility GPU actors compartilham a placa;
nome de processo não prova atividade de render e a lista não cobre todo ator kernel.
RAM warm ~6,42–6,67 GiB falha gate 8; headroom ~28,29–28,34 GiB passa gate 10.
Não generalizar a coleta curta a startup real, peaks ou 120 s. CLI/CIM/OS calls não
foram provados hard-time-bounded; nenhuma forcible kill de helper foi adicionada.
Process image hash não autentica loaded image/stdlib/DLLs. Filesystem size enumeration
não é snapshot atômico/physical allocation. Thresholds não são hard caps garantidos.

## J. HUMAN_PARAMETER_RECOMMENDATIONS

Propor, sem aplicar: confirmar conta/SID; CPU OBSERVE_ONLY; cadence 500 ms;
freshness 2.000 ms como receipt-age proxy sujeito a decisão explícita sobre generation
age. 250 ms teve margem estreita. Os quatro fields continuam UNKNOWN/null e os
budgets existentes permanecem 8/10/4/4/2 GiB, 120 s, 256 MiB e G5 30 s não real-testado.
SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0 preservado; não solicitar boundary novamente.

## K. REMAINING_G4_BLOCKERS

BLOCKED_NOT_AUTHORIZED: RAM gate falhou, RTX PID residency/idade-generation e
exclusividade não comprovadas, quatro valores humanos/consentimento ausentes,
nenhum launch/stop exclusivo/watchdog operacional testado. Python/stdlib/DLLs/native
packages/frontend/DB/import compatibility de F continua NOT_VERIFIED. A alternativa
GPU global startup-only exige nova decisão/contrato; não foi habilitada silenciosamente.

## L. REMAINING_G5_BLOCKERS

NOT_AUTHORIZED. Launcher byte-idêntico/incondicionalmente bloqueado. Sem G4, approval
real, consumo/replay, REST, engine GPU, deadline real 30 s, render/output ou QC.
Alpha Gen/MCP/modelos continuam fora da etapa.

## M. NO_OUT_OF_SCOPE_MUTATION_ATTESTATION

Três canônicos alterados; outros 3.162 arquivos anteriores e 619 snapshot files
intactos. Reserva Stage03E intacta, sem recópia/allowlist expandida. Escritas apenas
Production OS. Sem Python/import/CUDA/Comfy/LTX startup, processo alvo iniciado/morto,
listener/conexão ativa, modelos/GPU/mídia, installs/downloads, rede externa/commits,
ACL/firewall/registro/services/global environment ou alterações MIRAE/PULSE/produção.
PowerShell/.NET/helpers Windows em memória e invocações existentes read-only NVIDIA
foram usados conforme autorização passiva; essas utilities transitórias não são
startup/control adapters, e não foram ocultadas como custo zero ou isolamento OS.
A atestação cobre comandos/arquivos observados, não toda atividade do Windows/apps.

## N. NEXT_GATE = WAITING_HUMAN_REVIEW

STOP_AFTER_DELIVERY. Sem avanço automático para G4/G5/Alpha/MCP.
'@
WriteNew (Join-Path $Root 'STAGE03G_IMPLEMENTATION_RECEIPT.md') $report.Replace('__CHANGE_TABLE__',($table -join "`n"))
$new=@(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Where-Object {-not $known.ContainsKey($_.FullName)} | Sort-Object FullName | ForEach-Object {[ordered]@{path=$_.FullName;bytes=$_.Length;sha256=Hash $_.FullName}})
WriteNew (Join-Path $Evidence 'new-files-inventory.csv') (($new | ConvertTo-Csv -NoTypeInformation) -join "`r`n")
$delivery=[ordered]@{receipt_sha256=Hash (Join-Path $Root 'STAGE03G_IMPLEMENTATION_RECEIPT.md');decision_package_sha256=Hash (Join-Path $Root 'STAGE03G_G4_TELEMETRY_DECISION_PACKAGE.md');new_inventory_sha256=Hash (Join-Path $Evidence 'new-files-inventory.csv');new_inventory_rows=$new.Count;self_metadata_excluded=@('tests\stage03g\evidence\new-files-inventory.csv','tests\stage03g\evidence\delivery-integrity.json');self_hash_final_conversation=$true;canonical_changes=@($changes);final_audit_sha256=Hash (Join-Path $Evidence 'final-audit.json');next_gate='WAITING_HUMAN_REVIEW'}
Save (Join-Path $Evidence 'delivery-integrity.json') $delivery
$delivery | ConvertTo-Json -Depth 10
