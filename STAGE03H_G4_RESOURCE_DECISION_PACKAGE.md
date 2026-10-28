# WHAT LIES BTWN — Stage03H G4 Resource Readiness & Supervised Telemetry Design

Data de entrega: 2026-10-14, Europe/Bucharest. Evidências conservam UTC original.
Root: D:\WHAT-LIES-BTWN-PRODUCTION-OS. Modelo GPT-6.1 Sol / High solicitado;
configuração ativa da sessão não autenticada pelas ferramentas de diagnóstico.

## A. STAGE03H_STATUS

COMPLETE_WITH_LIMITATIONS. Diagnóstico passivo, experimentos finitos e pacote de
decisão concluídos. G4=BLOCKED_NOT_AUTHORIZED; G5=BLOCKED_NOT_AUTHORIZED;
ALPHA=CLOSED. RAM passou nesta etapa; GPU PID residency, generation age,
supervisor/lifecycle operacional e consentimento continuam pendentes.
Nenhuma alteração canônica, inicialização de runtime, aprovação ou binding.

## B. BASELINE_VERIFICATION

Lidos os dez artefatos exigidos: recibo/pacote/resultados G, recibo F, três JSONs
de policy/identity/lock e RuntimeMonitor/Startup/Start-WlbRuntime. Stage03G
COMPLETE_WITH_LIMITATIONS, 198 PASS/0 FAIL reconciliados; não contados como novos
testes H. Verificados 26 hashes/vínculos críticos, incluindo os 17 prepared
artifacts, três mudanças G, recibo F, inventário/reserva E e manifesto->lock.
Também conferidos os 70 arquivos do inventário de entrega G. Zero drift.
F foi reconciliado como histórico: suas mudanças posteriores em G são explicadas
pelo recibo G; não se exige retornar a hashes F superseded.

| Arquivo canônico | SHA256 atual preservado |
| --- | --- |
| core\Wlb.RuntimeMonitor.ps1 | afc7586b479f647018316e11e39ebc29ec151361bdf7c53a746456b220fafc41 |
| core\Wlb.Startup.ps1 | 6847dc5439c22f0db5d00f6f5f647e31821847374b3787537fb0a0fa75840267 |
| core\Start-WlbRuntime.ps1 | 427be7379bc15750ece78b77911bf68515c37a28659c80d30531ac858893f25c |
| policy\startup-policy.json | e1db244a744f6ee228956d7fdd199c89737822299bab7785b58ba8c9e527795f |
| policy\startup-identity.json | 10e751ee38ed20b62f0887439f4d31fb492f053131d3ff64e7ca8a0160e22187 |
| policy\runtime-lock.json | 78436e1a7164d6c33475a5e4eb7c796492a30e602caa418ba0791cd9170e954a |
| manifests\draft\POC0-CALIBRATION-001.json | a7cb7f393e9b2d618080e7118cc45348d48d911a7ef407f841649083f4f076ac |

Baseline de integridade: 3.237 arquivos existentes, inclusive snapshot619,
registrados antes das novas escritas e conferidos ao final. Sem nova auditoria
geral de ambientes/projetos, recópia ou imports. Um leitor inicial usou o nome
errado `bindings` em vez de `binding`, abortou antes de gravar; o campo real foi
corrigido no leitor e o hash conferiu. Isso não foi drift nem mudança de manifesto.
Detalhes: [baseline-verification](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03h/evidence/baseline-verification.json).

## C. RAM_CONSUMPTION_DIAGNOSIS

Medições reais PSAPI: RAM física utilizável31,291 GiB; disponível10,648 antes e
10,625 depois do levantamento. Commit37,710 GiB, limit67,131 GiB,
headroom29,421 GiB. Experimento posterior: disponível10,296–10,890 GiB;
última rechecagem10,598 GiB. Gate>=8 GiB PASS_OBSERVED_NOT_AUTHORITY;
headroom>=10 GiB também passou. O StageG teve6,42–6,67 GiB; a causa da melhora
entre etapas não foi atribuída a uma ação deste agente.

