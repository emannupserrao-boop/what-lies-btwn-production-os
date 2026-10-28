# Stage03E — integração futura do snapshot, somente proposta

Este changeset **não foi aplicado**. Estado atual: STAGED_NOT_ACTIVATED;
NEXT_GATE = WAITING_HUMAN_REVIEW. A autorização Stage03E cobriu somente a cópia
e verificação. Nenhuma alteração abaixo autoriza startup, imports ou jobs.

Evidência candidata a integrar:
`D:\WHAT-LIES-BTWN-PRODUCTION-OS\tests\stage03e\evidence\actual-snapshot-inventory.csv`,
SHA-256 `a7019b00d50a866729ebfc7806f91e7495bd69561783694bfff5198ffb35a8df`.
Snapshot: `D:\WHAT-LIES-BTWN-PRODUCTION-OS\runtimes\core\ComfyUI`,
619 arquivos / 9.533.695 bytes. Rehash obrigatório em qualquer revisão futura;
este pin não é uma aprovação nem uma prova de compatibilidade.

| Arquivo candidato | SHA-256 atual preservado | Alteração que exigiria autorização/revisão futura |
| --- | --- | --- |
| policy\startup-identity.json | 7f42355c74483f6965f6eb6e837b5ac09d71485fcde610882bc627c3dd420edb | Representar snapshot preparado, com caminho/pin do inventário efetivo e estado explícito sem ativação; preservar limitações de identidade Python/dependências e nenhuma autoridade |
| core\Wlb.Startup.ps1 | 1fffe9825cb7d7044e4e8e0dd2431aa9df559fec450c356e69538859cdd3825d | Revisar contrato estrito que aceita snapshot NOT_CREATED/exists=false; distinguir bytes verificados de runtime compatível e consentimento, recusando campos/estados inesperados |
| core\Start-WlbRuntime.ps1 | 3ed6a6cea5f1602bc47f95ffc4b031a102b12f9fdfe3f204b259ff9dfc6b9e26 | Se integrar leitura do inventário, verificar fontes/cópia/pins atuais e manter o entry point incapaz de iniciar processo; não aceitar exists=true isoladamente como prontidão |
| policy\runtime-lock.json | 2cba41ae01245961e941edb9d1f5ce016b773d6a7d99236d5e71c1b2f4727a98 | Atualizar somente vínculos legitimamente afetados e explicitar proveniência da integração revisada; manter performance/runtime/security NOT_VERIFIED e ausência de aprovação |
| manifests\draft\POC0-CALIBRATION-001.json | 349503c85cde19f23558f4dcecdaf4192dfea9cef52e19aa264cdf36fe5eeebb | Atualizar exclusivamente o binding de runtime-lock se necessário, sem promoção DRAFT ou habilitação de execução |

Os hashes posteriores são **NOT_DEFINED_PENDING_HUMAN_REVIEW**, pois não existe
implementação autorizada desse próximo changeset. A política startup-policy.json,
executor-policy.json e launcher de jobs permanecem bloqueados; parâmetros humanos
continuam UNKNOWN/null. Não há proposta de aumentar os budgets existentes.

Antes dessa integração, revisar fechamento de configuração/licença/imports.
alembic.ini está fora da allowlist atual, assim como outros non-Python assets não
aprovados; eventual inclusão exige decisão humana distinta, revisão concreta de
arquivos e pins e uma nova autorização de cópia. Não adicionar arquivos por heurística.
Também continuam pendentes interpretador/stdlib/DLLs e metadados versus binários/ABI.

Consentimento específico, parâmetros humanos e os adaptadores operacionais de
propriedade/porta/recursos/start/stop/watchdog pertencem a trabalho futuro autorizado.
Integridade e integração de uma cópia não concedem G4/G5. Não iniciar esse trabalho
automaticamente.
