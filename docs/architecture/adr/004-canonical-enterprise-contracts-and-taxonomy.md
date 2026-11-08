# 004. Contratos Canônicos, Semântica e Taxonomia Corporativa

## Status
Aceito (2026-11-04)

## Contexto
O DCX evoluiu de um script utilitário para o **Kernel de Execução e Host de Control Plane** da Datacosmos. Projetos clientes de alta relevância (como `gruponos`, `algar` e `raizen`) consomem dados e serviços através do DCX e do framework de integração `flext`.

Para evitar dispersão técnica ("colcha de retalhos"), acoplamento indevido e complexidade acidental nas camadas de negócio, é necessário formalizar:
1. Uma **taxonomia de mercado** unificada para as capacidades técnicas (alinhada aos padrões CNCF, DDD e Hexagonal Architecture).
2. A **semântica estrita dos contratos** de plugins, segurança de credenciais e integridade de binários.
3. A garantia de que as camadas superiores (projetos clientes) operem com esforço cognitivo mínimo, delegando todo o trabalho de infraestrutura para o DCX e os adaptadores tecnológicos.

## Decisão

1. **Taxonomia de Mercado das Capacidades Tecnológicas**:
   Adota-se a classificação corporativa em 5 planos:
   - `rdbms-oracle`: Enterprise Relational Plane (Oracle, Wallets, sqld360, AWR, RMAN).
   - `storage-lake`: Data Lake & Object Storage Plane (Rclone, Google Drive, S3, Parquet Snappy).
   - `olap-clickhouse`: Analytical Fast Ingestion Plane (ClickHouse).
   - `gitops-infra`: Platform Delivery & GitOps Plane (Kubernetes, ArgoCD, OCI, Helm).
   - `work-management`: Enterprise Work Tracking Plane (Jira Cloud REST v3).

2. **Contrato de Manifesto de Plugin (`plugin.yaml`)**:
   Todo plugin tecnológico deve possuir schema versão 1.0 declarando `name`, `version`, `category`, `requirements` (binários validados e segredos do cofre), `commands` e `lifecycle` (hooks de `preflight`, `healthcheck`, `teardown`).

3. **Inversão de Dependências (DIP) e Redução de Complexidade nos Clientes**:
   - O projeto cliente define suas regras de negócio em termos de entidades e portas abstratas (`p.Port`).
   - O cliente **não instancia drivers de banco, nem gerencia senhas, nem manipula comandos de sistema diretamente**.
   - O DCX e os adaptadores de tecnologia resolvem todo o ecossistema de runtime, injetando as implementações concretas na Composition Root do projeto.

4. **Hermeticidade e Segurança Zero Trust**:
   - Segredos descriptografados (`dcx cred`) existem apenas em memória e são repassados por canais seguros (pipes ou argumentos posicionais isolados).
   - Binários declarados em `etc/tools.yaml` possuem checksum SHA256 estrito por arquitetura e teto de extração (`io.CopyN`) para prevenção de ataques como Zip Bomb.

## Consequências

- **Positivas:**
  - Padronização no estado da arte da engenharia corporativa.
  - Redução drástica da complexidade nos projetos clientes (código limpo, expressivo e 100% testável em memória).
  - Eliminação de retrabalho e código duplicado entre equipes.
  - Conformidade estrita com os princípios Clean Architecture, SOLID, DRY, SSOT e YAGNI.

- **Negativas/Atenções:**
  - Exige que plugins legados ou dispersos (`~/oracle_scripts`, `~/legado`) sejam ajustados ao manifesto formal `plugin.yaml`.
