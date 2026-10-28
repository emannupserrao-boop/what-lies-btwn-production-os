# WHAT LIES BTWN — STAGE03I_IMPLEMENTATION_RECEIPT

Data:2026-10-14, Europe/Bucharest; receipts nas evidências conservam UTC.
Modelo GPT-6.1 Sol/High solicitado; ferramentas não autenticam configuração ativa.

## A. STAGE03I_STATUS

COMPLETE_WITH_LIMITATIONS. Infraestrutura independente preparada e testada,
sem autoridade operacional. G4=BLOCKED_NOT_AUTHORIZED; G5=NOT_AUTHORIZED;
Alpha/MCP=CLOSED. Dois módulos novos; três arquivos existentes modificados só
para validator/pins/binding.198 PASS/0 FAIL final. Nenhum startup/GPU/stop real.

## B. VERIFIED_STAGE03H_BASELINE

Stage03H COMPLETE_WITH_LIMITATIONS;103 PASS/0 FAIL históricos reconciliados.
Conferidos todos os3.281 arquivos anteriores:3.279 presentes nos inventários H
mais dois metadados próprios. delivery-integrity H SHA256
ed890ede2f462a9614ac8b95de25d78fa513f1083f226f56bf3b66035b81ca4d;
17 prepared_artifacts anteriores e hashes de entrega H conferidos, zero drift.
RAM H~10,60 GiB era medição histórica; I observou9,808–9,817 GiB, acima8;
headroom mínimo28,783 GiB, acima10. Não houve recuperação/encerramento de apps.
Snapshot619/9.533.695 bytes STAGED_NOT_ACTIVATED preservado e revalidado.
RTX PID residency NOT_VERIFIED; NV global observável; proxy PROPOSED_ONLY;
quatro valores UNKNOWN/null e consent ABSENT.
Detalhes: [baseline-verification](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03i/evidence/baseline-verification.json).

## C. DOCUMENT_RECONCILIATION_AND_SCOPE

Lidos integralmente os13 documentos exigidos antes das alterações. Propostas H
separam PREP-ONLY de HELPER-LIFECYCLE,PARAMS/PROXY,RUNTIME-IDENTITY,G4 eG5;
esses gates futuros não são exigências de execução nesta etapa. Aplicado o recorte
I explícito: preparação/interfaces/fixtures/passivo, sem policy binding, lifecycle
real ou startup. Não houve conflito que exigisse executar fora do escopo.

Worker em runspace dedicado no mesmo processo substitui, para esta preparação,
a opção futura de processo isolado descrita em H. Independência lógica foi
demonstrada, não isolamento de processo/IPC cross-process/crash containment.
Cancelamento/terminação sugeridos em H permanecem gate separado. Valores500/1000/
2000 usados só em candidatos de teste, sem alteração de parâmetros humanos.
Nenhuma permissão adicional foi inferida de documento ou fixture.

## D. EXACT_CHANGESET_AND_HASHES

| Arquivo | Antes SHA256 | Depois SHA256 |
| --- | --- | --- |
| core\Test-WlbManifest.ps1 | ec559370f75d541f66455187f4cae75b02297f3305da90df8e0707390076949f | 0de93354a3dc822430708971517f25926e355c73987458197018a82041023c25 |
| policy\runtime-lock.json | 78436e1a7164d6c33475a5e4eb7c796492a30e602caa418ba0791cd9170e954a | adc2c85cb4e05471d4ab239cd001e4502f86acaa2235dd73ad85863c37dcaa5e |
| manifests\draft\POC0-CALIBRATION-001.json | a7cb7f393e9b2d618080e7118cc45348d48d911a7ef407f841649083f4f076ac | a069b61dc4585087121ababe9eb680b33b9ecd99de6cc549badffaebb2106ece |
| core\Wlb.Supervisor.ps1 | NOVO | ac03bcf4ac1fcf0e62712ee477b2895e54150c9652a1299cdf998de4d9684626 |
| core\Wlb.TelemetryWorker.ps1 | NOVO | de94b7bf408f8937f2f472b9e6cc38da688870f259afe5fe49b12aa95addc055 |

