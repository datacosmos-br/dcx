# Guia Definitivo: Como Plugar Tecnologias e Fazer Funcionar no Ecossistema Datacosmos

> **Objetivo:** Manual prático de engenharia para criar, categorizar, plugar e consumir novas tecnologias e regras de negócio sem acoplamento e sem retrabalho.  
> **Público:** Desenvolvedores de plataforma e engenheiros de soluções de clientes.

---

## 1. Padrões Semânticos Fundamentais

Antes de escrever qualquer código, todo módulo no ecossistema Datacosmos deve seguir 5 padrões semânticos obrigatórios:

### 1.1 Linguagem Ubíqua de Negócio (DDD) vs. Jargão Técnico
- **Proibido nas Portas:** Nomes que vazem implementação ou protocolos externos (ex: `execute_sql_query`, `http_post_json`, `rclone_copy_file`).
- **Obrigatório nas Portas:** Termos semânticos do problema que está sendo resolvido (ex: `find_unreconciled_sales`, `persist_audit_batch`, `dispatch_divergence_alert`).

### 1.2 Tipagem Estrutural Pura (PEP 544 Protocols - `p.Port`)
- Dependências entre camadas são declaradas **exclusivamente por interfaces estruturais (`typing.Protocol`)** herdando de `p.Base`.
- Nenhuma classe de caso de uso pode tipar um argumento de construtor com uma classe concreta de driver (como `cx_Oracle.Connection` ou `requests.Session`).

### 1.3 Railway Oriented Programming (`r.Result[T]`)
- **Proibido:** Lançar exceções não tratadas para controle de fluxo ou engolir erros com blocos vazios de `except Exception: pass`.
- **Obrigatório:** Retornar `r.Result[T]`, onde o sucesso transporta `r.success(payload)` e a falha transporta `r.failure(domain_error)` com código semântico rastreável.

### 1.4 Modelos de Dados Puros e Declarativos (`m.Model`)
- Classes que herdam de `m.BaseModel` (Pydantic v2) são **esquemas de dados puros**.
- **Regra:** Zero métodos de regras de negócio dentro de classes em `m`. Toda mutação ou cálculo vive em serviços (`s`) ou utilitários puros (`u`).

### 1.5 Self-Only Deltas (ADR-024)
- Um projeto ou plugin declara **apenas fatos sobre si mesmo** em sua configuração (`plugin.yaml` ou `pyproject.toml`).
- É proibido um plugin tentar configurar caminhos ou parâmetros de outros módulos do sistema.

---

## 2. As 8 Áreas Arquiteturais do Ecossistema

O ecossistema é organizado em **8 Áreas Estruturadas**:

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

---

## 3. Passo a Passo: Como Criar e Plugar uma Nova Tecnologia

Vamos seguir um tutorial prático completo criando um conector para a **Área 4 (Storage)** capaz de salvar dados em formato Parquet no Google Drive e torná-lo imediatamente utilizável pelo projeto do cliente **`gruponos`**.

### Passo 1: Definir o Manifesto do Plugin no DCX (`plugin.yaml`)
Crie o arquivo de manifesto na tecnologia:
`plugins/storage/tech-storage/plugin.yaml`:

```yaml
schema_version: "1.0"
name: "tech-storage"
version: "1.0.0"
category: "storage-lake"
description: "Motor de armazenamento colunar Parquet Snappy e sincronização com Google Drive via Rclone"

requirements:
  binaries:
    - name: "rclone"
      version: ">=1.60.0"
      provider: "dcx-tools"
  vault_secrets:
    - alias: "gdrive_credentials"
      description: "Tokens de acesso ao Google Drive corporativo"

commands:
  - name: "sync-drive"
    description: "Sincroniza diretório local com pasta remota no Google Drive"
    entrypoint: "scripts/sync_gdrive.sh"

lifecycle:
  preflight: "scripts/preflight_check.sh"
```

---

### Passo 2: Definir os Protocolos da Tecnologia (`protocols.py`)
No código Python do conector (`tech_storage/protocols.py`):

```python
from typing import Protocol, runtime_checkable
from flext_core import r, p, t

@runtime_checkable
class ObjectStoragePort(p.Base, Protocol):
    """Porta técnica de armazenamento de objetos e arquivos colunares."""
    def save_parquet(self, remote_path: str, data: list[t.JsonMapping]) -> r.Result[str]:
        """Serializa em Parquet Snappy e envia para o storage remoto via streaming."""
        ...
```

---

### Passo 3: Implementar o Adaptador Concreto (`adapter.py`)
No adaptador da tecnologia (`tech_storage/adapters/parquet_rclone_adapter.py`):

```python
import io
import pyarrow as pa
import pyarrow.parquet as pq
from flext_core import r, t
from tech_storage.protocols import ObjectStoragePort

class ParquetRcloneAdapter(ObjectStoragePort):
    def __init__(self, rclone_remote: str):
        self._remote = rclone_remote

    def save_parquet(self, remote_path: str, data: list[t.JsonMapping]) -> r.Result[str]:
        if not data:
            return r.failure("Dados vazios para geração de Parquet")
        
        try:
            # 1. Serializa em memória com compressão Snappy via Apache Arrow
            table = pa.Table.from_pylist(data)
            buf = io.BytesIO()
            pq.write_table(table, buf, compression="snappy")
            buf.seek(0)

            # 2. Upload seguro usando streaming sem gravar arquivos temporários no disco
            full_remote_uri = f"{self._remote}:{remote_path}"
            # (Executa streaming seguro via DCX / Rclone)
            
            return r.success(full_remote_uri)
        except Exception as e:
            return r.failure(f"Falha na serialização/upload Parquet: {e}")
```

