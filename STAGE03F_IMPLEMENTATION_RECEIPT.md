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

| Arquivo | SHA256 antes | SHA256 depois |
| --- | --- | --- |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\core\Start-WlbRuntime.ps1 | 3ed6a6cea5f1602bc47f95ffc4b031a102b12f9fdfe3f204b259ff9dfc6b9e26 | 427be7379bc15750ece78b77911bf68515c37a28659c80d30531ac858893f25c |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\core\Wlb.Startup.ps1 | 1fffe9825cb7d7044e4e8e0dd2431aa9df559fec450c356e69538859cdd3825d | 6847dc5439c22f0db5d00f6f5f647e31821847374b3787537fb0a0fa75840267 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\manifests\draft\POC0-CALIBRATION-001.json | 349503c85cde19f23558f4dcecdaf4192dfea9cef52e19aa264cdf36fe5eeebb | 2a72ff8fc4ce23eafad3a62555e69624366d1e83af5d27c7e55dec74f249f287 |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\policy\runtime-lock.json | 2cba41ae01245961e941edb9d1f5ce016b773d6a7d99236d5e71c1b2f4727a98 | bc00c6a14e1671dbd15c1caf4f7d59e4362affa798d951144a1daebe6296333a |
| D:\WHAT-LIES-BTWN-PRODUCTION-OS\policy\startup-identity.json | 7f42355c74483f6965f6eb6e837b5ac09d71485fcde610882bc627c3dd420edb | 10e751ee38ed20b62f0887439f4d31fb492f053131d3ff64e7ca8a0160e22187 |

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