Ranking real por working set; GiB binários, observações sequenciais:

| PID / nome | Working set GiB | Private bytes GiB | Interpretação |
| --- | ---: | ---: | --- |
| 26972 brave.exe | 1,563 | 1,900 | Maior processo de usuário por WS; aba/role não identificada |
| 4124 Memory Compression | 1,444 | 0,014 | Memória administrada pelo Windows; não encerrar |
| 25176 ChatGPT.exe | 1,006 | 1,456 | Imagem pertence ao pacote OpenAI.Codex |
| 2516 dwm.exe | 0,706 | 1,694 | Compositor do Windows; não encerrar |
| 4004 Discord.exe | 0,500 | 0,680 | Aplicação de usuário |
| 25400 codex.exe | 0,487 | 1,222 | Backend ativo do trabalho; preservar |
| 8172 MsMpEng.exe | 0,465 | 0,626 | Proteção do Windows; preservar |
| 25184 ChatGPT.exe | 0,422 | 0,613 | Mesmo pacote Codex, outro processo |
| 42848 brave.exe | 0,397 | 0,494 | Mesmo executável Brave |
| 37088 HP.Omen.OmenCommandCenter.exe | 0,394 | 0,513 | Função de controle do host não validada; preservar |

426 PIDs no snapshot CIM:250 com criação/imagem e métricas .NET correlacionadas;
176 parciais/inacessíveis. Identidades completas não são ownership de lançamento.
74 links de parent PID+mesma imagem+criação anterior foram observados; são
evidência de relacionamento naquele snapshot, não histórico autenticado de criação.
Agrupamento quantitativo é por caminho exato da imagem, não só nome nem todo
descendente. Nenhum candidato LTX/python/Comfy/blender/ffmpeg/opera apareceu no
filtro finito; isso não prova inexistência de trabalho oculto/outro nome.
Três node.exe observados não foram atribuídos a MIRAE/PULSE ou recomendados para close.

WS representa páginas físicas presentes, incluindo compartilhadas; private bytes
representam alocação privada comprometida, inclusive fora de RAM. Commit global
não é consumo físico e não deve ser obtido pela soma de private bytes/WS.
Cache, driver/shared GPU, compressão e kernel não foram decompostos por aplicação.
A consulta raw de private working set expirou em2 s; valor UNAVAILABLE, não zero.
O primeiro diagnóstico abortado foi preservado como falha de provider, sem retry
desse provider. A versão2 coleta WS/private bytes disponíveis. Normalização dos
grupos registra null: o zero da soma de uma coluna ausente no artefato inicial
não era medição. Não usar esse campo original para decisões.

Dados completos: [ram-diagnosis](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03h/evidence/ram-diagnosis.json),
[grupos normalizados](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03h/evidence/memory-groups-normalized.json).

## D. MEMORY_RECOVERY_OPTIONS_FOR_OPERATOR

Não há necessidade demonstrada de fechar aplicações para passar RAM agora.
Se a pressão voltar antes de um futuro G4, salvar trabalho e usar fechamento
normal pela UI; reabrir depois. Reavaliar RAM/commit passivamente após cada ação.

| Grupo comprovado por imagem | PIDs | Soma WS GiB | Soma private GiB | Opção manual e estimativa limitada |
| --- | ---: | ---: | ---: | --- |
| Brave | 14 | 2,771 | 4,209 | Salvar sessão; identificar abas pesadas no task manager do navegador; fechar abas/janelas dispensáveis |
| Frontend Codex (ChatGPT.exe) | 19 | 2,281 | 4,297 | Preservar este trabalho; revisar só depois da entrega, evitando interromper tarefas ativas |
| Discord | 6 | 0,691 | 1,293 | Fechar normalmente se comunicação/call não estiver em uso |
| Backend codex.exe | 2 | 0,493 | 1,231 | Preservar sessão/tarefas; não recomendar encerramento durante a execução |
| Obsidian | 4 | 0,424 | 0,657 | Salvar notas e fechar se dispensável |
| Steam webhelpers | 7 | 0,360 | 1,415 | Fechar Steam pela UI se sem jogo/download; soma cobre helpers, não todo Steam |

