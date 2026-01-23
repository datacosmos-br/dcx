# RMAN State Tracking System

## Overview

O `restore.sh` implementa um sistema de state tracking que permite executar validações (DRY_RUN=1) e depois executar o restore real (DRY_RUN=0) sem re-executar as validações já completadas.

## Motivação

**Problema**: Ao executar um restore Oracle RMAN, as fases de preview e validate podem levar dezenas de minutos em bancos grandes. Se o usuário quer apenas validar antes de executar (DRY_RUN=1), não faz sentido re-executar preview/validate novamente quando rodar DRY_RUN=0.

**Solução**: State tracking persiste o estado de cada step executado em um arquivo. Quando DRY_RUN=0 é executado, o restore.sh detecta quais steps já foram completados e os pula automaticamente.

## Como Funciona

### Estado Persistente

O estado é salvo em: `${LOGDIR}/execution_state.sh`

**Exemplo de conteúdo:**
```bash
# RMAN Execution State - 2026-01-23
PREVIEW_COMPLETED="1"
PREVIEW_LOG="/tmp/restore_logs/03_preview.log"
PREVIEW_EXIT_CODE="0"
PREVIEW_DURATION="42"
PREVIEW_TIMESTAMP="1737654321"
VALIDATE_COMPLETED="1"
VALIDATE_LOG="/tmp/restore_logs/04_validate.log"
VALIDATE_EXIT_CODE="0"
VALIDATE_DURATION="68"
VALIDATE_TIMESTAMP="1737654389"
CROSSCHECK_TIMESTAMP="1737654123"
```

**Variáveis salvas por step:**
- `{STEP}_COMPLETED` - 1 se completou com sucesso, 0 se falhou
- `{STEP}_LOG` - Path do log file gerado
- `{STEP}_EXIT_CODE` - Exit code do comando (0 = sucesso)
- `{STEP}_DURATION` - Duração da execução em segundos
- `{STEP}_TIMESTAMP` - Unix timestamp da execução

### Fluxo de Execução

#### 1. DRY_RUN=1 (Validação)
```bash
DRY_RUN=1 ./restore.sh
```

**O que acontece:**
1. Executa Phase A (validation & discovery)
2. Executa Phase B (bootstrap & metadata)
3. Executa Phase C (catalog & preview)
4. Executa preview RMAN - **salva estado: PREVIEW_COMPLETED=1**
5. Executa validate RMAN - **salva estado: VALIDATE_COMPLETED=1**
6. **Para antes do restore** (exit com mensagem de sucesso)

**Estado salvo em:** `${LOGDIR}/execution_state.sh`

#### 2. DRY_RUN=0 (Execução)
```bash
DRY_RUN=0 ./restore.sh
```

**O que acontece:**
1. **Carrega estado** de `execution_state.sh`
2. Executa Phase A (validation & discovery)
3. Executa Phase B (bootstrap & metadata)
4. Executa Phase C (catalog & preview)
5. **Pula preview** (detecta PREVIEW_COMPLETED=1)
6. **Pula validate** (detecta VALIDATE_COMPLETED=1)
7. Executa restore (sempre - operação destrutiva)
8. Executa recover (sempre - operação destrutiva)
9. Abre o banco com RESETLOGS

**Mensagens de skip:**
```
[INFO] [SKIP] Restore Preview: Already completed (log: /tmp/.../03_preview.log)
[INFO] [SKIP] Restore Validate: Already completed (log: /tmp/.../04_validate.log)
```

### Detecção de Divergência

O sistema detecta se o catalog pode estar desatualizado:

1. **Crosscheck muito antigo** (>1 hora): oferece re-crosscheck
2. **Archivelogs novos no disco**: não detectados no catalog

**Exemplo de prompt:**
```
[INFO] Catalog may be stale. Re-run crosscheck? (YES/no)
```

**Behavior:**
- Primeira execução: sem state prévio, não oferece re-crosscheck
- Crosscheck recente (<1h): não oferece re-crosscheck
- Crosscheck antigo (>1h): oferece re-crosscheck com confirmação

