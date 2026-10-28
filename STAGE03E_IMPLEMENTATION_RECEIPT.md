# WHAT LIES BTWN — STAGE03E_IMPLEMENTATION_RECEIPT

## A. STAGE03E_STATUS

COMPLETE_WITH_LIMITATIONS. Snapshot de conteúdo copiado e verificado: STAGED_NOT_ACTIVATED. Apenas preparação de código, sem autoridade de execução. G2/G3/G4/G5/ALPHA fechados. Os resultados PASS desta entrega significam exclusivamente integridade de bytes, tamanho, allowlist e identidade/caminhos observados; não representam imports, startup, GPU ou funcionamento do ComfyUI.

## B. EXACT_SOURCE_INVENTORY_VERIFICATION

Origem fixa: D:\Musicas\Bitter-End-Visual-Local\ComfyUI. Destino fixo: D:\WHAT-LIES-BTWN-PRODUCTION-OS\runtimes\core\ComfyUI. CSV original preservado como única allowlist, SHA-256 a8e69c205a7f98a1aa3bb34d399201a61e76c112c233f7202abc8b25ba2941eb. Validadas todas as 619 linhas, 619 origens e destinos únicos, 9.533.695 bytes, 11 grupos. Nenhuma expansão, lista substituta, download ou seleção automática.

Pins adicionais conferidos integralmente: G4_DEPENDENCY_METADATA.json 97710ef8f044f13c1eb2c570ba188a697ce301c17aa871ef573a0afbbaabe901; startup-identity.json 7f42355c74483f6965f6eb6e837b5ac09d71485fcde610882bc627c3dd420edb; startup-policy.json e1db244a744f6ee228956d7fdd199c89737822299bab7785b58ba8c9e527795f. Os oito inputs autoritativos foram lidos e analisados integralmente; CSV e JSON de dependências processados em todas as linhas/entradas. Recibo D2 preservado: b19aed5ac764b6d5acd7543d46033fe358d2f4eb15d684ddf2e9f545ec8db5ac. Baseline completo: 2.269 arquivos, zero divergências antes da cópia e zero alterações depois.

Preflight antes da criação do destino: arquivos presentes/legíveis, caminhos canônicos sob raízes fixas, tamanhos e hashes exatos, reparse/junction/symlink recusados, hardlink count=1, diretórios ancestrais validados e retidos por handles sem delete sharing, destino ausente. Todos os 619 handles de origem permaneceram abertos com FileShare.Read, negando escrita/exclusão convencional durante a tentativa. Espaço disponível e margem conservadora de conteúdo + 64 MiB registrados em precopy-verification.json; nenhuma política de recurso foi alterada. ValidateOnly passou sem criar destino/reserva; a cópia teve uma única tentativa.

| Grupo | Arquivos | Bytes |
|---|---:|---:|
| alembic_db | 9 | 44114 |
| api_server | 7 | 6328 |
| app | 43 | 390713 |
| comfy | 322 | 5505691 |
| comfy_api | 39 | 309571 |
| comfy_config | 2 | 9046 |
| comfy_execution | 10 | 101273 |
| comfy_extras | 166 | 2813213 |
| middleware | 2 | 1792 |
| root-startup-and-provenance | 14 | 346667 |
| utils | 5 | 5287 |

## C. COPY_EXECUTION_RECEIPT

Tentativa 9cce62dc-89f8-4f12-9683-0be7682db2ca. Início UTC 2026-10-13T16:50:38.5151040Z; fim UTC 2026-10-13T16:51:36.8771752Z. O diretório do snapshot estava ausente. Mutex local dedicado à cópia e reserva persistente tests/stage03e/evidence/snapshot-reservation.json, criada com CreateNew, excluem outra tentativa deste procedimento; reserva não é aprovação nem consentimento G4/G5. Diretórios novos criados por CreateDirectoryW com erro se preexistentes, pais retidos e rechecados; somente diretórios derivados dos destinos aprovados. Nenhum link criado. Arquivos escritos exclusivamente via FileMode.CreateNew, escritor exclusivo, CopyTo a partir do handle validado, Flush(true), hash de saída e identidade por volume/file index. Cada fonte rechecada antes/depois da respectiva cópia; todas rechecadas ao final por handle retido e novo handle de caminho.

