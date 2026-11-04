# 003. Contrato de Plugins e Manifesto Unificado

## Status
Aceito (2026-11-04)

## Contexto
O DCX suporta extensibilidade via plugins corporativos (ex: plugin Oracle, RMAN, Data Pump). Cada plugin precisa ser detectável, previsível e validado de forma estrita para evitar conflitos de versão e falhas silenciosas durante a execução.

Inspirado pelo padrão de plugins e habilidades do ecossistema Flext e `~/.agents`, o DCX adota um manifesto declarativo e checagens prévias de saúde (preflight checks).

## Decisão
1. **Manifesto `plugin.yaml` Obrigatório**: Cada plugin deve conter em sua raiz um manifesto declarativo com:
   - `name`: Nome do plugin em formato kebab-case.
   - `version`: Versionamento semântico (`X.Y.Z`).
   - `description`: Descrição do propósito do plugin.
   - `requires`: Dependências externas e binárias requeridas (ex: `gum`, `yq`, `sqlplus`).
   - `commands`: Lista de comandos exportados.
2. **Padrão de Inicialização Idempotente**: Todo script `init.sh` de plugin deve ser idempotente e não poluir namespaces globais sem prefixo.
3. **Preflight Healthcheck**: A execução de qualquer comando de plugin valida primeiro se os binários e variáveis essenciais estão disponíveis, falhando rápido com mensagem explicativa em vez de falhar no meio de uma transação crítica.

## Consequências
- Plugins desacoplados, testáveis de forma isolada e previsíveis em ambientes de produção.
- Conformidade com os padrões de arquitetura do `flext`.
