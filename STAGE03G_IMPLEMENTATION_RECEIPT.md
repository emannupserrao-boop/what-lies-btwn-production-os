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

| Arquivo | SHA256 antes | SHA256 depois |
| --- | --- | --- |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\core\Wlb.RuntimeMonitor.ps1 | b2d68365699194ec2c0db37529d644006d167cc3918f659d0f3a9688b5aaeb1e | afc7586b479f647018316e11e39ebc29ec151361bdf7c53a746456b220fafc41 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\manifests\draft\POC0-CALIBRATION-001.json | 2a72ff8fc4ce23eafad3a62555e69624366d1e83af5d27c7e55dec74f249f287 | a7cb7f393e9b2d618080e7118cc45348d48d911a7ef407f841649083f4f076ac |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\policy\runtime-lock.json | bc00c6a14e1671dbd15c1caf4f7d59e4362affa798d951144a1daebe6296333a | 78436e1a7164d6c33475a5e4eb7c796492a30e602caa418ba0791cd9170e954a |

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