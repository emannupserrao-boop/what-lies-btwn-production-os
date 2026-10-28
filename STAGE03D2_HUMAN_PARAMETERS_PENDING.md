# Stage03D2 — parâmetros humanos pendentes

Somente proposta para revisão. Nenhuma opção abaixo foi vinculada à política operacional.
G2/G3/G4/G5/ALPHA, startup real e jobs permanecem fechados. A escolha
`SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0` já está estabelecida e não é perguntada novamente.

Os campos exatos estão em `policy\startup-policy.json.human_parameters`:

| Campo | Estado atual | Proposta conservadora | Impacto e aprovação necessária |
| --- | --- | --- | --- |
| operator_identity.status / value | UNKNOWN / null | Confirmar conta técnica e SID do operador | Conta observada por leitura: WORKSTATION\user; SID S-1-5-21-REDACTED. É um candidato técnico, não identificação humana inferida, assinatura nem autenticação independente. Requer confirmação e autorização humana explícita para vinculação |
| cpu_budget.status / value | UNKNOWN / null | Opção recomendada: manter bloqueante até definir orçamento a partir de medição autorizada. Alternativa para revisão: observação de CPU sem cap percentual apenas no startup supervisionado, mantendo deadline de 120 s | Não há medidas de custo/peaks CPU deste runtime. Nenhum teto numérico é inventado. A alternativa observacional não limita CPU e só poderia ser vinculada mediante aceitação humana expressa dessa limitação |
| polling_cadence_ms.status / value | UNKNOWN / null | Candidato A: 250 ms; candidato B: 500 ms | A faz até quatro avaliações/s; B até duas/s. Menor intervalo reduz atraso de detecção programado, aumenta leituras/overhead; custo do sampler real ainda não foi medido. Não são garantias de scheduling ou hard caps |
| telemetry_freshness_ms.status / value | UNKNOWN / null | Com A, idade máxima candidata 1000 ms; com B, 2000 ms | Rejeita dados mais antigos; idade tolerada maior amplia janela sem evidência atual. Esses pares são propostas, não medições nem autorização; overhead, latência e atribuição deverão ser verificados em um scope distinto |

Os valores 100 ms / 500 ms e `OBSERVE_ONLY_TEST` presentes nos mocks são exclusivamente
valores de teste com status `INJECTED_TEST_ONLY`; não são recomendações adotadas nem
parâmetros operacionais. A política real continua com quatro valores null/UNKNOWN.

Nenhuma identidade textual será tratada como consentimento G4. O futuro consentimento deve
ser uma ação específica do operador supervisionado, vinculada aos bytes revisados, ao
startup único e à autoridade de parada do próprio processo. O adaptador desse consentimento
não existe nesta fase; nenhum registro real foi criado ou consumido.

Antes de uma futura vinculação, solicitar autorização explícita para cada campo/valor e
revisar o contrato que atualmente aceita somente parâmetros pendentes na política real.
Mesmo essa vinculação não autoriza snapshot, imports, server startup, G4 ou jobs.

NEXT_GATE = WAITING_HUMAN_REVIEW. Nenhuma política operacional foi definida por inferência.
