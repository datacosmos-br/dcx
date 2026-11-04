# Arquitetura Canônica do DCX: Kernel, Contratos e Taxonomia Corporativa

> **Status:** Normativo e Canônico  
> **Versão:** 1.0.0  
> **Padrões de Mercado:** Platform Engineering (CNCF), Clean Architecture & Hexagonal (Ports & Adapters), Domain-Driven Design (DDD), 12-Factor App, Zero Trust Security  
> **Repositório:** `datacosmos-br/dcx`

---

## 1. Visão Geral e Papel do DCX

O **DCX** é o **Kernel de Execução e Host de Control Plane** da Datacosmos. Construído em Go nativo, estaticamente compilado e sem dependências externas de runtime, ele provê a fundação sobre a qual os conectores de dados (como o **FLEXT**) e as aplicações de negócio de clientes (como o **Grupo Nós**, **Algar** e **Raízen**) operam de forma segura, determinística e desacoplada.

```
┌────────────────────────────────────────────────────────────────────────┐
│              BUSINESS DOMAIN PLANE (Projetos & Clientes)               │
│               • gruponos  • algar  • raizen  • dc-recon                │
│                                                                        │
│   Casos de Uso (CQRS), Entidades de Domínio, Portas Semânticas (p.Port)│
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Injeção de Dependências (Pure DI)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│             DATA FABRIC & INTEGRATION PLANE (Tecnologias)              │
│       • flext-db-oracle  • flext-meltano (Singer/dbt)  • tech-storage  │
│                                                                        │
│   Adaptadores Tecnológicos Secundários, Pipelines ELT, Conectores      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Sustentação de Runtime
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│               CONTROL PLANE & RUNTIME KERNEL (DCX em Go)               │
│                                                                        │
│   1. Process Supervisor & CLI Router (execução isolada e segura)       │
│   2. Secret Management Vault (AES-256-GCM / PBKDF2 em memória)         │
│   3. Hermetic Toolchain Manager (tools.yaml + SHA256 validation)       │
│   4. Plugin & Capability Fabric (plugin.yaml + lifecycle preflight)    │
│   5. Health & Preflight Inspection (dcx validate)                      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Taxonomia de Mercado das Capacidades Tecnológicas

Para evitar sobreposição e colcha de retalhos, todos os plugins e capacidades tecnológicas são agrupados estritamente pelas categorias de mercado:

| Categoria CNCF / Mercado | Identificador | Tecnologias Encapsuladas | Contratos Fornecidos aos Projetos |
|---|---|---|---|
| **Enterprise RDBMS & Relational Plane** | `rdbms-oracle` | `flext-db-oracle`, `sqld360`, AWR, RMAN, Wallets | • Conexão e pooling gerenciados.<br>• Diagnóstico e otimização de plano de execução.<br>• Backup e restore determinístico. |
| **Data Lake & Object Storage Plane** | `storage-lake` | Rclone, Google Drive (`gdrive:`), S3, Apache Arrow, Parquet Snappy | • Streaming de upload/download de objetos.<br>• Serialização colunar compactada Snappy.<br>• Auditoria de integridade com SHA256. |
| **High-Throughput Analytical OLAP** | `olap-clickhouse` | Driver ClickHouse, Ingestion Pipelines | • Ingestão massiva em lotes (micro-batches).<br>• Consultas agregadas de tempo real. |
| **Platform Delivery & GitOps Plane** | `gitops-infra` | Kubernetes API, ArgoCD REST, OCI CLI, Helm | • Sincronização de estado desejado de clusters.<br>• Execução de jobs efêmeros e cronjobs. |
| **Work Management & Collaboration** | `work-management` | Jira Cloud REST v3, Confluence | • Transição automatizada de épicos e tarefas.<br>• Rastreabilidade de commits e evidências. |

---

## 3. Especificação Semântica dos Contratos do DCX

### 3.1 Contrato de Manifesto de Plugin (`plugin.yaml`)
Todo plugin tecnológico que se integra ao DCX deve implementar o manifesto declarativo canônico:

```yaml
schema_version: "1.0"
name: "tech-oracle"
version: "1.2.0"
category: "rdbms-oracle"
description: "Motor corporativo de conexão, diagnóstico e automação Oracle para o ecossistema Datacosmos"