## Funções Principais

### State Management

#### `_rman_state_file()`
Retorna o path do arquivo de estado.

```bash
local state_file
state_file=$(_rman_state_file)
# Retorna: ${LOGDIR}/execution_state.sh
```

#### `_rman_state_load()`
Carrega estado anterior.

```bash
if _rman_state_load; then
    echo "Estado carregado com sucesso"
else
    echo "Sem estado prévio (primeira execução)"
fi
```

**Retorna:**
- 0: Estado carregado com sucesso
- 1: Arquivo não existe (primeira execução)

#### `_rman_state_set(key, value)`
Salva valor no estado.

```bash
_rman_state_set "PREVIEW_COMPLETED" "1"
_rman_state_set "PREVIEW_LOG" "/tmp/preview.log"
```

**Comportamento:**
- Cria arquivo se não existir
- Remove chave antiga se já existir (evita duplicação)
- Adiciona nova linha com chave=valor

#### `_rman_state_get(key, default)`
Lê valor do estado.

```bash
local log_path
log_path=$(_rman_state_get "PREVIEW_LOG" "/tmp/default.log")
```

**Retorna:**
- Valor da chave se existir
- Default se não existir

#### `_rman_state_step_completed(step)`
Verifica se step completou com sucesso.

```bash
if _rman_state_step_completed "PREVIEW"; then
    echo "Preview já foi executado"
else
    echo "Preview precisa ser executado"
fi
```

**Retorna:**
- 0 (true): Step completou (STEP_COMPLETED=1)
- 1 (false): Step não completou ou nunca executou

### Execução Unificada

#### `oracle_rman_exec_with_state()`
Executa RMAN com state tracking.

**Signature:**
```bash
oracle_rman_exec_with_state "STEP_NAME" cmdfile logfile "description" [--skip-if-done] [--force]
```

**Arguments:**
- `STEP_NAME` - Nome do step (PREVIEW, VALIDATE, RESTORE, etc.)
- `cmdfile` - Path do arquivo de comando RMAN
- `logfile` - Path do arquivo de log
- `description` - Descrição legível
- `--skip-if-done` - Pula se já completado (padrão)
- `--force` - Força re-execução mesmo se completado

**Exemplo de uso:**
```bash
# Preview com skip automático
oracle_rman_exec_with_state "PREVIEW" "${RMAN_PRE}" "${LOGDIR}/03_preview.log" "Restore Preview"

# Restore sempre executa (--force)
oracle_rman_exec_with_state "RESTORE" "${RMAN_RES}" "${LOGDIR}/05_restore.log" "RESTORE DATABASE" --force
```

**Comportamento:**
1. Verifica se step já completou (skip automático, exceto se `--force`)
2. Mostra preview do comando
3. Pede confirmação (respeita `AUTO_YES`)
4. Executa comando RMAN
5. Atualiza estado no sucesso

**Atualização de estado:**
- Sucesso: `STEP_COMPLETED=1, EXIT_CODE=0`
- Falha: `STEP_COMPLETED=0, EXIT_CODE=<rc>`

### Divergência de Catalog

#### `oracle_rman_check_catalog_divergence()`
Verifica se catalog precisa refresh.

```bash
if ! oracle_rman_check_catalog_divergence; then
    echo "Catalog pode estar desatualizado"
fi
```

**Retorna:**
- 0: Catalog está atual
- 1: Divergência detectada (re-crosscheck recomendado)

**Checks:**
1. Primeira execução: retorna 0 (sem estado prévio para comparar)
2. Crosscheck recente (<1h): retorna 0
3. Crosscheck antigo (>1h): retorna 1
4. Mais archivelogs no disco que no catalog: retorna 1

## Edge Cases

### Estado Corrompido

**Sintaxe inválida em execution_state.sh:**

Comportamento:
- `_rman_state_load()` retorna 1
- Execução continua sem estado prévio
- Todos os steps são executados normalmente