copy-execution-ledger.json registra os 619 pares, hashes, tamanhos, identidades de origem/destino e flush. copy-outcome.json registra tentativa, horários, diretórios criados e estado. Nenhuma falha ocorreu na tentativa. Código possui parada conservadora sem retry/overwrite/cleanup: falhas ficam PARTIAL_BLOCKED, com arquivos criados e cópias verificadas registrados, e reserva mantida. Caminhos de falha/interrupção/power loss não foram injetados nesta etapa; não se afirma prova dessas condições. O script de cópia não deve ser reexecutado contra o destino/reserva existente.

## D. ACTUAL_SNAPSHOT_INVENTORY_AND_SHA256

Inventário efetivo independente da listagem de cópia: D:\WHAT-LIES-BTWN-PRODUCTION-OS\tests\stage03e\evidence\actual-snapshot-inventory.csv. Obtido por enumeração real do destino após a cópia, novos handles de leitura, comparação de identidade com a criação, tamanho/hash e comparação com a allowlist. SHA-256: a7019b00d50a866729ebfc7806f91e7495bd69561783694bfff5198ffb35a8df. Exatamente 619 arquivos e 9.533.695 bytes. Zero arquivos adicionais e nenhum diretório fora dos pais necessários da allowlist; nenhum .git, peso, custom node, cache ou conteúdo do usuário acrescentado. Logs/recibos/reserva ficam fora do snapshot.

Uma segunda verificação, em invocação PowerShell distinta após liberação dos handles da cópia, reabriu fontes e destino: 619 verificações de origem + 619 de destino, identidades/caminhos/hardlinks/bytes/hashes iguais. Evidências: independent-integrity-checks.csv e independent-verification-summary.json. Nenhum arquivo .py/.pyi foi executado/importado. O inventário efetivo inclui identidade local NTFS, portanto seu hash não é uma assinatura universal de distribuição nem autoridade de runtime.

## E. SOURCE_AND_DESTINATION_INTEGRITY

Os 619 conteúdos de origem preservados em tamanho/hash e identidade observada; source-before.json/source-after.json registram os pares. Os 2.269 arquivos preexistentes do Production OS preservados byte a byte; não houve changeset canônico nesta etapa. Evidências históricas C/D1/D2 intactas. Os 48 arquivos METADATA/WHEEL/RECORD das 16 dependências foram somente lidos/rehashados e permanecem iguais aos pins.

| Arquivo canônico preservado | SHA-256 antes = depois |
|---|---|
| policy\startup-identity.json | 7f42355c74483f6965f6eb6e837b5ac09d71485fcde610882bc627c3dd420edb |
| policy\startup-policy.json | e1db244a744f6ee228956d7fdd199c89737822299bab7785b58ba8c9e527795f |
| policy\runtime-lock.json | 2cba41ae01245961e941edb9d1f5ce016b773d6a7d99236d5e71c1b2f4727a98 |
| policy\executor-policy.json | 2782c8aed1b02b959b6efb13eb4244a7e871d3bb8b279c554a0ddbceb22baf31 |
| manifests\draft\POC0-CALIBRATION-001.json | 349503c85cde19f23558f4dcecdaf4192dfea9cef52e19aa264cdf36fe5eeebb |
| core\Invoke-WlbJob.ps1 | 2278e14b700fe722c5ca6d7e2d6e2245c3b88b1288fdee006da2cdd415a5fe66 |

LIMITAÇÕES: identidades por volume/file index e checks representam observações do filesystem Windows durante os handles e a auditoria; file IDs podem ser reutilizados posteriormente e não são autenticação independente. Handles/ACLs herdadas não criam sandbox, isolamento forte ou proteção contra quem pode modificar código/política sob a mesma conta. Nenhuma ACL foi modificada; cópia cria arquivos novos com permissões herdadas, sem clonar permissões/metadata de produção. Flush(true) solicita persistência; falha elétrica/hardware não foi testada. Depois da liberação dos handles o conteúdo pode ser alterado por alguém autorizado no host; futura integração deve revalidar tudo. Leituras podem afetar metadados de acesso geridos pelo sistema; a preservação atestada é de conteúdo/tamanho/identidade observada, não de todo atributo/timestamp do host.