Estimativa fundamentada do componente residente observado: benefício direto
dessas páginas pode ficar entre0 e a soma WS do grupo, descontado compartilhamento;
isso é envelope contábil desse componente, não previsão da variação global de RAM.
Compressed/cache e processos não agrupados podem alterar o ganho total; nenhuma
medição de before/after close foi autorizada/executada. Não somar envelopes e
prometer recuperação. Priorização: Brave/Discord/Obsidian opcionais; o WS grande
do Codex é informação para planejamento posterior, não ação nesta sessão.

Nenhum PID deve ser encerrado automaticamente. Preservar Memory Compression,
System/Idle, dwm, MsMpEng, svchost, serviços/drivers, explorer e utilitários de
controle do host; MIRAE/PULSE/LTX, Comfy/Python preexistentes e node não atribuídos;
Codex/observadores ativos. Sem limpeza de cache/pagefile, EmptyWorkingSet, trim,
Process.Kill, suspensão ou mudança de serviço.

## E. SAMPLING_OVERHEAD_ANALYSIS

Experimentos reais finitos no mesmo código canônico nativo; observador diferente,
host/carga diferentes de G. Um cold full sample após leitura de identidade,
12 uniformes e12 ticks split (6 consultas slow). Nenhuma cadência vinculada.

| Candidato | Custo médio | Min–max | p95 nearest-rank | Overruns>500 ms | Maior start lateness |
| --- | ---: | ---: | ---: | ---: | ---: |
| G histórico uniforme500 | 227,3 ms | 199–247 ms | 247 ms | 0/12 | 16 ms |
| H uniforme500 | 224,8 ms | 174–266 ms | 266 ms | 0/12 | 21 ms |
| H fast500 + slow1000, tick completo | 132,2 ms | 14–285 ms | 285 ms | 0/12 | 15 ms |
| H apenas leitura fast RAM/PID/porta | 14,4 ms | 13–17 ms | 17 ms | — | — |

Cold H1162 ms vs G1184 ms; não comparar com warm como máximo garantido.
Uniforme H: GPU175,8 ms mean (~78% da coleta), processo12,2, porta0,6,
concorrência13,0, disco21,2. Porta/RAM rápidas podem ser verificadas a cada tick;
metadados de image hash/identity precisam recheck contra PID reuse. Eventual cache
de hash exige pin/file-identity/tamper semantics, não foi ativado. GPU/actor/disk
podem ter scheduler separado, com timestamps reais preservados por componente.

Probes independentes n=3: NVIDIA global57,7 ms mean; process49,95 ms;
WDDM adapter19,75 ms. WDDM process467,2 ms no primeiro probe vs31,65/27,38
seguintes; mean175,4 inclui first-use. Demonstra variação/custo de provider,
não prova cache age. Process query N/A tem custo sem resolver residência, mas
a lista de atores ainda tem utilidade e cobertura incompleta.

CPU por janela do observador: uniforme4421,9 ms CPU /5778 ms wall =76,5% de
um core; split3703,1/5522 =67,1%. Média bracketed CPU/tick196,6 vs59,9 ms é
outra estatística, não CPU total da janela. Exclui helpers NVIDIA/WmiPrvSE;
atividade entre brackets/GC/scheduler também custa CPU. Não declarar economia
global nem extrapolar para startup. Split reduziu mean tick ~41%, mas p95 tick
285 ms excede o uniforme266 ms; há ticks slow e maior cauda observada. CPU continua
material. n12: p95=max observado, não bound de população ou tempo máximo.