**Recovery:**
```bash
rm -f ${LOGDIR}/execution_state.sh
# Próxima execução começa do zero
```

### Concorrência

**Duas execuções paralelas (mesma sessão):**

State file usa grep/mv atômico para updates:
```bash
grep -v "^${key}=" "${state_file}" > "${state_file}.tmp"
mv "${state_file}.tmp" "${state_file}"
echo "${key}=\"${value}\"" >> "${state_file}"
```

**Nota:** Concorrência real (2 processos paralelos) pode resultar em conflitos. Recomenda-se usar lock file para prevenir.

### Falhas Parciais

**Se um step falha (ex: validate falha após preview sucesso):**

Estado salvo:
```bash
PREVIEW_COMPLETED="1"
PREVIEW_EXIT_CODE="0"
VALIDATE_COMPLETED="0"
VALIDATE_EXIT_CODE="1"
```

**Próxima execução:**
- Preview: skipado (COMPLETED=1)
- Validate: re-executado (COMPLETED=0)

## Variáveis de Ambiente

### AUTO_YES

Controla confirmações interativas.

```bash
export AUTO_YES=1  # Skip todas as confirmações (unattended execution)
export AUTO_YES=0  # Pede confirmação (padrão, modo interativo)
```

**Usado em:**
- `oracle_rman_exec_with_state()` → `report_confirm()`
- Todas as operações destrutivas

**Exemplo de uso unattended:**
```bash
AUTO_YES=1 DRY_RUN=1 ./restore.sh  # Valida sem prompts
AUTO_YES=1 DRY_RUN=0 ./restore.sh  # Restaura sem prompts
```

### LOGDIR

Diretório onde o estado é salvo.

```bash
export LOGDIR="/custom/path"  # Custom path
# Padrão: /tmp/restore_${TARGET_SID}_logs_${SESSION_ID}
```

**Estado persistido em:** `${LOGDIR}/execution_state.sh`

### DRY_RUN

Controla nível de execução.

```bash
DRY_RUN=2  # Para após config (read-only)
DRY_RUN=1  # Para após validate (salva estado)
DRY_RUN=0  # Full restore (pula validated steps se estado existe)
```

## Compatibilidade

### Versão Anterior

Scripts sem state tracking continuam funcionando:
- `_rman_state_load()` retorna 1 (sem erro)
- Execução continua normalmente
- State tracking é opt-in (ativado automaticamente se usada nova API)

### Migração

Para migrar de versão antiga:
1. Nenhuma ação necessária
2. State tracking funciona automaticamente
3. Primeira execução cria `execution_state.sh`

**Retrocompatibilidade:**
- Funções antigas (`oracle_rman_exec_verbose`) ainda funcionam
- Nova API (`oracle_rman_exec_with_state`) adiciona state tracking
- Sem breaking changes

## Troubleshooting

### State não está sendo carregado

**Verificar estado salvo:**
```bash
ls -la ${LOGDIR}/execution_state.sh
cat ${LOGDIR}/execution_state.sh
```

**Verificar variáveis carregadas:**
```bash
export LOG_LEVEL=3  # Debug mode
./restore.sh
# Procurar por: [DEBUG] Loaded execution state from: ...
```

### Steps sendo re-executados indevidamente

**Debug:**
```bash
export LOG_LEVEL=3  # Debug mode
./restore.sh
```

**Procurar por:**
```
[DEBUG] State updated: PREVIEW completed in 42s
[DEBUG] Loaded execution state from: /tmp/.../execution_state.sh
```

**Verificar step completion:**
```bash
source ${LOGDIR}/execution_state.sh
echo "PREVIEW_COMPLETED=${PREVIEW_COMPLETED}"
echo "VALIDATE_COMPLETED=${VALIDATE_COMPLETED}"
```

### Catalog divergence sempre detectado

**Verificar CROSSCHECK_TIMESTAMP:**
```bash
grep CROSSCHECK_TIMESTAMP ${LOGDIR}/execution_state.sh
```

**Se muito antigo (>1h):**
- É comportamento esperado
- Re-execute crosscheck para atualizar timestamp

