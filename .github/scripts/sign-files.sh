#!/usr/bin/env bash
# sign-files.sh
# Usage: sign-files.sh <file> [<file> ...]
#
# Signs each supplied file with GPG and writes a detached armoured signature
# alongside the original as <file>.gpg.sig.  Verifies the signature before
# exiting so the workflow fails fast on any signing error.
#
# Required environment variables:
#   GPG_PASSPHRASE  – passphrase protecting the imported private key

set -euo pipefail

IGNORE_FILE="${IGNORE_FILE:-.gpg-ignore}"
ERRORS=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[sign-files] $*"; }
warn() { echo "[sign-files] WARNING: $*" >&2; }
die()  { echo "[sign-files] ERROR: $*" >&2; exit 1; }

# Return 0 if the file matches a pattern in .gpg-ignore, 1 otherwise.
is_ignored() {
    local file="$1"
    [[ -f "$IGNORE_FILE" ]] || return 1

    while IFS= read -r pattern || [[ -n "$pattern" ]]; do
        # Skip blank lines and comments
        [[ -z "$pattern" || "$pattern" == \#* ]] && continue
        # shellcheck disable=SC2254
        case "$file" in
            $pattern) return 0 ;;
        esac
    done < "$IGNORE_FILE"
    return 1
}

# Resolve the key fingerprint to use (first secret key available).
get_key_fingerprint() {
    gpg --batch --list-secret-keys --with-colons 2>/dev/null \
        | awk -F: '/^fpr/{print $10; exit}'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
[[ $# -eq 0 ]] && die "No files supplied."

FINGERPRINT="$(get_key_fingerprint)"
[[ -z "$FINGERPRINT" ]] && die "No GPG secret key found in keyring."
log "Signing with key fingerprint: $FINGERPRINT"

for FILE in "$@"; do
    # Skip empty arguments (can happen when called with an empty list)
    [[ -z "$FILE" ]] && continue

    if [[ ! -f "$FILE" ]]; then
        warn "File not found, skipping: $FILE"
        continue
    fi

    if is_ignored "$FILE"; then
        log "Skipping ignored file: $FILE"
        continue
    fi

    SIG_FILE="${FILE}.gpg.sig"

    log "Signing: $FILE → $SIG_FILE"

    # Create detached, armoured signature
    gpg --batch \
        --pinentry-mode loopback \
        --passphrase-fd 0 \
        --armor \
        --detach-sign \
        --default-key "$FINGERPRINT" \
        --output "$SIG_FILE" \
        "$FILE" <<< "${GPG_PASSPHRASE:-}"

    # Verify immediately so we fail fast on any signing error
    if gpg --batch --verify "$SIG_FILE" "$FILE" 2>/dev/null; then
        log "Verified: $SIG_FILE ✓"
    else
        warn "Signature verification FAILED for: $FILE"
        ERRORS=$(( ERRORS + 1 ))
    fi
done

if [[ $ERRORS -gt 0 ]]; then
    die "$ERRORS signature(s) failed verification."
fi

log "All signatures created and verified successfully."