# Requisitos de sistema validados antes de qualquer execução
requirements:
  binaries:
    - name: "sqlplus"
      version: ">=19.0.0"
      optional: true
    - name: "yq"
      version: ">=4.0.0"
      provider: "dcx-tools"
  vault_secrets:
    - alias: "oracle_credentials"
      description: "Credenciais de conexão com o banco de dados Oracle"

# Comandos expostos para os projetos clientes
commands:
  - name: "sqld360"
    description: "Executa diagnóstico profundo de performance SQL usando SQLd360"
    entrypoint: "scripts/run_sqld360.sh"
    preflight: "scripts/check_oracle_env.sh"
  - name: "restore-monitor"
    description: "Monitora restauração RMAN em tempo real"
    entrypoint: "scripts/monitor_restore.sh"

# Hooks de Ciclo de Vida do Plugin
lifecycle:
  preflight: "scripts/preflight.sh"
  healthcheck: "scripts/healthcheck.sh"
  teardown: "scripts/teardown.sh"
```

### 3.2 Contrato de Segurança de Segredos (`dcx cred` - Secret Management)
Seguindo o padrão **Zero Trust** e **12-Factor App**:
1. **Algoritmo de Criptografia:** AES-256-GCM com chave derivada via PBKDF2 (100.000 iterações com SHA-256 e salt criptográfico).
2. **Ciclo de Vida em Memória:**
   - Segredos descriptografados **nunca tocam o disco**.
   - Proibição absoluta de exportação em arquivos `.env` em plain-text ou passagem via flags de linha de comando (`ps aux` visível).
   - Injeção em processos filhos via **Argumentos Posicionais Isolados** em Go (`exec.Command("bash", "-c", script, "_", secret)`) ou **Pipes Seguros de Memória** (`stdin` direto fechado após leitura).

### 3.3 Contrato de Toolchain Hermético (`etc/tools.yaml`)
O DCX garante que os nós de execução possuam ferramentas idênticas e auditadas:
- Cada ferramenta declara seu repositório de download e **checksum SHA-256 estrito por plataforma**.
- O extrator de arquivos implementa proteção contra **Zip Bomb** e **Tar Path Traversal** com teto de extração em bytes via `io.CopyN`.

---

## 4. O Fluxo de Consumo pelas Camadas Mais Altas (Projetos & Clientes)

Para reduzir a complexidade nas camadas mais altas:
1. **O Cliente não sabe detalhes de ferramentas:** O projeto `gruponos` apenas declara que necessita da capacidade `rdbms-oracle` e `storage-lake`.
2. **O DCX resolve o ambiente e a segurança:**
   ```bash
   # Execução orquestrada pelo DCX
   dcx run gruponos reconcile --data 2026-01-31
   ```
3. **O Runtime do DCX:**
   - Executa os preflight checks do plugin `tech-oracle` e do `gruponos`.
   - Recupera a credencial do cofre `dcx cred` de forma segura.
   - Fornece o contexto de execução limpo para o container DI do Python (`flext-core`).
   - O caso de uso do Grupo Nós executa sua regra pura, emitindo o resultado com sucesso e sem falhas silenciosas.

---

## 5. Matriz de Conformidade Arquitetural

| Princípio | Implementação no DCX | Verificação Decisiva |
|---|---|---|
| **Clean Architecture (CA)** | O Kernel DCX e as Tecnologias operam como adaptadores externos que satisfazem portas declaradas pelo domínio do cliente. | Ausência de imports de clientes dentro do Kernel e dos plugins. |
| **Dependency Injection (DI)** | As dependências de banco e storage são resolvidas na inicialização e passadas por injeção ao entrypoint. | Facilidade de substituir adaptadores por Fakes em testes unitários. |
| **SOLID (SRP & DIP)** | DCX cuida da máquina; Tecnologias cuidam de protocolos; Projetos cuidam de regras de negócio. | Cada módulo possui uma única razão para mudar. |
| **DRY** | Unificação de scripts de diagnóstico Oracle e storage em plugins reutilizáveis. | Zero duplicação de scripts shell de banco nos clientes. |
| **SSOT** | `tools.yaml` é a fonte da verdade para binários; `dcx cred` é a fonte única para credenciais. | Inexistência de senhas soltas no Git ou configs duplicadas. |
| **YAGNI** | Binários compactos, execução local e direta, sem camadas distribuídas pesadas sem necessidade. | Build estático Go de 15MB que sobe em 5 milissegundos. |
