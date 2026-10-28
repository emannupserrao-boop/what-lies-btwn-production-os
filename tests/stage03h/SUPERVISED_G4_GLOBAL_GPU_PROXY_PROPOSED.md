# SUPERVISED_G4_GLOBAL_GPU_PROXY_PROPOSED

Status: PROPOSED_ONLY / NOT_ENABLED / NOT_EXECUTION_AUTHORITY.
Stage03H não altera policy/evaluator, não cria consentimento e não abre G4.

## Escopo e condições necessárias

1. Apenas uma tentativa futura de startup G4 supervisionado, sem modelos,
   inference, submissão, render ou carregamento de workflow. Nunca G5/Alpha.
2. Antes da tentativa, adquirir baseline global NVIDIA válido, imediatamente
   anterior ao lançamento, após warm-up autorizado. UUID/modelo/driver registrados;
   exatamente a RTX pretendida; counters inteiros não negativos e coerentes.
   O baseline não pode ser uma amostra Stage03G/H histórica ou renovado depois.
3. RAM física disponível >=8 GiB, commit headroom >=10 GiB em baseline e amostras;
   incremental commit <=4 GiB, own private bytes <=4 GiB; output/log/temp <=256 MiB;
   deadline monotônico 120 s preservado. Igualdade nos limites passa só recursos.
4. Global used VRAM minus baseline <=2 GiB. Inclui todos os atores; não atribui
   alocação ao alvo. Queda/reversão global implica BLOCKED_RECONCILE, sem rebaseline.
5. Inventário de atores e atividade GPU precisa estar conhecido/revisado. Ausência
   de heavy-process names ou GPU utilization=0 não comprova exclusividade.
   Atividade não classificada, heavy GPU work, counter incompleto ou identidade
   inacessível impedem admissão/continuação. Desktop compartilhado exige aceitação
   específica do risco de cobertura; essa aceitação não foi obtida nesta etapa.
6. Identificar atores com PID+creation+image; registrar diffs de entrada/saída,
   troca de imagem, driver/adapter/device/UUID/LUID. Mudança reportada e bloqueia
   a tentativa até reconciliação humana, sem restart automático ou expansão da lista.
7. Ausência, inconsistência, envelhecimento, provider/sampler failure, sequence
   inválida, fila excedida, unknown port/own tuple ou perda de observador bloqueia.
8. Receipt proxy candidato 2000 ms é contado desde aquisição original, incluindo
   duração da coleta; cache nunca renova esse timestamp. Actual provider generation
   age continua UNKNOWN. Se idade de geração for exigida, este modo continua
   bloqueado. Aceitar um proxy exige decisão humana explícita, separada do binding
   de 2000 ms; não converter UNKNOWN em VERIFIED.
9. Consentimento humano G4 específico, autenticação/one-attempt/replay/expiry,
   bindings aos hashes finais, modo global selecionado e ownership de lifecycle
   são dependências obrigatórias da operação. Observações de conta/SID, hashes
   ou aprovação deste documento não são consentimento de execução.
10. Sem retry/restart. Aborto exige futuro adapter de parada com ownership exato,
    authority própria e rechecagem imediatamente antes da ação. Não parar processo
    anterior, helper estrangeiro ou árvore descendente por nome. Resultado
    desconhecido e falha de cleanup permanecem BLOCKED_RECONCILE.

## Aceitação futura

Todos os requisitos acima simultâneos; fixtures não concedem autoridade.
Demonstrar baseline imutável, exact/exceeded 2 GiB, unknown/changed actors,
stale/cache/missing/inconsistent/clock failure, foreign/reused PID, no retry e
G5/Alpha denial. O modelo de revisão Stage03H aceita somente SIMULATED_TEST_ONLY,
retorna authorized=false mesmo em caso positivo e não é um evaluator operacional.

## Limitações e rollback

Não é sandbox, egress enforcement, hard cap físico nem per-PID VRAM.
Não detecta necessariamente picos entre amostras. Contenção pode causar aborto
conservador; deallocations externas podem esconder crescimento, por isso reversão
bloqueia e ainda assim não elimina esse risco. Não há garantia de geração fresca.
Rollback futuro: desabilitar explicitamente o modo/adapters e restaurar policy,
source e bindings consistentes de backup revisado; reconciliar tentativa antes
de qualquer restauração de estado. Nunca apagar evidência/consumo ou reautorizar.
Stage03H rollback: nenhum canônico foi alterado; manter o pacote como evidência.