Validator: exact allowlist17->19 adiciona só os módulos, sem relaxar validação.
Lock: acrescenta dois pins e atualiza pin do validator; restantes campos iguais.
Manifesto: somente64 caracteres do lock binding substituídos, DRAFT intacto.
Sem alterações RuntimeMonitor/Startup/Start-WlbRuntime/StartupPolicy/Identity/
executor/G5/source snapshot. Backups dos três existentes antes de editar.
Changesets intermediários preservados; valores finais em
[canonical-changes-delivery](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03i/evidence/canonical-changes-delivery.json).
Inventário SHA256 de todos os arquivos novos/alterados acompanha a entrega.

## E. SUPERVISOR_IMPLEMENTATION

[Wlb.Supervisor.ps1](D:/WHAT-LIES-BTWN-PRODUCTION-OS/core/Wlb.Supervisor.ps1)
implementa classes sealed Envelope/Heartbeat/Mailbox/Supervisor/Decision e bridge
de recursos puro. Tick usa QPC monotônico e deadline absoluto120000 ms; não chama
sampler nem espera worker. Valida fingerprint/clock/mode/sequence/timestamps,
freshness, heartbeat/failure, queue fault e deadline; BLOCKED terminal latched.
Take usa TryEnter sem espera; contention de mailbox também bloqueia.
State externo sempre BLOCKED_NOT_AUTHORIZED, AuthorizedToExecute=false.

Get-WlbPreparedSupervisorDecision parseia payload limitado, preserva strings ISO
de identidade mesmo em versões novas do PowerShell, rejeita duplicate/case keys,
acopla clock/aquisição/conclusão ao envelope e chama evaluator puro G.
Não há callback de sampler, runtime start/stop/HTTP/consent em supervisor.
Tick depende do caller/scheduler; hard latency/host isolation não demonstrados.

## F. TELEMETRY_WORKER_IMPLEMENTATION

[Wlb.TelemetryWorker.ps1](D:/WHAT-LIES-BTWN-PRODUCTION-OS/core/Wlb.TelemetryWorker.ps1)
prepara state/tick/heartbeat passivos para execução desacoplada pelo caller.
Reusa fontes oficiais StageG sem editar: PSAPI RAM/commit,.NET PID/private/CPU,
TCP nativoIPv4/IPv6,NVIDIA global/process queries,WDDM,concorrentes e disco.
Fast500 e slow1000 candidatos; slow cache conserva sequência/acquisition.
Fingerprint do worker rechecado; identidade não concede ownership de lifecycle.
Qualquer falha de provider/publish marca worker failed; chamada subsequente
recusada, sem retry automático. Nenhum mecanismo de stop/cancelamento real.

Harnesses criam runspaces benignos próprios, não subprocessos de teste;12 ao
todo nas três rodadas assíncronas, com conclusão natural. Queries NVIDIA existentes
continuam utilities transitórias passivas, não runtime/generation adapters.
O worker não é iniciado automaticamente ao importar módulo ou via entry G4/G5.
Actor hash observado é lista parcial PID/name, não identidade completa/exclusividade;
provider generation UNKNOWN e RTX residency continuam NOT_VERIFIED.

## G. MAILBOX_AND_FRESHNESS_CONTRACT

Mailbox capacity1, fault latched quando cheia/busy/replay; heartbeat tem slot
fixo separado. Envelope JSON snapshot profundo/get-only,payload<=64 KiBUTF-8;
worker fingerprint64hex,clock<=128chars. Aquisição fast/slow/request/conclusão
separadas; cache mantém slow timestamp/sequence originais. ObservedReceivedMs
registra receipt inclusive recusado; SupervisorReceivedMs só metadata aceita.
Heartbeat não renova aquisição; receipt age não comprova provider age.
Freshness candidato2000 conta desde min(fast,slow), não chegada.

PASSIVE_PREPARATION_ONLY força generation verification=false, mesmo se caller
passar true. SIMULATED_TEST_ONLY permite VERIFIED fictício para testar paths
sem autoridade. Timestamp/provider clock de GPU não foi inventado. Bridge
cross-process não existe; todos os testes compartilhados usam QPC no mesmo
processo. Limites de transport não são hard caps de heap/provider/disco.
[Contrato e arquitetura](D:/WHAT-LIES-BTWN-PRODUCTION-OS/STAGE03I_SUPERVISION_DECISION_PACKAGE.md).