## F. LICENSE_AND_DEPENDENCY_LIMITATIONS

LICENSE foi copiado sem alteração: 35.823 bytes, SHA-256 230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809. A leitura integral do texto é preservada no arquivo; cabeçalho GNU GPL Version 3 e referência license.file=LICENSE em pyproject são evidências locais. Nenhuma conclusão jurídica de distribuição, auditoria per-file ou resolução de exceções foi realizada. pyproject.toml (2.092 bytes) e requirements.txt (557 bytes) estão explicitamente incluídos, com hashes do CSV; não são instalação/configuração do ambiente.

| Distribuição | Versão declarada em METADATA | Estado |
|---|---|---|
| torch | 2.14.1+cu130 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| torchaudio | 2.11.0+cu130 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| torchvision | 0.29.1+cu130 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| transformers | 5.18.0 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| numpy | 2.5.2 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| pillow | 12.3.0 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| safetensors | 0.8.0 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| aiohttp | 3.14.3 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| yarl | 1.25.1 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| pyyaml | 6.0.3 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| psutil | 7.2.2 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| comfy_aimdo | 0.5.5 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| comfy_kitchen | 0.2.36 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| comfyui_frontend_package | 1.53.10 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| alembic | 1.20.0 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |
| sqlalchemy | 2.1.1 | STATIC_METADATA_ONLY / RUNTIME_NOT_VERIFIED |

As versões acima são declarações dos metadados, não imports nem verificação de binários/ABI. RECORD foi hashado como texto, não usado para certificar todos os binários listados. Os 16 pacotes não constituem fechamento completo das dependências declaradas ou dos imports; requirements também cita, por exemplo, workflow templates, embedded docs, torchsde, einops, tokenizers, sentencepiece, scipy, tqdm, av, requests e outras dependências. Nenhum pacote foi instalado/resolvido. Python/Torch/torchaudio/torchvision/CUDA/frontend/bibliotecas nativas permanecem RUNTIME_NOT_VERIFIED; o pin histórico da entrada Python em startup-identity não foi transformado em validação de interpretador/stdlib/DLLs.

## G. EXCLUDED_FILES_AND_UNRESOLVED_IMPORTS

Apenas os 619 arquivos do CSV foram copiados. Exclusões por ausência na allowlist: root models/pesos/checkpoints, custom_nodes, comfy_api_nodes/providers, .git, credenciais, caches, input/output/user/temp, ambiente Python e dados/configs/assets não aprovados. Diretórios nested comfy/ldm/models e comfy_api/input contêm Python aprovado; não são pesos nem dados de entrada. Outros exemplos/módulos explicitamente no CSV foram mantidos exatamente, sem seleção por nome. 616 arquivos .py/.pyi e três arquivos de proveniência/configuração declarativa (LICENSE, pyproject.toml, requirements.txt).

alembic.ini existe na origem (3.314 bytes), mas NÃO consta do CSV e NÃO foi copiado. app/database/db.py linhas 73–80 constrói caminho para esse arquivo e Config(config_path); o fechamento de configuração/migrações permanece pendente. Não se infere startup viável sem esse arquivo, nem falha necessariamente em todos os modos. pyproject referencia README.md, que não integra esta cópia; não houve instalação do pacote. Outros non-Python data/assets, frontend e efeitos de inicialização/imports permanecem não demonstrados. Qualquer necessidade de acrescentar arquivo requer revisão humana da allowlist em escopo distinto; não há correção automática de configuração/runtime.

## H. G4_READINESS_AND_REMAINING_BLOCKERS

