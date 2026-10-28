# Provider freshness e supervisor — proposta Stage03H

PROPOSED_ONLY. Não há worker, watchdog operacional, cancelamento ou stop novo.

| Conceito | Contrato proposto |
| --- | --- |
| Receipt age | supervisor_now - aquisição original; inclui collection duration; candidato <=2000 ms |
| Collection duration | fim - início da chamada em domínio monotônico validado; não mede cache/provider age |
| Provider generation age | timestamp/semântica do valor produzido; UNKNOWN para NVIDIA/WDDM nesta evidência |
| Deadline startup | supervisor_now - startup_started >=120000 ms bloqueia; independente do sampler |
| Watchdog responsiveness | loop independente; nenhuma query síncrona no supervisor; bound real ainda não demonstrado |

## Arquitetura mínima candidata

Supervisor único mantém relógio monotônico, deadline absoluto, policy/hash
bindings, tuple própria do runtime e sequência. Nenhuma NVIDIA/CIM/native/disk
call bloqueante roda nesse loop. Recebe envelope pequeno imutável de worker
isolado por processo futuro; handshake vincula worker/attempt nonce, source pins,
clock domain e request ID. Same-account boundary já selecionado: isso não é
autenticação independente nem sandbox.

Mailbox com capacidade 1, tamanho máximo explícito a definir e validar antes de
implementação; queue overflow/out-of-order/duplicate/replay bloqueiam. Worker tem
no máximo uma solicitação pendente por coletor; não acumular workers/requests ao
travar. Envelope conserva aquisição original por componente, end/duration, source,
generation_age_status, actor identity e flags available/inconsistent/cache.
Supervisor marca o instante de emissão do request e recebimento no seu relógio;
usa o request original como bound conservador de aquisição. Cache não usa request
novo como aquisição de valor antigo. Não comparar ClockId de processos distintos
sem protocolo explícito; IDs Stage03G são locais por module-load.

Rápidos candidatos: RAM/commit + own PID/private/CPU + porta a cada 500 ms.
Lentos candidatos: GPU/actors/disk a cada 1000 ms, com acquisition-age por campo
e deadline de receipt 2000 ms. Nenhuma cadência foi vinculada. Atores novos podem
aparecer entre consultas; não apresentar 1000 ms como cobertura contínua. Disco
tem cap256 MiB; lentidão/picos entre leituras continuam risco, exigindo destino
escopado e futura escrita contada/bounded. O collector atual hardcode Stage03G
evidence; futuro scope deve representar o run aprovado, sem excluir output/log/temp.

Cold warm-up e baseline são fases anteriores ao startup. Publicar só amostra
completa disponível; baseline não é coletado enquanto o primeiro worker ainda
compila/enumeration. O prazo 120 s inicia no attempt dispatch de runtime futuro;
readiness não prorroga o prazo. Sincronização/validação de clocks, envelope, IPC,
identity e scheduler sob carga precisam testes antes de qualquer operação.

## Falhas e responsabilidades

Sampler failed: bloqueio imediato ao evento. Hung/unresponsive: supervisor
continua observando sua fila não bloqueante e bloqueia quando idade de aquisição
excede2000 ms; não fica aguardando query. Deadline bloqueia mesmo com dados frescos.
Não aceitar heartbeat sem métricas como freshness e não reiniciar sampler/runtime
automaticamente. Gate BLOCKED não é, sozinho, prova de que runtime parou.

O código atual usa CLI NVIDIA síncrona e CIM OperationTimeoutSec=2. Uma chamada
finita sem retry não é hard timeout. H observou timeout no provider RAM raw e
WDDM process probe cold467 ms; uma query lenta real pode demorar mais. Runspace/
Task timeout apenas na espera pode deixar chamada/thread nativa rodando; não
tratar abandono de await como cancelamento comprovado. Um worker por processo
limita propagação do bloqueio, mas precisa lifecycle validado e cleanup bounded.

Cancelamento/cooperative shutdown/terminação de query worker ou subprocesso
NVIDIA próprio são changeset futuro. Exigem autorização separada para criar e
modificar/encerrar exclusivamente helpers da tentativa, tuple+handles+creation,
rechecks, teste de PID recycling, nenhum stop por nome nem parada de WmiPrvSE
compartilhado. Não foram implementados nesta etapa. Não há Process.Kill novo.
Definir escalonamento/cleanup timeout antes da implementação, sem inventar agora
um hard bound garantido. Runtime stop é outro adapter e autoridade distinta.

## Simulação e evidência

Test-ReviewDesign.ps1 exercita estado independentemente de chamada de sampler:
hung/mock sem invocação, stale no primeiro tick sintético2020 ms (quantum20 ms),
sampler failed, deadline120000, cache com timestamp antigo, sequence/queue/clock.
20 ms não é parâmetro operacional nem latência real medida. Não houve teste real
de subprocesso pendurado, concorrência IPC, jitter sob startup, stop ou 120 s.
O experimento split Stage03H é sequencial em um observador: mede custo possível,
não demonstra esta arquitetura não bloqueante.
