# Arquitetura Canônica do DCX: Kernel, Contratos, Padrões Semânticos e Taxonomia

> **Status:** Normativo e Canônico  
> **Versão:** 1.0.0  
> **Padrões de Mercado:** Platform Engineering (CNCF), Clean Architecture & Hexagonal (Ports & Adapters), Domain-Driven Design (DDD), 12-Factor App, Zero Trust Security  
> **Repositório:** `datacosmos-br/dcx`  
> **Guia de Implementação Prática:** [docs/guides/plugging-and-extending-capabilities.md](../guides/plugging-and-extending-capabilities.md)

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

## 2. Padrões Semânticos Invioláveis

Todo código, contrato e manifesto no ecossistema Datacosmos deve seguir cinco padrões semânticos:

1. **Linguagem Ubíqua de Negócio (DDD):**
   As portas de domínio expõem intenção de negócio (`FuelMovementPort`, `AuditStoragePort`), **nunca** detalhes de tecnologia (`SqlExecutor`, `RcloneUploader`).
2. **Tipagem Estrutural Pura (`p.Port`):**
   Contratos são definidos via `typing.Protocol` herdando de `p.Base`. Casos de uso e serviços nunca dependem de classes concretas de drivers.
3. **Railway Oriented Programming (`r.Result[T]`):**
   Fluxo de controle baseado no monad Result. Sucesso (`r.success`) ou erro semântico tipado (`r.failure`). Exceções de runtime não vazam para fora da fronteira dos adaptadores.
4. **Modelos Declarativos Puros (`m.Model`):**
   Modelos Pydantic v2 contêm apenas definições de dados e validadores de campo nativos. **Zero lógica de negócio ou métodos mutadores** dentro de modelos em `m`.
5. **Self-Only Deltas (ADR-024):**
   Nenhum componente declara dados sobre outro repositório. O manifesto declara apenas suas próprias capacidades, dependências e comandos.

---

## 3. As 8 Áreas Arquiteturais do Ecossistema

Para garantir modularidade e evitar colcha de retalhos, todas as capacidades e soluções são alocadas em **8 Áreas Especializadas**:

```
┌─────────────────────────────────────────────────────────────────────────┐
│              ÁREA 8: BUSINESS DOMAINS & CLIENT SOLUTIONS                │
│       • gruponos (Combustíveis & DW)  • algar (Telecom)  • raizen       │
│       • dc-recon (Reconciliação)      • dcdoc (Docs)     • DataOP       │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ Consumo via Portas de Domínio (DI)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        ÁREAS DE TECNOLOGIA (MEIO)                       │
│                                                                         │
│  ÁREA 2: Data Integration & ELT (flext-meltano, Singer Taps/Targets)    │
│  ÁREA 3: Enterprise Database & Performance (flext-db-oracle, sqld360)   │
│  ÁREA 4: Object Storage & Columnar Lake (tech-storage, Parquet, GDrive) │
│  ÁREA 5: Analytical & Fast OLAP (tech-clickhouse)                       │
│  ÁREA 6: Platform Infrastructure & GitOps (tech-gitops, K8s, ArgoCD)    │
│  ÁREA 7: Enterprise Work Tracking & Agile (tech-jira REST v3)           │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ Sustentação de Runtime
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│             ÁREA 1: CORE RUNTIME & EXECUTION (KERNEL DCX)               │
│    • CLI Host Nativo (Go)              • Cofre AES-256 (dcx cred)       │
│    • Supervisor de Processos           • Toolchain Hermético tools.yaml │
│    • Preflight & Health Inspection     • Container DI (flext-core)      │
└─────────────────────────────────────────────────────────────────────────┘
```