A integridade desta cópia está verificada; G4 continua BLOCKED / NOT_AUTHORIZED. STAGED_NOT_ACTIVATED é evidência separada; startup-identity.snapshot.status=NOT_CREATED, exists=false e actual_inventory_sha256=null e runtime-lock.snapshot_created=false foram preservados intencionalmente como contrato canônico anterior não ativado. Essa diferença exige revisão futura explícita, não ajuste silencioso para aparentar prontidão.

Changeset candidato do próximo gate, NÃO aplicado: STAGE03E_NEXT_GATE_CHANGESET_PROPOSAL.md lista os cinco arquivos candidatos com SHA-256 atual e mudanças dependentes de revisão. Revisar a completude/necessidade de alembic.ini/non-code/license notices; integrar o inventário efetivo em startup-identity; revisar validação de identidade que atualmente exige NOT_CREATED/exists=false; atualizar somente bindings legitimamente afetados em runtime-lock e manifesto sem promover DRAFT; manter execução desabilitada até consentimento e controle operacional aprovados. Revisar candidato Python/stdlib/DLLs e dependências nativas. Não aumentar a allowlist ou copiar configurações nesta entrega.

Demais bloqueios: identidade humana/CPU budget/polling/freshness UNKNOWN; consentimento confiável específico de startup ausente; protocolo single-attempt/recovery, observadores reais de PID/creation time/executable/porta, start/stop exclusivo do processo próprio, exclusão real do executor, telemetria operacional RAM/commit/private/VRAM/GPU/disk, watchdog/deadline e validação supervisionada real não implementados/verificados. Limites 8/10/4/4/2 GiB, 120 s/30 s e 256 MiB preservados; thresholds não são hard caps. SUPERVISED_SAME_WINDOWS_ACCOUNT_POC0 não demonstra isolamento OS/egress/REST; flags offline/loopback não bloqueiam todos os acessos. As 24 pendências operacionais anteriores continuam pendentes.

## I. G5_STATUS

NOT_AUTHORIZED. execution_enabled=false; gpu_jobs_enabled=false; real_startup_enabled=false; consent_status=ABSENT; manifesto DRAFT; launcher original byte-idêntico com recusa incondicional. Não houve G4, approval real, consumo de approval, POST/submissão HTTP, job GPU, cancelamento ou geração. Aprovação/consumo atômico/replay/submissão/monitoramento de job/outputs permanecem bloqueios futuros. G2/G3/ALPHA igualmente fechados.

## J. NO_OUT_OF_SCOPE_MUTATION_ATTESTATION

Alterações realizadas: criação dos 619 arquivos aprovados no snapshot, diretórios pais necessários e arquivos novos de procedimento/evidência/relatório Stage03E dentro do Production OS. Zero alterações dos 2.269 arquivos anteriores; nenhuma fonte ou ambiente de produção alterado. Inventário de novos artefatos: tests/stage03e/evidence/stage03e-new-files.csv, com hashes; dois arquivos de metadados auto-referentes excluídos e explicados em delivery-integrity.json. Todas as fontes inspecionadas e metadados das dependências rechecados. Nenhum arquivo externo à allowlist no snapshot.

PowerShell/.NET e helpers Windows locais fizeram somente validação/IO de cópia/relatórios; Add-Type compilou helpers fixos em memória do processo, sem instalação ou execução de conteúdo ComfyUI/Python. Nenhum Python/import/CUDA, servidor, GPU, API externa/REST, download, instalação, produção MIRAE/PULSE/LTX, aprovação G4/G5, alteração ACL/firewall/registro/serviços/global environment ou operação Git commit/merge/push/tag. Não houve encerramento de processo. Não se afirma auditoria omnisciente de todo o host: preservação externa cobre os 619 arquivos envolvidos e os 48 metadados lidos. Direitos de host e escopo supervisionado não foram ampliados.

## K. NEXT_GATE

WAITING_HUMAN_REVIEW. STOP_AFTER_DELIVERY. Snapshot STAGED_NOT_ACTIVATED; não prosseguir automaticamente a integração, imports, startup, G4/G5, Alpha Gen ou MCP. Uma cópia íntegra não é autorização ou prova de compatibilidade operacional.
