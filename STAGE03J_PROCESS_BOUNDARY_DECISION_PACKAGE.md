# WHAT LIES BTWN — Production OS
# Stage03J — Worker Process Boundary & Owned Helper Lifecycle

## A. STAGE03J_STATUS

**STAGE03J_STATUS = PARTIAL_WITH_BLOCKERS.** A fronteira real entre processos, IPC limitado e parada por handle próprio estão implementados e demonstrados. A aceitação integral de recursos falhou: RAM disponível abaixo de 8 GiB. A entrega permanece preparada e sem autoridade de produção.

Matriz selecionada: **137 PASS / 1 FAIL**. O FAIL de RAM permanece explícito. Após sua identificação, cessou a criação de helpers e foi adicionada uma guarda de admissão que recusa recursos indisponíveis, malformados ou abaixo de 8 GiB de RAM/10 GiB de commit headroom. A recusa é terminal para a tentativa e foi comprovada sem criar processo. Não houve novo teste de startup sob essa guarda em condição elegível.

Modelo solicitado: GPT-6.1 Sol; esforço solicitado: High. A configuração ativa da sessão não foi atestada pelas ferramentas; nenhuma configuração de aplicação foi modificada.

## B. VERIFIED_STAGE03I_BASELINE

Os 14 documentos obrigatórios foram lidos integralmente antes de alterações canônicas. A identidade dos 3.387 arquivos preexistentes e dos 19 prepared artifacts foi verificada sem drift. Baseline histórico: Stage03I COMPLETE_WITH_LIMITATIONS, 198 PASS/0 FAIL final, worker anterior em runspace, supervisor sem autoridade e snapshot STAGED_NOT_ACTIVATED.

SHA-256 de STAGE03I_DELIVERY_INTEGRITY.json: 69aefeafed1c31c0c32969d12a15b26b7b3cf56f6a3f0b400105d7e9cd025e2e. O histórico não foi reexecutado como auditoria geral nem somado aos testes Stage03J. Evidências: tests/stage03j/evidence/baseline-verification.json e baseline-files.csv.

No fechamento, **3.384 arquivos antigos continuam idênticos e somente três arquivos existentes foram alterados**. Nenhum arquivo antigo foi removido. O snapshot de 619 arquivos, 9.533.695 bytes e 11 grupos continua verificado, não ativado; os validadores Plan/Admission continuam sem caminho de execução.

## C. EXACT_CHANGESET_AND_HASHES

O changeset mínimo foi registrado em tests/stage03j/evidence/proposed-changeset.json antes das alterações canônicas. Dois novos componentes são registrados como prepared artifacts: módulo de fronteira e helper fixo. Os demais novos arquivos são testes, cópias de rollback e evidências no namespace Stage03J, além desta entrega.

| Arquivo | Tipo | SHA-256 final |
|---|---|---|
| core\Wlb.WorkerProcess.ps1 | NEW | dd20a1e2e26b766d45faefb5c76fcf689426446a9c39798a9ad36f211ff68a29 |
| tests\stage03j\OwnedTelemetryWorker.ps1 | NEW | b89d0bcbae989d7d15b98539310fc227211897710d0d9277e2504219ab3d502e |
| core\Test-WlbManifest.ps1 | MODIFIED | 1406954595be085464689f7a9e337ef29c605f2ae395cc91809e49509be7df74 |
| policy\runtime-lock.json | MODIFIED | 7c051ecc3926898796f400a2dd4336a1ec773ed970552afaf79f2d2251674d94 |
| manifests\draft\POC0-CALIBRATION-001.json | MODIFIED | 2e3e049e60d4f5b5c752715f572658dd842beb1ff113bcb14af1c1ea8af3bbe0 |

Alterações nos três canônicos, comprovadas por comparação exata:

- Test-WlbManifest.ps1: somente duas entradas adicionadas à allowlist, de 19 para 21.
- runtime-lock.json: hash do validador atualizado e dois pins novos; todos os demais campos e os outros 18 pins anteriores permanecem idênticos.
- Manifest DRAFT: somente substituição de 64 caracteres no binding SHA-256 do lock.

A adição final da guarda de recursos altera apenas o novo módulo StageJ e seus pins dependentes. startup-policy.json, startup-identity.json, executor-policy.json, os três módulos Supervisor/TelemetryWorker/RuntimeMonitor e ambos os launchers originais mantêm os hashes do Stage03I.