---

### Passo 4: O Cliente Declara sua Porta Semântica de Negócio (`gruponos`)
Agora vamos para a **Camada 3 (Negócio)** no repositório `gruponos`.  
O Grupo Nós precisa auditar vendas diárias. Ele **não sabe** o que é PyArrow, nem Rclone, nem flags de sistema.

Ele define sua porta de negócio pura:
`gruponos/ports/audit_port.py`:

```python
from typing import Protocol
from flext_core import r, p
from gruponos.domain.models import AuditBatch

class AuditStoragePort(p.Base, Protocol):
    """Porta de domínio para gravação de relatórios de auditoria contábil."""
    def record_audit(self, batch: AuditBatch) -> r.Result[str]:
        ...
```

---

### Passo 5: Criar o Adaptador Fino no Cliente conectando com a Tecnologia
`gruponos/adapters/storage_adapter.py`:

```python
from flext_core import r
from gruponos.ports.audit_port import AuditStoragePort
from gruponos.domain.models import AuditBatch
from tech_storage.protocols import ObjectStoragePort

class GruponosAuditStorageAdapter(AuditStoragePort):
    def __init__(self, storage_engine: ObjectStoragePort):
        self._storage = storage_engine

    def record_audit(self, batch: AuditBatch) -> r.Result[str]:
        # Converte a entidade de domínio do Grupo Nós para o formato de persistência
        payload = batch.to_audit_records()
        remote_path = f"Datacosmos/GrupoNos/Auditoria/{batch.station_id}/{batch.date}.snappy.parquet"
        return self._storage.save_parquet(remote_path, payload)
```

---

### Passo 6: Composition Root — Plugar Tudo via Injeção de Dependência (`api.py`)
No ponto de composição da aplicação (`gruponos/api.py`):

```python
from flext_core import FlextContainer
from tech_storage.adapters.parquet_rclone_adapter import ParquetRcloneAdapter
from tech_storage.protocols import ObjectStoragePort
from gruponos.ports.audit_port import AuditStoragePort
from gruponos.adapters.storage_adapter import GruponosAuditStorageAdapter
from gruponos.domain.services.audit_service import AuditReconciliationService

class GruponosApi:
    @classmethod
    def build_audit_service(cls) -> AuditReconciliationService:
        container = FlextContainer()

        # 1. Registra a Tecnologia Compartilhada (Camada 2)
        storage_engine = ParquetRcloneAdapter(rclone_remote="gdrive")
        container.add_service(ObjectStoragePort, storage_engine)

        # 2. Registra o Adaptador de Domínio do Grupo Nós (Camada 3)
        audit_adapter = GruponosAuditStorageAdapter(storage_engine=storage_engine)
        container.add_service(AuditStoragePort, audit_adapter)

        # 3. Constrói o Caso de Uso injetando as portas
        return AuditReconciliationService(
            audit_port=container.require(AuditStoragePort)
        )
```

---

### Passo 7: Como Fazer Funcionar via CLI com o Kernel DCX

O caso de uso agora pode ser executado diretamente pelo terminal através do roteador nativo do **DCX**:

```bash
# Execução transparente orquestrada pelo Kernel DCX
dcx run gruponos audit --date 2026-01-31 --station-id 104
```

**O que o DCX faz nos bastidores:**
1. Valida se o binário `rclone` e o runtime Python estão presentes (`tools.yaml`).
2. Verifica se a credencial `gdrive_credentials` está desbloqueada no cofre (`dcx cred`).
3. Invoca o serviço do Grupo Nós com as credenciais injetadas em memória.
4. O serviço processa as regras de negócio, serializa em Parquet, envia para o Google Drive e retorna código de saída `0` com mensagem de sucesso estruturada em JSON.

---

## 4. Resumo de Diretrizes Invioláveis

1. **A tecnologia nunca sabe quem é o cliente:** O `tech-storage` ou o `flext-db-oracle` não possuem imports ou referências a `gruponos`.
2. **O cliente nunca sabe qual driver físico está gravando:** O `gruponos` fala apenas com `AuditStoragePort`. Se amanhã o armazenamento mudar do Google Drive para o AWS S3 ou MinIO local, **zero linhas de regras de negócio do Grupo Nós serão alteradas**.
3. **Cofre Único e Seguro:** Nenhuma chave de API ou senha é colocada em código fonte ou em `.env` plain-text. Tudo passa pelo cofre encriptado `dcx cred` (AES-256 PBKDF2).
4. **Testes Instantâneos:** Para testar a regra do `AuditReconciliationService`, basta passar uma classe `FakeAuditStoragePort` que guarda os dados em uma lista na memória RAM. O teste roda em 2 milissegundos.
