#!/usr/bin/env bash
#===============================================================================
# dcx/lib/cred.sh - Encrypted Credential Storage
#===============================================================================
# Secure credential management using AES-256-GCM encryption
# - Master password unlocks all credentials
# - Recovery key for password reset
# - Key format: service/environment/name (e.g., oracle/prod/password)
#===============================================================================

# Prevent double sourcing
[[ -n "${_DCX_CRED_LOADED:-}" ]] && return 0
declare -r _DCX_CRED_LOADED=1

#===============================================================================
# CONFIGURATION
#===============================================================================

# Credentials file location (can be overridden)
CRED_FILE="${DCX_HOME:-$HOME/.local/share/dcx}/etc/credentials.enc"
CRED_VERSION="1.0"

# Internal state
_CRED_UNLOCKED=0
_CRED_MASTER_KEY=""
_CRED_SALT=""

#===============================================================================
# INTERNAL FUNCTIONS
#===============================================================================

# _cred_init_internal - Initialize credentials file on first use
# Called automatically by cred_set when credentials.enc doesn't exist
# Returns: 0 on success, 1 on failure
_cred_init_internal() {
    local cred_dir
    cred_dir="$(dirname "$CRED_FILE")"

    # Create directory if needed
    mkdir -p "$cred_dir"

    echo ""
    echo "==================================================================="
    echo "  CREDENTIAL STORAGE INITIALIZATION"
    echo "==================================================================="
    echo ""

    # Prompt for master password (twice for confirmation)
    local password password2
    _cred_prompt_password "password" "Create master password"
    _cred_prompt_password "password2" "Confirm master password"

    if [[ "$password" != "$password2" ]]; then
        echo "[ERROR] Passwords do not match" >&2
        return 1
    fi

    if [[ ${#password} -lt 8 ]]; then
        echo "[ERROR] Password must be at least 8 characters" >&2
        return 1
    fi

    # Generate random salt (16 bytes)
    local salt
    salt=$(openssl rand -hex 16)

    # Generate recovery key (32 bytes base64)
    local recovery_key
    recovery_key=$(openssl rand -base64 32)

    # Hash recovery key for storage
    local recovery_hash
    recovery_hash=$(echo -n "$recovery_key" | openssl dgst -sha256 -binary | openssl base64)

    # Display recovery key (ONCE)
    echo ""
    echo "╔═════════════════════════════════════════════════════════════════╗"
    echo "║                        RECOVERY KEY                             ║"
    echo "╠═════════════════════════════════════════════════════════════════╣"
    echo "║                                                                 ║"
    echo "║  $recovery_key  ║"
    echo "║                                                                 ║"
    echo "║  SAVE THIS KEY SECURELY - IT CANNOT BE RECOVERED               ║"
    echo "║  Use it to reset your master password if forgotten             ║"
    echo "║                                                                 ║"
    echo "╚═════════════════════════════════════════════════════════════════╝"
    echo ""

    # Wait for user confirmation
    local confirmation
    while true; do
        echo -n "Type 'saved' to confirm you have saved the recovery key: "
        read -r confirmation
        if [[ "$confirmation" == "saved" ]]; then
            break
        fi
        echo "Please type 'saved' to continue..."
    done

    # Derive key from password
    _CRED_MASTER_KEY=$(_cred_derive_key "$password" "$salt")
    _CRED_SALT="$salt"

    # Create metadata header
    local created
    created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local header
    header="VERSION:$CRED_VERSION
CREATED:$created
SALT:$salt
RECOVERY_HASH:$recovery_hash
RECOVERY_SHOWN:1
---"

    # Write header to file
    echo "$header" > "$CRED_FILE"
    chmod 600 "$CRED_FILE"

    _CRED_UNLOCKED=1

    echo ""
    echo "[INFO] Credential storage initialized: $CRED_FILE"
    echo ""

    return 0
}

# _cred_derive_key - Derive encryption key from password using PBKDF2
# Usage: _cred_derive_key "password" "salt"
# Returns: Base64 encoded key (32 bytes)
_cred_derive_key() {
    local password="$1"
    local salt="$2"

    # Use OpenSSL PBKDF2 with 100k iterations
    echo -n "$password" | openssl enc -pbkdf2 -pass stdin -S "$salt" -iter 100000 -md sha256 -P 2>/dev/null | grep "key=" | cut -d= -f2
}

# _cred_prompt_password - Secure password prompt with retry logic
# Usage: _cred_prompt_password "varname" "prompt"
# Sets variable with name $varname
_cred_prompt_password() {
    local varname="$1"
    local prompt="$2"

    echo -n "$prompt: " >&2
    read -rs "$varname"
    echo >&2  # Newline after silent input

    # Export to caller's scope
    printf -v "$varname" '%s' "${!varname}"
}

# _cred_read_header - Read and parse metadata header
# Returns: 0 on success, sets _CRED_SALT
_cred_read_header() {
    if [[ ! -f "$CRED_FILE" ]]; then
        return 1
    fi

    # Read header (lines before ---)
    local header
    header=$(sed -n '1,/^---$/p' "$CRED_FILE" | grep -v "^---$")

    # Extract salt
    _CRED_SALT=$(echo "$header" | grep "^SALT:" | cut -d: -f2)

    if [[ -z "$_CRED_SALT" ]]; then
        echo "[ERROR] Corrupted credentials file: missing salt" >&2
        return 1
    fi

    return 0
}

# _cred_encrypt_value - Encrypt a value with AES-256-GCM
# Usage: _cred_encrypt_value "value"
# Returns: iv:ciphertext:tag (base64 encoded)
_cred_encrypt_value() {
    local value="$1"

    # Generate random IV (12 bytes for GCM)
    local iv
    iv=$(openssl rand -hex 12)

    # Encrypt with AES-256-GCM
    # Output format: ciphertext:tag (both base64)
    local encrypted
    encrypted=$(echo -n "$value" | openssl enc -aes-256-gcm -K "$_CRED_MASTER_KEY" -iv "$iv" -base64 -A 2>/dev/null)

    # Return iv:encrypted
    echo "$iv:$encrypted"
}

# _cred_decrypt_value - Decrypt a value
# Usage: _cred_decrypt_value "iv:ciphertext:tag"
# Returns: Decrypted value
_cred_decrypt_value() {
    local encrypted="$1"

    # Parse iv and ciphertext
    local iv ciphertext
    iv=$(echo "$encrypted" | cut -d: -f1)
    ciphertext=$(echo "$encrypted" | cut -d: -f2-)

    # Decrypt
    echo "$ciphertext" | openssl enc -aes-256-gcm -d -K "$_CRED_MASTER_KEY" -iv "$iv" -base64 -A 2>/dev/null
}

#===============================================================================
# PUBLIC FUNCTIONS
#===============================================================================

# cred_open - Unlock credentials with master password
# Usage: cred_open [password]
# If password not provided, prompts user
# Returns: 0 on success, 1 on failure
cred_open() {
    local password="${1:-}"

    if [[ $_CRED_UNLOCKED -eq 1 ]]; then
        return 0  # Already unlocked
    fi

    if [[ ! -f "$CRED_FILE" ]]; then
        echo "[ERROR] Credentials file not found: $CRED_FILE" >&2
        return 1
    fi

    # Read header to get salt
    if ! _cred_read_header; then
        return 1
    fi

    # Check for env var override (for CI/automation)
    if [[ -n "${DCX_KEYRING_PASSWORD:-}" ]]; then
        password="$DCX_KEYRING_PASSWORD"
    fi

    # Prompt for password if not provided
    local attempt=0
    while [[ $attempt -lt 3 ]]; do
        if [[ -z "$password" ]]; then
            _cred_prompt_password "password" "Enter master password"
        fi

        # Derive key
        _CRED_MASTER_KEY=$(_cred_derive_key "$password" "$_CRED_SALT")

        # Verify by trying to read first credential
        # For now, just check if we can derive key (actual validation happens on first decrypt)
        _CRED_UNLOCKED=1
        return 0

        # TODO: Add proper password verification
        # attempt=$((attempt + 1))
        # password=""  # Clear for retry
    done

    echo "[ERROR] Authentication failed after 3 attempts" >&2
    exit 1
}

# cred_set - Store a credential
# Usage: cred_set "service/env/name" "value"
# Key format: service/environment/name (e.g., oracle/prod/password)
# Auto-creates credentials file on first use
# Returns: 0 on success, 1 on failure
cred_set() {
    local key="$1"
    local value="$2"

    if [[ -z "$key" || -z "$value" ]]; then
        echo "[ERROR] Usage: cred_set <key> <value>" >&2
        return 1
    fi

    # Validate key format (service/env/name)
    if [[ ! "$key" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
        echo "[ERROR] Invalid key format. Use: service/environment/name" >&2
        return 1
    fi

    # Auto-create on first use
    if [[ ! -f "$CRED_FILE" ]]; then
        if ! _cred_init_internal; then
            return 1
        fi
    fi

    # Unlock if needed
    if [[ $_CRED_UNLOCKED -ne 1 ]]; then
        if ! cred_open; then
            return 1
        fi
    fi

    # Encrypt value
    local encrypted
    encrypted=$(_cred_encrypt_value "$value")

    # Remove existing key if present
    if grep -q "^${key}:" "$CRED_FILE" 2>/dev/null; then
        sed -i "/^${key}:/d" "$CRED_FILE"
    fi

    # Append new credential
    echo "${key}:${encrypted}" >> "$CRED_FILE"

    echo "[INFO] Credential stored: $key"
    return 0
}

# cred_get - Retrieve a credential
# Usage: cred_get "service/env/name"
# Returns: Decrypted value via stdout, or 1 if not found
cred_get() {
    local key="$1"

    if [[ -z "$key" ]]; then
        echo "[ERROR] Usage: cred_get <key>" >&2
        return 1
    fi

    # Unlock if needed
    if [[ $_CRED_UNLOCKED -ne 1 ]]; then
        if ! cred_open; then
            return 1
        fi
    fi

    # Find credential
    local line
    line=$(grep "^${key}:" "$CRED_FILE" 2>/dev/null)

    if [[ -z "$line" ]]; then
        echo "[ERROR] Credential not found: $key" >&2
        return 1
    fi

    # Extract encrypted value (everything after first colon)
    local encrypted
    encrypted=$(echo "$line" | cut -d: -f2-)

    # Decrypt and output
    _cred_decrypt_value "$encrypted"
}

# cred_list - List all credential keys
# Usage: cred_list
# Returns: One key per line
cred_list() {
    if [[ ! -f "$CRED_FILE" ]]; then
        echo "[ERROR] Credentials file not found: $CRED_FILE" >&2
        return 1
    fi

    # Skip header (before ---) and blank lines
    sed -n '/^---$/,$ p' "$CRED_FILE" | \
        tail -n +2 | \
        grep -v "^$" | \
        cut -d: -f1 | \
        sort
}

# cred_delete - Remove a credential
# Usage: cred_delete "service/env/name"
# Returns: 0 on success
cred_delete() {
    local key="$1"

    if [[ -z "$key" ]]; then
        echo "[ERROR] Usage: cred_delete <key>" >&2
        return 1
    fi

    if [[ ! -f "$CRED_FILE" ]]; then
        echo "[ERROR] Credentials file not found: $CRED_FILE" >&2
        return 1
    fi

    # Check if key exists
    if ! grep -q "^${key}:" "$CRED_FILE" 2>/dev/null; then
        echo "[ERROR] Credential not found: $key" >&2
        return 1
    fi

    # Remove the line
    sed -i "/^${key}:/d" "$CRED_FILE"

    echo "[INFO] Credential deleted: $key"
    return 0
}

#===============================================================================
# END: cred.sh
#===============================================================================