## H. FAILURE_AND_DEADLINE_TESTS

64 testes finais tipados/fixtures: lento/ausente,heartbeat perdido/failed,
generation UNKNOWN, stale/exato2000,duplicado/out-of-order/gap,clock/futuro,
mailbox cheia,cache timestamp rewrite,deadline exato120s,PID e ownership simulados
perdidos,GPU unavailable,concorrência unknown,JSON/types/64KiB/immutability,
timestamps payload-envelope e no retry. Nenhum caso autoriza startup.

Oito checks assíncronos finais: delay simulado300 e2800 ms com relógio real,
saída natural, block antes da conclusão,passive source UNKNOWN bloqueado,
4 envelopes/cache conservado e1 recheck desse envelope real armazenado.
Delay2800: block em2004 ms; worker ainda em execução, termina naturalmente;
Tick máximo0,2601 ms nesse caso. Query realmente hung e watchdog ComfyUI não
testados.120s é deadline injetado, não120s de execução real.

Primeira suite:52 PASS/7 FAIL (parser convertia creation string em DateTime,
fixture defaults/regex); fontes/resultados preservados e corrigidos. Primeira
rodada async:5 PASS/2 FAIL por harness exigir sucesso de coleta diante de provider
lento indisponível; worker saiu naturalmente sem retry e supervisor bloqueou.
Expectativa corrigida para aceitar/registrar falha segura, sem afirmar coleta
bem-sucedida quando faltam dados. Rodadas finais coletaram dados com source age
UNKNOWN e bloquearam. Consolidador abortou antes de gravar por array NoEnumerate
e labels repetidos; reporter corrigido e suite final run5 tem IDs únicos.
Nada foi contado como PASS real de watchdog nem omitido do histórico.

## I. GLOBAL_GPU_PROXY_PREPARATION_STATUS

SUPERVISED_G4_GLOBAL_GPU_PROXY_PROPOSED / PREPARATION_ONLY.
Interface Test-WlbPreparedGpuProxy valida scopeG4 sem modelos,RTX name/UUID/driver/
index/total estáveis,baseline anchor imediato,delta global<=2 GiB,reversão,
unknown/changed actors,missing/inconsistent/type/age/deadline. G5/Alpha/models
recusados. threshold_state positivo é só PREPARATION_THRESHOLDS_ONLY;
state BLOCKED_NOT_AUTHORIZED,enabled_in_policy=false,no PID attribution/retry.
Não é controle operacional aprovado. Nenhuma exceção foi adicionada ao evaluator
G estrito nem à policy. Dados passivos UNKNOWN permanecem bloqueados.

## J. PERFORMANCE_AND_OVERHEAD

Rodada final, medidas reais finitas: full cold914 ms (fast163); warm4 ticks
234/26/253/22 ms,mean133,75. Fast21/24/23/22 ms; slow refreshes2. Payloads
23.222–23.223 bytes,acquisition-age no receipt máximo567 ms. Neutral poll máximo
3,8514 ms. Esse consumer de timing não relaxa supervisor UNKNOWN.
CPU parent+worker1484,375 ms em1626 ms (~91,3% de um core), exclui helpers
NVIDIA/CIM. Inclui harness/serialization/poll; não comparável diretamente à CPU
de um collector isolado H nem ao host inteiro. CPU continua material.
H split mean132,2 é referência histórica de12 ticks; I n4 não prova melhoria,
p95/tail bound,accuracy ou worst case. Cold/provider failure anteriores mostram
limitações. Nenhum tempo máximo garantido ou cadence operacional vinculada.
[Performance summary](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03i/evidence/performance-summary.json).

## K. REGRESSION_RESULTS

