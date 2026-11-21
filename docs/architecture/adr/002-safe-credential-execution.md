# 002. Execução Segura e Cifragem de Credenciais

## Status
Aceito (2026-11-04)

## Contexto
O gerenciador de credenciais do DCX (`lib/cred.sh` e `cmd/dcx/cred.go`) armazena e recupera segredos para conexões de bancos de dados (Oracle, MySQL, etc.) e integrações corporativas. O arquivo de credenciais é cifrado com AES-256-CBC e PBKDF2 (100.000 iterações).

No entanto, o wrapper em Go executava as funções do `cred.sh` interpolando as chaves e valores diretamente via `%q` dentro de strings de comando bash. O `%q` do Go não escapa operadores shell como `$()`, permitindo execução arbitrária de código.

## Decisão
1. **Invocação com Argumentos Protegidos**: Substituir a interpolação shell em `runCredCommand` por passagem via `$1`, `$2`, `"${@:3}"`:
   ```go
   cmd := exec.Command("bash", "-c", `source "$1" && "$2" "${@:3}"`, "_", credShPath, funcName, args...)
   ```
2. **Validação Estrita de Chaves**: Toda chave DEVE seguir o padrão `serviço/ambiente/identificador` antes de qualquer processamento, rejeitando caracteres de controle e operadores de shell.
3. **Redação e Proteção de Segredos**: Segredos decifrados nunca devem ser registrados em logs ou arquivos de depuração.
4. **Isolamento de Stdin**: O processo só solicita senhas no terminal interativo quando `stdin` for um TTY; em pipelines automatizados de CI ou agentes, a ausência de variável de ambiente ou senha fornecida deve falhar imediatamente sem bloquear o processo.

## Consequências
- Resolução definitiva do achado Semgrep `916685869` e fechamento com evidência do bead `dcx-nes.3`.
- Robustez contra travamentos em execuções de automação não-interativas.
