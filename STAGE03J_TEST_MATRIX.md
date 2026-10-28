# Stage03J — matriz de testes e avaliação

Resultado selecionado: **137 PASS / 1 FAIL**, 138 verificações distintas. O FAIL é a avaliação real de RAM disponível abaixo de 8 GiB. Não é removido da matriz nem convertido em aprovação.

Seleção: checks03-checks.json (115); guard02-checks.json (9); audit02-integrity-checks.json (14, sendo 13 PASS e 1 FAIL). As provas reais de processo vêm de run06. Após a guarda final de recursos, não houve novo startup de helper: somente recusa real anterior à criação e regressões sem criação de processos.

REAL_OWNED_PROCESS = processos benignos criados pela própria tentativa e avaliados em relógio real. REAL_DENIAL_ON_OWNED_HELPER = operação de parada negada sobre helper real por evidência divergente; nenhuma aplicação externa foi usada como alvo. SIMULATED_* = bytes, mensagens ou relógios injetados; nenhuma medição de ComfyUI ou G4. RELEVANT_REGRESSION = validadores e gates fechados. STORED_STAGE03J_FAILURE = existência de evidência preservada, sem transformar a tentativa falha em execução aprovada. FINAL_INTEGRITY = comparação de conteúdo e avaliação discreta de recursos.

O caso de helper estrangeiro usa um helper real que pertence a uma tentativa diferente da tentativa chamadora. Reutilização de PID é simulada por creation time divergente no tuple de um helper real. A falha controlada usa saída 23; não simula a física de um crash nativo ou de um comando NVIDIA travado.

Os 198 PASS do Stage03I são históricos e não entram neste total. checks01 (113 PASS/2 FAIL) e checks02 (115 PASS/0 FAIL) são preservados, mas não somados novamente. A auditoria anterior final-integrity-checks.json também preserva o mesmo bloqueio de RAM. run01–run05 permanecem como evidências de desenvolvimento, incluindo falhas e correções.

## Verificações selecionadas

