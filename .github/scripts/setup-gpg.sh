#!/usr/bin/env bash
# setup-gpg.sh
# Configures the local GPG environment for commit signing.
#
# Usage:
#   ./setup-gpg.sh                        # interactive – prompts for all inputs
#   GPG_KEY_ID=<id> ./setup-gpg.sh        # uses existing key, skips generation
#   GPG_PRIVATE_KEY_FILE=<path> ./setup-gpg.sh  # imports from an exported key file

set -euo pipefail

log()  { echo "[setup-gpg] $*"; }
die()  { echo "[setup-gpg] ERROR: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Ensure gpg is available
# ---------------------------------------------------------------------------
command -v gpg &>/dev/null || die "gpg is not installed. Install it and re-run."

# ---------------------------------------------------------------------------
# 2. Import an existing key or generate a new one
# ---------------------------------------------------------------------------
if [[ -n "${GPG_PRIVATE_KEY_FILE:-}" ]]; then
    log "Importing GPG key from: $GPG_PRIVATE_KEY_FILE"
    gpg --batch --import "$GPG_PRIVATE_KEY_FILE"

elif [[ -n "${GPG_KEY_ID:-}" ]]; then
    log "Using existing key: $GPG_KEY_ID"

else
    log "No existing key supplied – generating a new RSA 4096-bit key."
    read -r -p "Full name  : " GPG_NAME
    read -r -p "Email      : " GPG_EMAIL
    read -r -s -p "Passphrase : " GPG_PASS
    echo

    gpg --batch --gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: ${GPG_NAME}
Name-Email: ${GPG_EMAIL}
Passphrase: ${GPG_PASS}
Expire-Date: 2y
%commit
EOF
    log "Key generated."
fi

# ---------------------------------------------------------------------------
# 3. Identify the key to configure
# ---------------------------------------------------------------------------
if [[ -z "${GPG_KEY_ID:-}" ]]; then
    # Pick the first available secret key
    GPG_KEY_ID=$(gpg --batch --list-secret-keys --with-colons \
        | awk -F: '/^sec/{print $5; exit}')
    [[ -z "$GPG_KEY_ID" ]] && die "Could not determine GPG key ID."
fi

log "Configuring git to sign commits with key: $GPG_KEY_ID"

# ---------------------------------------------------------------------------
# 4. Configure git
# ---------------------------------------------------------------------------
git config --global user.signingkey "$GPG_KEY_ID"
git config --global commit.gpgsign true
git config --global tag.gpgsign    true

# Point git at the correct gpg binary (handles macOS homebrew paths, etc.)
GPG_BIN=$(command -v gpg)
git config --global gpg.program "$GPG_BIN"

# ---------------------------------------------------------------------------
# 5. Export the public key for GitHub / team members
# ---------------------------------------------------------------------------
PUB_KEY_FILE="${HOME}/.gnupg/gpg-public-${GPG_KEY_ID}.asc"
gpg --armor --export "$GPG_KEY_ID" > "$PUB_KEY_FILE"
log "Public key exported to: $PUB_KEY_FILE"
log ""
log "Next steps:"
log "  1. Add the public key to your GitHub account:"
log "       https://github.com/settings/keys"
log "  2. To export the private key for GitHub Actions secrets, run:"
log "       gpg --armor --export-secret-keys $GPG_KEY_ID > private-key.asc"
log "     Then add the contents as the GPG_PRIVATE_KEY secret in your repo settings."
log "  3. Add GPG_PASSPHRASE as a separate secret."
log ""
log "Setup complete. Your commits and tags will now be GPG-signed automatically."