Cache explícito slow no experimento: máximo acquisition/receipt age516 ms,
timestamps originais mantidos. Não houve amostra slow com idade de geração
provada. Split continua síncrono/sequencial aqui; slow hung ainda bloquearia.
Disco canônico enumera evidence Stage03G, não Stage03H: escopo anotado e fonte
preservada; um monitor futuro deve usar paths do run aprovados.
Dados: [sampling-summary](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03h/evidence/sampling-summary.json).

## F. NVIDIA_WDDM_ATTRIBUTION_RESULT

NVIDIA global disponível: RTX5080 Laptop, driver617.42, UUID
GPU-REDACTED, PCI00000000:C3:00.0,
device/vendor0x2C1910DE. Diagnóstico global: total16303 MiB,
used2757/free13247, diferença299 MiB não classificada, utilização2% naquele instante.
31 process rows NVIDIA, todos VRAM N/A=null. A documentação NVIDIA descreve
a indisponibilidade da memória por processo em WDDM porque o gerenciamento é
feito pelo kernel Windows; isso é consistente com a observação local.
[NVIDIA SMI](https://docs.nvidia.com/deploy/nvidia-smi/index.html).

Novo achado real: descritor DXGI de nome exato RTX, vendor10DE/device2C19 fornece
LUID `luid_0x00000000_0x00018816`. AMD890M=...19CC8; software render=...19C45.
Enumeração de descriptors, sem D3D device/context/workload. Nome/vendor/LUID
identificam RTX dentro do Windows; não por tamanho de memória. DXGI fornece
AdapterLuid e IDs de hardware diretamente.
[DXGI_ADAPTER_DESC1](https://learn.microsoft.com/en-us/windows/win32/api/dxgi/ns-dxgi-dxgi_adapter_desc1).

37 linhas WDDM PID/LUID associadas a esse descriptor. NVIDIA nome/device/vendor
coincide, mas não há campo UUID comum direto no descriptor: ponte LUID->UUID
independente permanece NOT_VERIFIED. Canônico continua NOT_VERIFIED, sem promover
a descoberta StageH ou persistir um LUID desta sessão como ID eterno.

Contabilidade não é residência validada: dwm PID2516 dedicated counter
21325287424 bytes (19,862 GiB), maior que capacidade global NVIDIA15,92 GiB;
committed nessa linha870490112 bytes (~0,811 GiB). Logo não interpretar essa
coluna como bytes físicos exclusivamente residentes daquele PID. Shared é
contabilidade de memória compartilhada/sistema; committed é compromisso virtual,
não comprovação de residency. Não somar dedicated/shared/committed como VRAM
individual. A Microsoft documenta problema conhecido de contadores em Windows10;
é contexto de cautela, não diagnóstico da causa neste host.
[Microsoft counter caveat](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/gpu-process-memory-counters-report-wrong-value).

Engine observation detectou RTX3D/video-decode em PIDs21864(Codex frontend),
2516(dwm),26836(Brave) e37088(Omen); windows de sampling/coverage desconhecidas.
Sem alegação de render ou de exclusividade. Raw WDDM tem Timestamp_Sys100NS,
mas PerfTime/Frequency_PerfTime=0; uma conversão exploratória como FILETIME UTC
produz offset~3h futuro relativo ao receipt, sem clock/epoch validados.
Não corrigir por timezone ou deduzir idade. Providers usam timestamps em fórmulas
de contadores; isso não demonstra timestamp de geração de cada métrica.
[Win32_PerfRawData](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-perfrawdata).
RTX PID physical VRAM residency e actual generation age: NOT_VERIFIED.
Dados: [DXGI evidence](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03h/evidence/dxgi-adapter-evidence.json).

## G. GLOBAL_GPU_PROXY_CONTRACT_PROPOSAL

[SUPERVISED_G4_GLOBAL_GPU_PROXY_PROPOSED](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03h/SUPERVISED_G4_GLOBAL_GPU_PROXY_PROPOSED.md)
é especificação formal somente. Startup G4 sem modelos, nunca G5/Alpha/inference;
baseline imediato válido e imutável; global delta<=2 GiB; unknown contention/activity
bloqueia; actor change report+block; missing/inconsistent/stale bloqueia;
sem per-PID claim, restart ou consentimento implícito. Mantém demais caps.
Global delta pode esconder movimentos simultâneos e causar aborto conservador.
Aceitação explícita do risco/freshness proxy e consentimento específico continuam
obrigatórios. Nenhuma exceção habilitada em policy ou evaluator canônico.

## H. PROVIDER_FRESHNESS_AND_WATCHDOG_DESIGN

[Design completo](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03h/PROVIDER_FRESHNESS_AND_WATCHDOG_DESIGN.md).
Receipt age desde aquisição original inclui duração de coleta; actual provider
age/cache continua UNKNOWN. O parâmetro2000 ms não resolve essa distinção.
Proposta: supervisor independente sem queries síncronas, worker futuro isolado,
mailbox bounded1, envelopes immutable por acquisition/request/sequence/clock,
deadline monotônico120s separado do sampler. Failed sampler bloqueia; hung/stale
bloqueia sem esperar pela query. Cache/heartbeat nunca renova acquisition age.

Simulação não chama sampler: detectou stale em tick sintético2020 ms, quantum20;
deadline exato120000, failed, cache rewrite, queue/sequence/clock inválidos.
Não houve tempo real120s, IPC real, hung subprocess real ou stop testado.
Timeout de espera/runspace não garante cancelamento de chamada nativa. CLI NVIDIA
síncrona atual não tem hard deadline comprovado. Cancelar/encerrar helpers próprios
exige changeset e autorização separada posterior; não implementado nem solicitado
como G4 agora. Gate BLOCKED não comprova parada de um runtime; own-stop operacional
continua uma dependência anterior ao futuro startup.

## I. HUMAN_PARAMETER_BINDING_PROPOSAL

| Campo | Proposta futura | Estado atual |
| --- | --- | --- |
| operator_identity | Confirmar WORKSTATION\user / S-1-5-21-REDACTED | UNKNOWN/null |
| cpu_budget | OBSERVE_ONLY durante G4 startup; sem teto percentual, deadline120s mantido | UNKNOWN/null |
| polling_cadence_ms | 500 ms candidato; slow1000 ms é scheduler adicional proposto, sujeito revisão/testes | UNKNOWN/null |
| telemetry_freshness_ms | 2000 ms de acquisition/receipt age; decisão generation proxy distinta | UNKNOWN/null |

Boundary SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0 permanece escolhido. Conta/SID
observados não são autenticação independente ou consentimento; nenhuma nova
decisão de isolamento é solicitada. Policy SHA preservado, valores não vinculados.

## J. TESTS_AND_EVIDENCE

103 PASS /0 FAIL final:68 checks de contratos/regressões de recursos canônicos
adaptados somente ao namespace H;35 checks de modelo de proposta/supervisor.
102 checks frescos e1 recheck da medição real H armazenada. Não são103 runtimes.
Incluem exact/exceeded RAM/commit/private/VRAM/disco; missing/type/identity/PID reuse;
stale/generation unknown/clock/deadline; portas IPv4/IPv6 sintéticas;
GPU actors/changed/unknown; proxy G5/Alpha/models recusados; mocked stop apenas
em memória, sem consentimento humano; G4 Admission e G5 launcher reais recusados
por contratos estáticos, sem startup/submissão. Nenhum mock virou policy.

Reais:426 PIDs, PSAPI, NV/WDDM/DXGI,1 cold +12 full samples +12 fast ticks com6
slow refreshes, probes3x4componentes eengine query única. Inferências: opções de
recuperação, provável redução de custo, mapping lógico NVIDIA/Windows e riscos.
Simulações: métricas ideais, actors classificados, provider-proxy assumido para
teste, supervisors/callback stop fictícios. Nenhuma comprova lifecycle operacional.

Preservados: timeout raw-process diagnóstico1, fonte original e fonte2, erro
pré-escrita do leitor baseline. Não são PASS nem FAIL final de contratos; provider
raw indisponível permanece limitação explícita. Sem retry da consulta que expirou.
Probes cold são novos contextos declarados, sem promessa de bounds.
[Resultados](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03h/evidence/consolidated-results.json),
[resumo](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03h/evidence/test-summary.json),
[limitações](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03h/evidence/interpretation-limitations.json).

## K. MINIMUM_NEXT_CHANGESET

[Changeset, dependências, permissões, aceitação e rollback](D:/WHAT-LIES-BTWN-PRODUCTION-OS/tests/stage03h/MINIMUM_NEXT_CHANGESET.md).
Mínimo recomendado: preparar supervisor/envelopes/sampler desabilitados e novos
testes; atualizar pins lock/manifest coerentemente após changeset autorizado.
Start-WlbRuntime continua estático no PREP-ONLY; binding de policy e real
lifecycle são gates separados. Validator Startup atual exige UNKNOWN/null:
binding futuro exige também changeset de contracts, não mera edição JSON.
Nenhum arquivo canônico alterado para fingir capacidades. Backup/diff antes;
rollback conjunto de source/policy/bindings sem apagar evidência nem reautorizar.
Snapshot, environments existentes e launcherG5 fora da preparação mínima.

## L. REMAINING_G4_BLOCKERS

RAM não é blocker atual observado, mas precisa recheck imediato: se<8 GiB,
G4 BLOCKED sem ação automática. Permanecem RTX PID residency/source generation
age e exclusividade/atividade GPU não provados; modo global proposto não habilitado;
quatro bindings e consent confiável ausentes; supervisor não bloqueante,
owned start/stop/port e one-attempt/recovery não operacionais. Identidade efetiva
Python/stdlib/DLLs/native packages/frontend/assets/DB/import compatibility F
permanece NOT_VERIFIED. Snapshot conteúdo pronto não prova execução.
Nenhum consentimento/approval ID/reserva de startup novo.

## M. REMAINING_G5_BLOCKERS

Launcher/executor bloqueados e byte-idênticos. Sem G4 comprovado nem consentimento
do job, binding/atomic consumption/replay, engine/submission/REST,30s reais,
output/render/QC independente. Proxy startup-only nunca cobre job/Alpha.

## N. NO_OUT_OF_SCOPE_MUTATION_ATTESTATION

Zero arquivo preexistente alterado/removido;3.237 preservados,619 snapshot intactos,
reserva E e evidências F/G mantidas. Novos arquivos somente tests\stage03h e os
dois relatórios StageH na raiz. Inventário com paths absolutos/SHA256 e final-audit
fazem parte da entrega; políticas/params/conteúdo snapshot mantidos.

Sem Python/Comfy/server/model/inference/job, processo existente encerrado,
suspenso/modificado; sem cache/RAM/pagefile cleanup, installs/downloads de tools,
ACL/firewall/registro/serviços, runtime/job launcher ativado, consentimento/commit
ou alteração MIRAE/PULSE/LTX/Comfy environments. PowerShell/.NET/Add-Type em
memória, descriptors DXGI e utilities NVIDIA transitórias de consultas passivas
foram usados; não são execução de produção e seu custo não foi ocultado.
Houve leitura de documentação pública Microsoft/NVIDIA, sem instalação nem
alteração de rede. Atestação cobre comandos e arquivos conferidos, não a atividade
independente de Windows/apps nem uma garantia futura de sandbox da mesma conta.

## O. NEXT_GATE = WAITING_HUMAN_REVIEW

STOP_AFTER_DELIVERY. Design e evidência para revisão, sem pedido automático de
autoridade G4, habilitação de proxy, execução ou continuação G5/Alpha.
