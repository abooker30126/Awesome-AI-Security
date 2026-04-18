# Security Keys & GPG Signing

This document explains how GPG signing is used in this repository, how to set up your local environment, and how to verify signatures.

---

## Table of Contents

1. [Overview](#overview)
2. [Setting Up GPG Locally](#setting-up-gpg-locally)
3. [Configuring GitHub Secrets](#configuring-github-secrets)
4. [Verifying Signatures](#verifying-signatures)
5. [Workflow Behaviour](#workflow-behaviour)
6. [Troubleshooting](#troubleshooting)

---

## Overview

Every pull request that modifies files with the extensions `.sh`, `.py`, `.yml`, or `.tf` automatically receives a detached GPG signature stored alongside the original file as `<filename>.gpg.sig`.

Signatures are created by the [`gpg-sign-files` workflow](workflows/gpg-sign-files.yml) using a repository-level secret.

---

## Setting Up GPG Locally

### Prerequisites

| Tool | Minimum version |
|------|----------------|
| `gpg` | 2.2 |
| `git` | 2.x |

### Quick Start

```bash
# Clone the repository
git clone https://github.com/abooker30126/Awesome-AI-Security.git
cd Awesome-AI-Security

# Run the setup helper (interactive)
bash .github/scripts/setup-gpg.sh
```

The script will:

1. Generate a new RSA 4096-bit key (or import an existing one).
2. Configure `git` to sign all future commits and tags automatically.
3. Export your public key to `~/.gnupg/gpg-public-<KEY_ID>.asc`.

### Using an Existing Key

```bash
# Import from an exported key file
GPG_PRIVATE_KEY_FILE=~/my-key.asc bash .github/scripts/setup-gpg.sh

# Or pass the key ID directly (key must already be in your keyring)
GPG_KEY_ID=B732B308C0FE0BB3 bash .github/scripts/setup-gpg.sh
```

### Export Your Public Key for GitHub

After running the setup script, add your public key to GitHub so that your signed commits are shown as *Verified*:

1. Open `~/.gnupg/gpg-public-<KEY_ID>.asc` in a text editor.
2. Copy the entire contents (including `-----BEGIN PGP PUBLIC KEY BLOCK-----`).
3. Go to **GitHub → Settings → SSH and GPG keys → New GPG key** and paste it.

---

## Configuring GitHub Secrets

The signing workflow requires two repository secrets:

| Secret name       | Description |
|-------------------|-------------|
| `GPG_PRIVATE_KEY` | Armoured private key, exported with `gpg --armor --export-secret-keys <KEY_ID>` |
| `GPG_PASSPHRASE`  | Passphrase that protects the private key |

### Adding Secrets

1. Navigate to **Repository → Settings → Secrets and variables → Actions**.
2. Click **New repository secret**.
3. Add `GPG_PRIVATE_KEY`:

   ```bash
   gpg --armor --export-secret-keys <YOUR_KEY_ID>
   # Copy the entire output, including header/footer lines
   ```

4. Add `GPG_PASSPHRASE` (the passphrase you chose when creating the key).

> **Security note:** Never commit the private key or passphrase to the repository. Use GitHub Secrets exclusively.

---

## Verifying Signatures

### Verify a Single File

```bash
# Import the repository's public key first (one-time setup)
gpg --keyserver keyserver.ubuntu.com --recv-keys <KEY_ID>

# Verify
gpg --verify path/to/file.sh.gpg.sig path/to/file.sh
```

A successful verification looks like:

```
gpg: Signature made Mon 18 Apr 2026 19:32:41 UTC
gpg:                using RSA key C8040559438A554CAD747154B732B308C0FE0BB3
gpg: Good signature from "Anthony Booker <anthony@example.com>" [ultimate]
```

### Verify All Signatures in a Directory

```bash
find . -name '*.gpg.sig' | while read -r sig; do
  original="${sig%.gpg.sig}"
  echo -n "Verifying $original ... "
  gpg --batch --verify "$sig" "$original" 2>/dev/null && echo "OK" || echo "FAILED"
done
```

---

## Workflow Behaviour

The [gpg-sign-files workflow](workflows/gpg-sign-files.yml) runs automatically on every pull request (`opened`, `synchronize`, `reopened`).

```
PR opened / updated
       │
       ▼
Identify files changed vs. base branch
(extensions: .sh  .py  .yml  .tf)
       │
       ▼
Filter against .gpg-ignore
       │
       ▼
Sign each file → <file>.gpg.sig
       │
       ▼
Verify each signature
       │
       ▼
Commit signatures to PR branch
       │
       ▼
Post signature report as PR comment
```

Files listed in [`.gpg-ignore`](../../.gpg-ignore) are excluded from signing.

---

## Troubleshooting

### `No secret key` error in the workflow

Ensure the `GPG_PRIVATE_KEY` secret contains the *full* armoured output of:

```bash
gpg --armor --export-secret-keys <KEY_ID>
```

including the `-----BEGIN PGP PRIVATE KEY BLOCK-----` header.

### Signature says `BAD signature`

The file was modified after it was signed. Re-run the workflow (push an empty commit, for example) to re-sign the file.

### `gpg: signing failed: Inappropriate ioctl for device`

Add the following to `~/.gnupg/gpg-agent.conf` and restart the agent:

```
allow-loopback-pinentry
```

```bash
gpgconf --reload gpg-agent
```