**Forçar crosscheck refresh:**
```bash
# Remove timestamp antigo
rm -f ${LOGDIR}/execution_state.sh
# Próxima execução faz crosscheck normal (sem prompt)
```

## Performance

### Estado File Size

Tamanho típico: ~200 bytes por step

**Exemplo:**
- 5 steps × 5 variáveis × 8 bytes = ~200 bytes total
- Crescimento linear com número de steps
- Negligível em termos de performance

### Load Performance

- **Load:** O(1) via `source`
- **Write:** O(n) onde n = número de keys (tipicamente < 50)
- **Get:** O(n) via grep (n = linhas no arquivo)

**Otimização futura:**
- Considerar JSON para grandes estados (>100 keys)
- Considerar SQLite para persistent state complexo

## Exemplo Completo de Workflow

### Workflow 1: Validate → Execute

```bash
# Step 1: Valida tudo (sem executar restore)
$ DRY_RUN=1 ./restore.sh

[INFO] Executing Phase A: Validation & Discovery
[INFO] Executing Phase B: Bootstrap & Metadata
[INFO] Executing Phase C: Catalog & Preview
[RMAN] Executing: Restore Preview
[OK] Preview concluido (42s)
[RMAN] Executing: Restore Validate
[OK] Validate concluido (68s)
================================================================
  DRY_RUN=1 COMPLETED - PREVIEW & VALIDATE OK
================================================================
  State saved to: /tmp/restore_logs/execution_state.sh

  TO EXECUTE THE ACTUAL RESTORE:
    DRY_RUN=0 ./restore.sh
================================================================

# Step 2: Verifica logs
$ cat /tmp/restore_logs/03_preview.log
$ cat /tmp/restore_logs/04_validate.log

# Step 3: Executa restore (pula preview/validate)
$ DRY_RUN=0 ./restore.sh

[INFO] Loaded execution state from: /tmp/restore_logs/execution_state.sh
[INFO] Executing Phase A: Validation & Discovery
[INFO] Executing Phase B: Bootstrap & Metadata
[INFO] Executing Phase C: Catalog & Preview
[INFO] [SKIP] Restore Preview: Already completed
[INFO] [SKIP] Restore Validate: Already completed
[RMAN] Executing: RESTORE DATABASE
[OK] Restore concluido (120s)
[RMAN] Executing: RECOVER DATABASE
[OK] Recover concluido (60s)
================================================================
  RESTORE COMPLETED SUCCESSFULLY
================================================================
```

### Workflow 2: Catalog Divergence

```bash
# Cenário: Crosscheck executado há 3 horas
$ DRY_RUN=0 ./restore.sh

[INFO] Loaded execution state from: /tmp/restore_logs/execution_state.sh
[INFO] Catalog may be stale (last crosscheck: 3h ago)
[INFO] Catalog may be stale. Re-run crosscheck? (YES/no)
> YES

[RMAN] Executing: Crosscheck backups
[OK] Crosscheck concluido (15s)
[INFO] Catalog refreshed

[INFO] [SKIP] Restore Preview: Already completed
[INFO] [SKIP] Restore Validate: Already completed
...
```

### Workflow 3: Unattended (AUTO_YES=1)

```bash
# Execute todo o restore sem prompts
$ AUTO_YES=1 DRY_RUN=0 ./restore.sh

[INFO] AUTO_YES=1: Skipping all confirmations
[RMAN] Executing: Restore Preview
[RMAN] Executing: Restore Validate
[RMAN] Executing: RESTORE DATABASE
[RMAN] Executing: RECOVER DATABASE
================================================================
  RESTORE COMPLETED SUCCESSFULLY
================================================================
```

## Referências

- Implementação: `lib/oracle_rman.sh` (Sections 10, 11, 12)
- Uso: `restore.sh` (função `phase_validate_and_restore`)
- Testes: `tests/test_rman_state.sh` (unit tests)
- Testes: `tests/test_rman_integration.sh` (integration tests)