198 PASS /0 FAIL final:64 I contratos,8 async,103 D1/D2,14 F,9 final snapshot/
bindings/gates/H compatibility.197 checks frescos +1 recheck de medição I;
103 H/198 G históricos não somados. Rodadas intermediárias não inflaram total.
D1/D2 em namespace I incluem validadores/recursos/owned mock/file/mutex reais
inofensivos, sem aprovação ou namespace operacional. F verifica estados/compat/
identity sem falsa ativação. G via integration bridge puro e queries reais;
H decision model exact/over/unknown executado em fixtures novas. Final rehash
619 e19 pins,policy four UNKNOWN,DRAFT,G4/G5 recusados,AST e entry não integrado.
As regressões D1/D2/F ocorreram antes das últimas asserções novas de payload/
receipt no módulo I; esses paths I foram testados depois em suites finais64/8
e bindings/619/gates finais9. Fontes legadas G/F/D permaneceram intactas.
[Matriz](D:/WHAT-LIES-BTWN-PRODUCTION-OS/STAGE03I_TEST_MATRIX.md),
[resultados completos](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03i/evidence/consolidated-results.json).

## L. HUMAN_DECISIONS_PENDING

Operator identity/SID confirmados humanamente,CPU budget,fast/slow cadence,
telemetry freshness e aceitação explícita de GPU global/provider proxy pendentes.
Candidatos:CPU OBSERVE_ONLY,fast500,slow1000,acquisition/receipt2000 ms.
Quatro campos continuam UNKNOWN/null. Conta proposta H WORKSTATION\user /
SID S-1-5-21-REDACTED não é consentimento.
SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0 preservado; não se solicita novo boundary.

## M. MINIMUM_NEXT_G4_CHANGESET

Revisão deste pacote primeiro. Depois, em escopos separados: validar boundary
worker/IPC se necessário e clocks/cleanup; resolver provider age ou contrato
explícito do proxy; vincular valores humanos e adaptar validators/policy/pins;
resolver effective Python/stdlib/DLL/native/frontend/DB/assets/import F;
implementar trusted single-attempt consent e own lifecycle/port/watchdog.
Qualquer Python/start/stop helper/Comfy exige autorização própria futura.
Novo supervisor não é ligado a runtime nesta entrega. Gate BLOCKED não comprova
processo parado. G5 necessita contrato/consent/engine/submission/QC separados.
[Gates, permissões, aceitação e rollback](D:/WHAT-LIES-BTWN-PRODUCTION-OS/STAGE03I_SUPERVISION_DECISION_PACKAGE.md).

## N. REMAINING_G4_AND_G5_BLOCKERS

G4:consent/bindings ausentes,provider generation/RTX PID residency/actors/coverage
não verificados,proxy não aceito/ativado,runtime compatibility F pendente,
owned start/stop/port e operational supervision não implementados/testados.
Same-process independência lógica não comprova native-hang cleanup/host failure
isolation; nenhuma parada real preparada nesta etapa. RAM passou só nas amostras
atuais e deve ser reavaliada imediatamente antes de uma tentativa futura.
G5:sem G4,job consent atomic/replay,engine/REST/cancelamento/30s/output/QC.
Launcher com throw incondicional intacto; Alpha/MCP fechados.

## O. NO_OUT_OF_SCOPE_MUTATION_ATTESTATION

Exatamente três arquivos preexistentes alterados,3.278 preservados; snapshot619
e reserva E intactos; StageH/G/F e ambientes existentes preservados. Dois módulos
novos e tests/evidence StageI;três MDs raiz. Inventário/final-audit documentam
paths absolutos/SHA256. Real_startup/gpu_jobs/execution=false,consent ABSENT,
manifest DRAFT; quatro UNKNOWN/null; nenhum registro de aprovação real.

Sem Python/Comfy/LTX/runtime/model/CUDA/inference/job,listener/REST,stop/suspend
de processo existente,downloads/installs/ambientes,ACL/firewall/registro/services/
global config,commit/merge/push,MIRAE/PULSE/original snapshot/model changes.
Runspaces próprios encerraram naturalmente; nenhuma query/prod process foi
cancelada/morta. Mock consent/owned stop de regressões é fixture, nunca aprovação
humana. Fonte G NVIDIA mantém utilities read-only transitórias autorizadas.
Atestação cobre comandos observados e hashes Production OS; não toda atividade
independente Windows/apps nem garantia de sandbox/auth independente da mesma conta.

## P. NEXT_GATE = WAITING_HUMAN_REVIEW

STOP_AFTER_DELIVERY. Sem autoridade antecipada, ativação de proxy ou avanço G4/G5.