O inventário STAGE03J_SHA256_INVENTORY.csv cobre todos os arquivos novos e os três modificados, incluindo tentativas falhas e fontes preservadas. Os dois arquivos de fechamento — inventário e DELIVERY_INTEGRITY.json — são excluídos de seu próprio inventário para evitar autorreferência; o JSON fornece hashes do inventário, relatório e matriz. Nenhum deles é autorização de execução.

## D. PROCESS_BOUNDARY_IMPLEMENTATION

O supervisor é o processo PowerShell que executa o harness. O worker é um processo PowerShell separado, criado com CreateProcessW, sem janela, perfil ou comandos arbitrários. Executável fixo: C:/Users/user/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe, SHA-256 362a356ce7f0940ec74f73a8fc2c990a2cc24a38a11c90bbd8eca947110ad139. Helper e diretório de trabalho são fixos em tests/stage03j.

O supervisor não chama collectors no caminho de tick. Connect/read/write são tarefas assíncronas; GetResult só é chamado após IsCompleted. A consulta ou o sono do worker não bloqueiam os ticks. O harness usa espera experimental de 20 ms, mantém no máximo 2.048 ticks por teste e não altera a cadência humana UNKNOWN. Esses intervalos não garantem escalonamento hard real time.

O registro mantém o handle retornado pela criação, PID, FILETIME de criação, imagem/hash, hash do helper, token e tentativa. Metadados incertos permanecem registrados com handle retido e sem autoridade de parada. Há limite de dois helpers simultâneos e 32 tentativas consumidas por processo supervisor; a reserva de criação é serializada. Foram efetivamente criados 36 helpers em seis rodadas, sempre um de cada vez, distribuídos entre processos supervisores distintos.

TEMP, TMP e PSModuleAnalysisCachePath são redirecionados apenas no ambiente dos filhos para scratch da tentativa StageJ. Não foram alteradas variáveis globais, configurações de host ou ACLs de arquivos existentes. Importar o novo módulo define funções; não inicia helper, pipe ou runtime. Start-WlbRuntime.ps1 não importa o novo módulo.

## E. IPC_AND_CLOCK_VALIDATION

Foi escolhido um named pipe local por tentativa: nome GUID, uma instância, first instance, overlapped I/O e PIPE_REJECT_REMOTE_CLIENTS. A DACL é definida na criação do próprio objeto efêmero para o SID atual. Nenhum listener TCP/HTTP é criado. O framing é prefixo uint32 de tamanho e UTF-8 estrito, limitado a 65.536 bytes por mensagem. O pipe tem buffers solicitados de 65.536 bytes; o Windows trata esses tamanhos como sugestão, não hard cap. [CreateNamedPipe](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-createnamedpipea).

O cliente confirma o PID nativo do servidor; o servidor confirma o PID nativo do cliente contra o lease. Cada mensagem exige schema, attempt ID, nonce, fingerprint exato do worker, sequência contígua e clock ID. O fingerprint usa PID, creation time, imagem e hash. Duplicação, replay, fora de ordem, campos inesperados, JSON com chaves duplicadas/case collisions, tamanho inválido, UTF-8 inválido, truncamento e EOF são recusados. [Identificação nativa do cliente](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getnamedpipeclientprocessid).

O helper usa stop-and-wait ACK e envia no máximo uma amostra pendente. O supervisor guarda uma única amostra, recusa a segunda sem consumo e preserva a idade da última aquisição mesmo depois do consumo. ACK contém somente identidade, sequência e autoridade false, sem comandos executáveis. O filho tem connect/ACK/write timeout de 8 segundos e não faz retry.

