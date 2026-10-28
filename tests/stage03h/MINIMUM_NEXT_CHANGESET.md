# Minimum next changeset — proposta, zero implementação canônica Stage03H

O próximo passo mínimo é preparação de supervisor e contratos ainda desabilitados.
Nenhuma revisão deste pacote ou decisão de parâmetros concede G4. Não há pedido
automático de G4, geração de aprovação ou reserva nova.

| Ordem/gate | Entrega/dependência | Permissão futura necessária | Aceitação | Rollback |
| --- | --- | --- | --- | --- |
| H-REVIEW | Revisar resultados/risco global/receipt proxy; boundary permanece selecionado | Decisão humana de design; nenhuma execução | Registrar decisões explícitas e itens pendentes | Manter UNKNOWN/null, mode disabled |
| PREP-ONLY | Separar sampler/supervisor; envelopes/clock/cache; hooks simulados; guards fail-closed | Autorizar changeset canônico delimitado, apenas preparação | Fixtures hung/stale/replay/PID/actor/caps/120s; G4/G5 ainda recusados; source pins coerentes | Backup/hash antes; restaurar sources+lock+manifest juntos, preservar evidências |
| HELPER-LIFECYCLE-TEST | IPC/worker próprio, timeout e cleanup validado sob carga | Autorização separada para iniciar/parar apenas helpers isolados identificados, sem Python/GPU | Hung query não prende supervisor, bounded queue, no orphan/new helper retry, foreign PID intocado | Parar somente helper próprio autorizado; outcome unknown exige reconcile |
| PARAMS/PROXY-REVIEW | Binding dos quatro valores e, separadamente, decisão sobre GPU global/provider proxy | Autorizar edição policy+validadores/hash bindings depois de revisão de valores finais | Só valores/status explícitos revisados; caps8/10/4/4/2 e120s intactos; modo só G4 sem modelos | Desabilitar/restaurar configuração e bindings; não preservar enabled inadvertidamente |
| RUNTIME-IDENTITY | Resolver effective Python/stdlib/DLL/assets/native dependency identity e caminho de configuração | Escopo separado para qualquer Python/import/compatibility test, sem instalação implícita | Evidência reproduzível compatível com binaries/args/env pins; sem claims de sandbox | Voltar NOT_VERIFIED; não modificar venv/Comfy/LTX |
| G4-SPECIFIC-HUMAN | Consentimento one-attempt confiável após todos os gates anteriores e preflight imediato | Autorização humana específica de startup model-free, own stop, loopback/paths aprovados | RAM>=8/headroom>=10, actors revisados sem desconhecidos, monitor operacional, exact own lifecycle, timeout e no retry | Aborto/cleanup só próprio conforme consentimento; unknown=reconcile sem retry |
| G5-SEPARATE | G4 comprovado; consent/submission/output/QC exclusivos do job | Outra autorização; jamais derivada de G4/proxy | Engine/REST/replay/30s/QC operacionais | Nunca ressubmeter outcome desconhecido |

## Arquivos candidatos para PREP-ONLY

- core\Wlb.Supervisor.ps1 (novo, proposto): estado/relógio/envelope e interfaces
  desabilitadas. Nenhuma conexão automática com launcher durante preparação.
- core\Wlb.RuntimeMonitor.ps1: separar coletores e budgets de aquisição, registrar
  source-age UNKNOWN, actor inventory/diffs, DXGI descriptor mapping como metadata;
  não promover accounting a RTX PID residency. Eventual proxy evaluator em branch
  explícita desabilitada, apenas após decisão humana específica.
- core\Wlb.Startup.ps1: contracts para parâmetros futuros/status revisados e
  admission strict; hoje exige UNKNOWN/null. Não basta editar JSON: validator
  precisaria mudança revisada para aceitar novos valores sem relaxar caps/consent.
- core\Start-WlbRuntime.ps1: permanece Plan/Admission estático nesse changeset
  mínimo; adapter de real start/stop só em escopo futuro de lifecycle autorizado.
- policy\runtime-lock.json e manifests\draft\POC0-CALIBRATION-001.json:
  pins exatos de sources finais; DRAFT, execution=false e approval ausente.
- tests em novo namespace: fixtures clock/envelope/cache/actors/negative source
  shape e provas de recusa. Não reusar namespaces de evidência anteriores.

policy\startup-policy.json só deve mudar em gate PARAMS/PROXY explicitamente
autorizado. startup-identity/snapshot619, Invoke-WlbJob/executor, MIRAE/PULSE/LTX,
pacotes, ACL/firewall/serviços ficam fora da preparação mínima. Se algum precisar
mudar, apresentar diff concreto sob outro escopo antes de executar.

## Propostas de valores, sem binding

operator_identity: confirmar WORKSTATION\user e SID
S-1-5-21-REDACTED. cpu_budget: OBSERVE_ONLY para
startup G4, sem teto percentual e com deadline120 s. polling_cadence_ms:500 ms
candidato, slow refresh1000 ms é política de scheduler proposta distinta.
telemetry_freshness_ms:2000 ms candidato de receipt/acquisition proxy, não provider
generation age. SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0 preservado.

No estado atual os quatro continuam UNKNOWN/null; consent ABSENT; startup/jobs
false. Proposta não contém approval ID nem autorização antecipada.