| Área Arquitetural | Escopo | Componentes Principais | Contratos Providos |
|---|---|---|---|
| **Área 1: Core Runtime (Kernel)** | Fundação de Sistema | `dcx` (Go), `flext-core` | CLI runner, cofre AES-256 PBKDF2, `tools.yaml`, Result Monad, DI Container. |
| **Área 2: Data Integration (ELT)** | Extração e Carga | `flext-meltano`, `flext-tap-*`, `flext-target-*`, `flext-dbt-*` | Bases Singer Tap, Singer Target e modelos de transformação dbt. |
| **Área 3: Enterprise Database** | Banco Relacional | `flext-db-oracle`, `sqld360`, AWR, RMAN, Wallets | Pooling de conexão, tuning SQL, diagnósticos e automação RMAN. |
| **Área 4: Storage & Data Lake** | Armazenamento de Objetos | `tech-storage`, Rclone (`gdrive:`), S3, Apache Arrow, Parquet | Streaming de leitura/escrita Parquet Snappy, sync em nuvem. |
| **Área 5: Analytical OLAP** | Ingestão e Agregação | `tech-clickhouse` | Conector ClickHouse de alto throughput e consultas analíticas. |
| **Área 6: Platform & GitOps** | Infraestrutura | `tech-gitops`, Kubernetes API, ArgoCD, OCI CLI, Helm | Sincronização de manifests, jobs de cluster e gestão OCI. |
| **Área 7: Work Tracking** | Gestão de Tarefas | `tech-jira`, Jira REST v3, JQL | Transição de status, vínculo de épicos e extração de métricas. |
| **Área 8: Business Domains** | Regras de Clientes | `gruponos`, `algar`, `raizen`, `dc-recon`, `dcdoc` | Casos de uso de negócio, auditoria contábil, conciliação e relatórios. |

---

## 4. Especificação Semântica dos Contratos do DCX

### 4.1 Contrato de Manifesto de Plugin (`plugin.yaml`)
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

### 4.2 Contrato de Segurança de Segredos (`dcx cred` - Secret Management)
Seguindo o padrão **Zero Trust** e **12-Factor App**:
1. **Algoritmo de Criptografia:** AES-256-GCM com chave derivada via PBKDF2 (100.000 iterações com SHA-256 e salt criptográfico).
2. **Ciclo de Vida em Memória:**
   - Segredos descriptografados **nunca tocam o disco**.
   - Proibição absoluta de exportação em arquivos `.env` em plain-text ou passagem via flags de linha de comando (`ps aux` visível).
   - Injeção em processos filhos via **Argumentos Posicionais Isolados** em Go (`exec.Command("bash", "-c", script, "_", secret)`) ou **Pipes Seguros de Memória** (`stdin` direto fechado após leitura).

### 4.3 Contrato de Toolchain Hermético (`etc/tools.yaml`)
O DCX garante que os nós de execução possuam ferramentas idênticas e auditadas:
- Cada ferramenta declara seu repositório de download e **checksum SHA-256 estrito por plataforma**.
- O extrator de arquivos implementa proteção contra **Zip Bomb** e **Tar Path Traversal** com teto de extração em bytes via `io.CopyN`.

---

## 5. Como Plugar e Executar: O Fluxo de Consumo pelas Camadas Superiores

O guia passo a passo completo com código fonte encontra-se em:  
👉 **[Guia Prático: Como Plugar Tecnologias e Fazer Funcionar](../guides/plugging-and-extending-capabilities.md)**

Resumo do fluxo de 3 passos:
1. **Definição da Porta de Domínio no Cliente:** O cliente declara o que precisa via `typing.Protocol` sem menção a SQL ou Rclone.
2. **Implementação do Adaptador Fino:** O adaptador conecta a porta de domínio à tecnologia compartilhada (`flext-db-oracle` ou `tech-storage`).
3. **Injeção na Composition Root (`api.py`):** O container DI monta o grafo e expõe o caso de uso, executável via `dcx run <cliente> <comando>`.

---

## 6. Matriz de Conformidade Arquitetural

| Princípio | Implementação no DCX | Verificação Decisiva |
|---|---|---|
| **Clean Architecture (CA)** | O Kernel DCX e as Tecnologias operam como adaptadores externos que satisfazem portas declaradas pelo domínio do cliente. | Ausência de imports de clientes dentro do Kernel e dos plugins. |
| **Dependency Injection (DI)** | As dependências de banco e storage são resolvidas na inicialização e passadas por injeção ao entrypoint. | Facilidade de substituir adaptadores por Fakes em testes unitários. |
| **SOLID (SRP & DIP)** | DCX cuida da máquina; Tecnologias cuidam de protocolos; Projetos cuidam de regras de negócio. | Cada módulo possui uma única razão para mudar. |
| **DRY** | Unificação de scripts de diagnóstico Oracle e storage em plugins reutilizáveis. | Zero duplicação de scripts shell de banco nos clientes. |
| **SSOT** | `tools.yaml` é a fonte da verdade para binários; `dcx cred` é a fonte única para credenciais. | Inexistência de senhas soltas no Git ou configs duplicadas. |
| **YAGNI** | Binários compactos, execução local e direta, sem camadas distribuídas pesadas sem necessidade. | Build estático Go de 15MB que sobe em 5 milissegundos. |