Cada tentativa cria um session ID novo e o worker anuncia um clock ID próprio. Após HELLO, um challenge vincula tentativa/nonce/session. A prova exige frequência QPC igual, timestamps do filho dentro do roundtrip bruto do pai, tolerância de um tick nas bordas e roundtrip <=500 ms. Nas seis provas finais, RTT observado de 88,071 a 122,873 ms. A aceitação só marca clock_verified após essa prova; nenhum ID do Stage03I é reutilizado como prova. A documentação Microsoft sustenta a coerência de QPC no mesmo computador e a ambiguidade de ordenação de um tick entre contextos; a negociação operacional não é autenticação do relógio contra um processo comprometido. [QPC e timestamps de alta resolução](https://learn.microsoft.com/en-us/windows/win32/sysinfo/acquiring-high-resolution-time-stamps).

Acquisition age usa timestamps originais do envelope. Receipt age é calculada à parte; heartbeat não renova medição consumida. Provider generation age continua UNKNOWN e ProviderGenerationVerified=false. Cache slow preserva timestamp e sequence originais. IPC sob a mesma conta Windows **não constitui autenticação independente**, sandbox ou isolamento contra essa conta. Hashes de arquivo são leituras pontuais, não atestação da memória executada nem proteção contra adulteração pela mesma conta.

## F. OWNED_HELPER_START_STOP_RESULTS

Modos fixos: NORMAL_EXIT (amostra mínima e saída), FINITE_DELAY (1.250 ms), SIMULATED_HANG (sono de 30.000 ms), CONTROLLED_FAILURE (saída 23) e HEARTBEAT_INTERRUPTION (3.000 ms sem heartbeat). Os modos de interrupção não executam consultas NVIDIA, workload pesado ou comandos externos.

| Caso final | PID próprio | Ticks | RTT clock ms | Máximo intervalo ticks ms | Saída | Parada solicitada |
|---|---|---|---|---|---|---|
| normal-passive | 34664 | 62 | 104.663 | 166 | 0 | 0 |
| finite-delay-and-denials | 48876 | 92 | 113.63 | 144 | 0 | 0 |
| hang-short-timeout | 48704 | 68 | 88.071 | 38 | 197 | 1 |
| controlled-failure | 39960 | 52 | 119.969 | 36 | 23 | 0 |
| heartbeat-interruption | 37624 | 110 | 118.852 | 36 | 197 | 1 |
| channel-closed | 40888 | 46 | 122.872 | 38 | 197 | 1 |

A saída 197 identifica TerminateProcess solicitado para helper próprio. A parada é uma ação separada da decisão BLOCKED do supervisor. O método só aceita o lease registrado por referência, o creator PID atual, tentativa/nonce, handle mantido e tuple PID/creation time/imagem/hash sem divergência. O hash atual do helper também é rechecado. Não existe abertura de alvo por PID para encerrar, kill por nome, kill de árvore ou limpeza de Python/PowerShell.

A identidade de processo é ancorada no handle de criação, pois PID pode ser reutilizado; o handle é fechado apenas depois de provar saída. [Handles e IDs de processo](https://learn.microsoft.com/en-us/windows/win32/procthread/process-handles-and-identifiers), [FILETIME de criação](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes).

Foram recusados, sobre helper real: tentativa chamadora estrangeira, nonce errado, creation time divergente simulando PID reutilizado, PID errado, hash errado, lease ausente/simulado e razão de parada fora do escopo. Reinicializar a mesma tentativa também foi recusado. O helper do teste de recusas saiu naturalmente com código 0; nenhum processo preexistente foi usado como alvo. Identidade incerta exige BLOCKED/reconciliação humana, não encerramento presumido.

Todos os 36 helpers têm evidência nativa de saída antes do fechamento de seus handles. Isso não prova limpeza ou ownership de eventuais helpers NVIDIA iniciados pelo collector histórico na rodada run02.

## G. WATCHDOG_AND_FAILURE_RESULTS

No hang final, o deadline experimental de 750 ms após a prova de relógio foi detectado em **778 ms**, com worker ainda vivo. Os 68 ticks continuaram sem esperar o sono de 30 segundos; maior intervalo entre ticks: 38 ms. Houve exatamente uma solicitação de parada própria e saída 197. O G4 mantém 120.000 ms e foi testado separadamente por injeção monotônica no limite exato; nenhum teste real ficou aberto por 120 segundos.

A perda de heartbeat foi detectada aos 2.016 ms após a prova de relógio, usando o timestamp original de produção do heartbeat, antes do término do sono de 3 segundos. O fechamento do pipe causou falha terminal e parada própria. A saída controlada 23 produziu EOF/perda de worker sem kill. Terminal não permite retry/restart automático. A recusa final por recursos também é latched e bloqueia nova chamada na mesma tentativa.

Falhas parciais preservadas: run01 descobriu marshaling ANSI indevido de QueryFullProcessImageNameW, que retornava caminho truncado. A identidade foi tratada como incerta, a parada recusada e os seis helpers saíram com código 1. A declaração Unicode foi corrigida. run02 mostrou coleta completa acima de freshness e uma corrida de saída/parada; run03/run04 preservam reparos. run05 revelou repetição da parada no harness durante a transição de saída; run06 usa latch de solicitação e stop_history, sem falhas de harness. A matriz checks01 conserva 113 PASS/2 FAIL; esses resultados não foram apagados.

Na rodada final, NORMAL_EXIT usa somente host memory e observação do próprio processo: 105 ms de coleta, payload de 1.337 bytes e 156 ms de aquisição até recebimento. GPU, port, disk e concurrency ficam explicitamente UNKNOWN_NOT_QUERIED. O collector completo Stage03I continua intacto e não foi integrado ao startup. Essa amostra valida transporte de telemetria mínima, não avaliação completa dos recursos de G4.

## H. TELEMETRY_AND_RESOURCE_LIMITATIONS

Limites canônicos preservados: RAM >=8 GiB, headroom >=10 GiB, commit incremental <=4 GiB, private bytes <=4 GiB, VRAM incremental <=2 GiB, startup 120 s, job 30 s e output/log/temp <=256 MiB. São limites de avaliação/interrupção de software; não hard caps do sistema operacional. Candidates 500/1.000/2.000 ms permanecem experimentais e não foram gravados nos quatro parâmetros humanos.

**Bloqueio real de RAM:** mínimo observado na rodada final de 5.095.104.512 bytes (**4,75 GiB**). A leitura ao testar a guarda final foi 5.313.044.480 bytes (**4,95 GiB**). Headroom mínimo observado: 26.175.029.248 bytes (24,38 GiB). Private bytes do helper na amostra: 89.432.064 bytes (85,29 MiB). Maior delta positivo global de commit antes/depois: 48.226.304 bytes (45,99 MiB), sem atribuição causal ao helper. Essas são leituras discretas, não provas de pico ou enforcement contínuo.

Falha de condução preservada: a condição de RAM só foi usada como bloqueio de criação depois da avaliação final. **17 de 36 tentativas tiveram leitura anterior à criação abaixo de 8 GiB**: cinco em run04 e seis em cada run05/run06. Elas não recebem aceitação plena de orçamento. Não há prova retrospectiva de interrupção por RAM. A guarda final foi adicionada para impedir nova criação nessa condição; seus nove testes passaram, incluindo recusa real sem lease e recusa de restart. Não houve tentativa de liberar RAM encerrando aplicações externas.

O footprint criado antes dos documentos de entrega é cerca de 2,16 MB; o fechamento registra o valor final. Isso não é monitor contínuo de todos os arquivos de um futuro runtime. A guarda cobre somente admissão pontual RAM/headroom; CPU, private peak, delta commit, GPU e disco operacional permanecem pendentes de integração e supervisão.

GPU global proxy permanece PROPOSED_ONLY. RTX PID VRAM residency, LUID↔NVIDIA UUID e exclusividade de atores continuam NOT_VERIFIED. WDDM accounting não comprova residência física; N/A de NVIDIA por processo não vira zero nem medição verificada. Idade de geração não é inventada. A rodada run02 reutilizou consultas passivas fixas do Stage03I; não houve teste deliberado de hang NVIDIA ou encerramento de seus descendentes. Qualquer lifecycle futuro de comandos NVIDIA deve ser objeto de autorização separada, com criação/identidade/handle próprios e sem cleanup genérico.

## I. REGRESSION_MATRIX

[Matriz completa](D:/WHAT-LIES-BTWN-PRODUCTION-OS/STAGE03J_TEST_MATRIX.md): 138 verificações selecionadas, 137 PASS/1 FAIL. Evidências selecionadas: checks03-checks.json, guard02-checks.json e audit02-integrity-checks.json em tests/stage03j/evidence. Provas reais: run06-real-index.json e seus seis arquivos individuais; audit02-final-audit.json detalha comparação de conteúdo.

Regressões relevantes: 21 pins atuais, allowlist exata, binding DRAFT, budgets, quatro parâmetros UNKNOWN/null, policy false, consent ABSENT, snapshot619 STAGED_NOT_ACTIVATED, StaticReview sem execução, ExecutionEligibility recusado, G4 Admission recusado e G5 sem aprovação recusado. Não houve aprovação simulada em arquivos nem consumo de consentimento. Após a guarda final, essas regressões foram reexecutadas sem novo helper.

## J. OUT_OF_SCOPE_MUTATION_ATTESTATION

Nenhuma ação explícita executou Python/imports, ComfyUI/LTX Desktop, inference, modelos, jobs GPU, instalação, download de payload, modificação de host, commit, ativação de proxy, aprovação G4/G5 ou alteração dos quatro parâmetros humanos. Não houve escrita intencional em ambientes externos, MIRAE ou PULSE nem encerramento de processos preexistentes.

Writes explícitos se limitaram ao novo componente core, namespace tests/stage03j, três canônicos de binding e documentos Stage03J. A verificação de 3.387 arquivos preexistentes delimita a atestação de conteúdo no Production OS; não é alegação forense de imutabilidade de todo o host ou das escritas normais de Windows/aplicações. As referências Microsoft foram consultadas somente como documentação pública.

## K. REMAINING_G4_BLOCKERS

| Dependência / decisão futura | Permissão necessária | Critério de aceitação / gate |
|---|---|---|
| RAM/headroom elegíveis e novo teste sob a guarda final | Revisão humana e autorização de nova tentativa StageJ; nenhuma aplicação externa pode ser encerrada por este contrato | Leitura fresca >=8/10 GiB; startup e saída próprios sob a guarda, com evidência completa. Hoje BLOCKED |
| Supervisor contínuo de orçamentos e collector completo fora do pai | Changeset explícito limitado a código próprio, novos bindings e testes | Queries lentas/hang não suspendem ticks; idade original, geração/exclusividade tratadas honestamente; limites interrompem somente alvos próprios. NOT_VERIFIED |
| Lifecycle de eventuais helpers NVIDIA | Autorização separada para executáveis/argumentos passivos fixos, registry e handles desde a criação | Nenhum processo preexistente/descendente genérico; identity mismatch recusa; timeout não perde evidência nem amplia ownership. PENDING |
| Fonte de GPU atribuída ou alternativa global proxy | Escolha humana explícita; proxy não está autorizado | Prova de residency/freshness por PID, ou limitação alternativa formalmente aceita apenas para G4 sem modelos. PROPOSED_ONLY |
| Quatro parâmetros humanos e consentimento real | Identidade do operador, CPU, polling, freshness e contrato de consentimento definidos pelo humano | Valores deixam UNKNOWN somente em etapa autorizada; consentimento válido, escopo único e vínculo de conteúdo. ABSENT |
| Compatibilidade de runtime, port owner, disco e parada do futuro runtime próprio | Contrato específico que autorize os probes/runtime então necessários | Python/native/frontend/DB verificados; port/process tuple; output/log/temp agregado; own lifecycle. Esta etapa não os executa |

Nenhuma linha da tabela constitui aprovação antecipada, convite para executar automaticamente ou substituição das restrições desta etapa. G4 permanece fechado.

Rollback planejado, **não executado**: manter todos os gates false; confirmar ausência de helper vivo e preservar evidências; validar os três backups StageI; restaurar somente Test-WlbManifest.ps1, runtime-lock.json e o binding DRAFT dos backups em tests/stage03j/baseline; verificar os 19 pins e StaticReview. Os arquivos novos podem permanecer arquivados e fora da allowlist; não apagar tentativas ou evidências nem tocar ambientes externos. Uma falha de identidade/processo exige reconciliação humana antes de qualquer limpeza.

## L. REMAINING_G5_BLOCKERS

G5 depende da resolução e aprovação explícita de G4, de aprovação humana por job, identidade de manifest/graph/bindings, adapter de submit, isolamento de outputs, supervisão durante workload, accounting e cancelamento do processo próprio. Nada disso foi autorizado ou validado por testes benignos de StageJ. O launcher continua execution_enabled=false e recusa ausência de aprovação. Alpha Gen permanece capacidade especializada posterior; MCP e novos runtimes continuam fechados.

## M. NEXT_GATE = WAITING_HUMAN_REVIEW

**WAITING_HUMAN_REVIEW.** Pacote preparado com bloqueio de RAM e de validação contínua claramente registrados. Nenhum startup posterior, retry, instalação, aprovação ou execução G4/G5 será iniciado automaticamente. STOP AFTER DELIVERY.