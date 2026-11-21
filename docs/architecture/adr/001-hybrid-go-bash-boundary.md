# 001. Limite e Fronteira Híbrida Go/Bash

## Status
Aceito (2026-11-04)

## Contexto
O DCX é construído sobre uma arquitetura híbrida:
1. Um binário em Go (`cmd/dcx/`) para desempenho, distribuição única e gerenciamento de ferramentas/configurações.
2. Um ecossistema de bibliotecas e plugins em Bash (`lib/*.sh`, `plugins/`) para automações corporativas rápidas e integração com o sistema operacional.

Historicamente, algumas pontes entre o Go e os scripts shell foram feitas por interpolação de strings em comandos do tipo `exec.Command("bash", "-c", fmt.Sprintf(...))`, o que introduziu riscos de segurança (como a RCE apontada no bead `dcx-nes.3`).

## Decisão
1. **Passagem de Parâmetros Segura**: Toda invocação de rotinas em Bash a partir do Go DEVE utilizar argumentos posicionais do array de execução (`exec.Command("bash", "-c", script, arg0, arg1, ...)`), garantindo que dados de entrada do usuário nunca sejam interpolados diretamente na string do script.
2. **Separação de Responsabilidades**:
   - **Go**: Validação estrita de entrada, descompressão com cotas, checagem de hashes, orquestração de alto nível.
   - **Bash**: Interações com ferramentas de banco de dados, variáveis de ambiente e plugins dinâmicos.
3. **Padrão Flext de Facades**: As bibliotecas em Bash devem expor funções públicas padronizadas e previsíveis (`core_*`, `cred_*`, `log_*`, `parallel_*`), sem efeitos colaterais ao serem carregadas via `source`.

## Consequências
- Eliminação total de superfícies de injeção de comando shell (Command Injection).
- Código auditável e aderente às regras de segurança corporativas do Datacosmos.