| # | Verificação | Evidência | Resultado |
|---|---|---|---|
| 1 | normal-passive-separate-pid | REAL_OWNED_PROCESS | PASS |
| 2 | normal-passive-clock-proof | REAL_OWNED_PROCESS | PASS |
| 3 | normal-passive-bounded-monotonic-ticks | REAL_OWNED_PROCESS | PASS |
| 4 | normal-passive-reconciled-exit | REAL_OWNED_PROCESS | PASS |
| 5 | normal-passive-worker-or-channel-terminal | REAL_OWNED_PROCESS | PASS |
| 6 | finite-delay-and-denials-separate-pid | REAL_OWNED_PROCESS | PASS |
| 7 | finite-delay-and-denials-clock-proof | REAL_OWNED_PROCESS | PASS |
| 8 | finite-delay-and-denials-bounded-monotonic-ticks | REAL_OWNED_PROCESS | PASS |
| 9 | finite-delay-and-denials-reconciled-exit | REAL_OWNED_PROCESS | PASS |
| 10 | finite-delay-and-denials-worker-or-channel-terminal | REAL_OWNED_PROCESS | PASS |
| 11 | hang-short-timeout-separate-pid | REAL_OWNED_PROCESS | PASS |
| 12 | hang-short-timeout-clock-proof | REAL_OWNED_PROCESS | PASS |
| 13 | hang-short-timeout-bounded-monotonic-ticks | REAL_OWNED_PROCESS | PASS |
| 14 | hang-short-timeout-reconciled-exit | REAL_OWNED_PROCESS | PASS |
| 15 | hang-short-timeout-worker-or-channel-terminal | REAL_OWNED_PROCESS | PASS |
| 16 | controlled-failure-separate-pid | REAL_OWNED_PROCESS | PASS |
| 17 | controlled-failure-clock-proof | REAL_OWNED_PROCESS | PASS |
| 18 | controlled-failure-bounded-monotonic-ticks | REAL_OWNED_PROCESS | PASS |
| 19 | controlled-failure-reconciled-exit | REAL_OWNED_PROCESS | PASS |
| 20 | controlled-failure-worker-or-channel-terminal | REAL_OWNED_PROCESS | PASS |
| 21 | heartbeat-interruption-separate-pid | REAL_OWNED_PROCESS | PASS |
| 22 | heartbeat-interruption-clock-proof | REAL_OWNED_PROCESS | PASS |
| 23 | heartbeat-interruption-bounded-monotonic-ticks | REAL_OWNED_PROCESS | PASS |
| 24 | heartbeat-interruption-reconciled-exit | REAL_OWNED_PROCESS | PASS |
| 25 | heartbeat-interruption-worker-or-channel-terminal | REAL_OWNED_PROCESS | PASS |
| 26 | channel-closed-separate-pid | REAL_OWNED_PROCESS | PASS |
| 27 | channel-closed-clock-proof | REAL_OWNED_PROCESS | PASS |
| 28 | channel-closed-bounded-monotonic-ticks | REAL_OWNED_PROCESS | PASS |
| 29 | channel-closed-reconciled-exit | REAL_OWNED_PROCESS | PASS |
| 30 | channel-closed-worker-or-channel-terminal | REAL_OWNED_PROCESS | PASS |
| 31 | normal-exit0-live-minimal-sample | REAL_OWNED_PROCESS | PASS |
| 32 | live-provider-generation-remains-unknown | REAL_OWNED_PROCESS | PASS |
| 33 | finite-exit0-without-termination | REAL_OWNED_PROCESS | PASS |
| 34 | actual-denial-1 | REAL_DENIAL_ON_OWNED_HELPER | PASS |
| 35 | actual-denial-2 | REAL_DENIAL_ON_OWNED_HELPER | PASS |
| 36 | actual-denial-3 | REAL_DENIAL_ON_OWNED_HELPER | PASS |
| 37 | actual-denial-4 | REAL_DENIAL_ON_OWNED_HELPER | PASS |
| 38 | actual-denial-5 | REAL_DENIAL_ON_OWNED_HELPER | PASS |
| 39 | actual-denial-6 | REAL_DENIAL_ON_OWNED_HELPER | PASS |
| 40 | actual-denial-7 | REAL_DENIAL_ON_OWNED_HELPER | PASS |
| 41 | actual-denial-8 | REAL_DENIAL_ON_OWNED_HELPER | PASS |
| 42 | real-short-deadline-before-hang-completion | REAL_OWNED_PROCESS | PASS |
| 43 | real-heartbeat-loss-before-worker-completion | REAL_OWNED_PROCESS | PASS |
| 44 | controlled-crash-exit23-without-kill | REAL_OWNED_PROCESS | PASS |
| 45 | real-channel-loss-owned-termination | REAL_OWNED_PROCESS | PASS |
| 46 | partial-attempts-preserved-not-final-passes | STORED_STAGE03J_FAILURE | PASS |
| 47 | sim-valid-sample-original-acquisition | SIMULATED_IPC | PASS |
| 48 | wrong-attempt | SIMULATED_IPC | PASS |
| 49 | wrong-nonce | SIMULATED_IPC | PASS |
| 50 | wrong-worker | SIMULATED_IPC | PASS |
| 51 | duplicate-sequence | SIMULATED_IPC | PASS |
| 52 | out-of-order-sequence | SIMULATED_IPC | PASS |
| 53 | sequence-string | SIMULATED_IPC | PASS |
| 54 | future-message | SIMULATED_IPC | PASS |
| 55 | reversed-message | SIMULATED_IPC | PASS |
| 56 | worker-clock-changed | SIMULATED_IPC | PASS |
| 57 | sample-before-clock-negotiation | SIMULATED_IPC | PASS |
| 58 | envelope-clock-changed | SIMULATED_IPC | PASS |
| 59 | provider-verification-forged | SIMULATED_IPC | PASS |
| 60 | simulated-as-live | SIMULATED_IPC | PASS |
| 61 | future-collection | SIMULATED_IPC | PASS |
| 62 | collection-after-production | SIMULATED_IPC | PASS |
| 63 | fast-before-request | SIMULATED_IPC | PASS |
| 64 | envelope-sequence-gap | SIMULATED_IPC | PASS |
| 65 | slow-sequence-gap | SIMULATED_IPC | PASS |
| 66 | unexpected-wire-property | SIMULATED_IPC | PASS |
| 67 | unexpected-envelope-property | SIMULATED_IPC | PASS |
| 68 | wrong-kind | SIMULATED_IPC | PASS |
| 69 | payload-clock-mismatch | SIMULATED_IPC | PASS |
| 70 | payload-generation-age-fabricated | SIMULATED_IPC | PASS |
| 71 | payload-authority-forged | SIMULATED_IPC | PASS |
| 72 | mailbox-second-sample-rejected | SIMULATED_IPC | PASS |
| 73 | slow-cache-timestamp-rewritten | SIMULATED_IPC | PASS |
| 74 | fast-clock-reversed | SIMULATED_IPC | PASS |
| 75 | cached-slow-age-retained | SIMULATED_IPC | PASS |
| 76 | json-reject-323026429 | SIMULATED_IPC | PASS |
| 77 | json-reject--1745896836 | SIMULATED_IPC | PASS |
| 78 | json-reject--1756430535 | SIMULATED_IPC | PASS |
| 79 | json-reject-1138147638 | SIMULATED_IPC | PASS |
| 80 | framing-valid-roundtrip | SIMULATED_BYTES | PASS |
| 81 | framing-truncated-header | SIMULATED_BYTES | PASS |
| 82 | framing-truncated-body | SIMULATED_BYTES | PASS |
| 83 | framing-empty-body | SIMULATED_BYTES | PASS |
| 84 | framing-zero-length | SIMULATED_BYTES | PASS |
| 85 | framing-oversized-header | SIMULATED_BYTES | PASS |
| 86 | framing-invalid-utf8 | SIMULATED_BYTES | PASS |
| 87 | framing-eof | SIMULATED_BYTES | PASS |
| 88 | framing-write-size-bound | SIMULATED_BYTES | PASS |
| 89 | framing-read-one-leaves-next-pending | SIMULATED_BYTES | PASS |
| 90 | clock-proof-valid-independent-session | SIMULATED_CLOCK | PASS |
| 91 | clock-frequency-mismatch | SIMULATED_CLOCK | PASS |
| 92 | clock-epoch-before-parent | SIMULATED_CLOCK | PASS |
| 93 | clock-epoch-after-parent | SIMULATED_CLOCK | PASS |
| 94 | clock-reversed-child | SIMULATED_CLOCK | PASS |
| 95 | clock-challenge-mismatch | SIMULATED_CLOCK | PASS |
| 96 | clock-session-mismatch | SIMULATED_CLOCK | PASS |
| 97 | clock-roundtrip-over500ms | SIMULATED_CLOCK | PASS |
| 98 | clock-1tick-cross-thread-tolerance | SIMULATED_CLOCK | PASS |
| 99 | injected-deadline-exact120s | SIMULATED_CLOCK | PASS |
| 100 | injected-short-timeout-keeps-g4-budget | SIMULATED_CLOCK | PASS |
| 101 | heartbeat-does-not-renew-consumed-acquisition | SIMULATED_IPC | PASS |
| 102 | supervisor-clock-reversal-terminal | SIMULATED_CLOCK | PASS |
| 103 | terminal-latched-no-retry | SIMULATED_IPC | PASS |
| 104 | simulated-lease-cannot-stop | SIMULATED_LIFECYCLE | PASS |
| 105 | invalid-launch-mode-refused-before-create | SIMULATED_LIFECYCLE | PASS |
| 106 | 21-prepared-pins-match | RELEVANT_REGRESSION | PASS |
| 107 | four-human-parameters-still-unknown-null | RELEVANT_REGRESSION | PASS |
| 108 | policy-gates-false-and-consent-absent | RELEVANT_REGRESSION | PASS |
| 109 | static-review-pass-not-executable | RELEVANT_REGRESSION | PASS |
| 110 | execution-eligibility-refused | RELEVANT_REGRESSION | PASS |
| 111 | g4-plan-snapshot619-staged-not-started | RELEVANT_REGRESSION | PASS |
| 112 | g4-admission-refused | RELEVANT_REGRESSION | PASS |
| 113 | g5-empty-approval-refused-no-record | RELEVANT_REGRESSION | PASS |
| 114 | unchanged-eight-resource-budget-values | RELEVANT_REGRESSION | PASS |
| 115 | new-process-components-not-in-g4-entrypoint | RELEVANT_REGRESSION | PASS |
| 116 | resource-exact8-and10-admits-only-benign-test | SIMULATED_RESOURCE_GUARD | PASS |
| 117 | resource-one-byte-below8-refused | SIMULATED_RESOURCE_GUARD | PASS |
| 118 | resource-one-byte-below10-refused | SIMULATED_RESOURCE_GUARD | PASS |
| 119 | resource-unavailable-refused | SIMULATED_RESOURCE_GUARD | PASS |
| 120 | resource-malformed-type-refused | SIMULATED_RESOURCE_GUARD | PASS |
| 121 | resource-inconsistent-commit-refused | SIMULATED_RESOURCE_GUARD | PASS |
| 122 | resource-negative-refused | SIMULATED_RESOURCE_GUARD | PASS |
| 123 | live-low-ram-create-refused-without-lease | REAL_CURRENT_HOST_CREATE_REFUSAL | PASS |
| 124 | resource-refusal-latched-no-restart | REAL_CURRENT_HOST_CREATE_REFUSAL | PASS |
| 125 | baseline3387-only-three-documented-changes | FINAL_INTEGRITY | PASS |
| 126 | exact-three-rollback-backups | FINAL_INTEGRITY | PASS |
| 127 | runtime-lock-only-prepared-pins-changed | FINAL_INTEGRITY | PASS |
| 128 | 19-to21-prepared-map-exact | FINAL_INTEGRITY | PASS |
| 129 | draft-only64char-lock-sha-replacement | FINAL_INTEGRITY | PASS |
| 130 | validator-only-two-allowlist-paths-added | FINAL_INTEGRITY | PASS |
| 131 | new-files-stay-in-approved-stageJ-scope | FINAL_INTEGRITY | PASS |
| 132 | no-new-approval-records | FINAL_INTEGRITY | PASS |
| 133 | all-recorded-owned-helper-handles-proved-exited | FINAL_INTEGRITY | PASS |
| 134 | final-six-attempts-zero-harness-failure | FINAL_INTEGRITY | PASS |
| 135 | owned-stop-request-latched-once | FINAL_INTEGRITY | PASS |
| 136 | stageJ-created-file-footprint-below256MiB | FINAL_INTEGRITY | PASS |
| 137 | current-stageJ-source-syntax-valid | FINAL_INTEGRITY | PASS |
| 138 | observed-minimal-helper-resource-readings-within-budgets | FINAL_INTEGRITY | FAIL |

## Critérios não satisfeitos ou não verificados

- RAM disponível >=8 GiB: FAIL, mínimo observado 4,75 GiB; recusa final demonstrada.
- Startup de helper executado sob a guarda final com recursos elegíveis: NOT_RUN_RESOURCE_BLOCKED.
- Interrupção contínua por orçamento de RAM/commit/private/disk: NOT_VERIFIED; a guarda final é admissão pontual.
- Watchdog operacional de ComfyUI por 120 segundos: NOT_RUN_NOT_AUTHORIZED.
- GPU residency RTX atribuída ao PID, idade de geração do provider e exclusividade de atores: NOT_VERIFIED.
- Compatibilidade Python/ComfyUI, G4/G5, Alpha Gen e MCP: NOT_RUN_NOT_AUTHORIZED.