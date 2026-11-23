#!/usr/bin/env bash
# Local only. Usage: decrypt.sh PRIVATE_PEM path/to/anna.key.bin NEW_DIR
# Compatible with mobile-agent-testers' RSA-OAEP / PBKDF2 / AES-256-CBC format.
set -euo pipefail
umask 077
priv=$1 wrapped=$2 out=$3
if git -C "$(dirname "$out")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo 'Choose an output directory outside any git checkout.' >&2; exit 1
fi
mkdir -m 700 "$out"  # never overwrite a previous run
key=$(openssl pkeyutl -decrypt -inkey "$priv" -pkeyopt rsa_padding_mode:oaep -in "$wrapped")
MAT_AES_KEY=$key openssl enc -d -aes-256-cbc -pbkdf2 -in "${wrapped%.key.bin}.tgz.enc" -pass env:MAT_AES_KEY |
  python3 -c 'import sys,tarfile
with tarfile.open(fileobj=sys.stdin.buffer, mode="r|gz") as archive:
    for m in archive:
        if not (m.isdir() or m.isfile()) or m.name.split("/")[0] != "results" or ".." in m.name.split("/"):
            sys.exit("Unsafe archive member")
        archive.extract(m, sys.argv[1], filter="data")' "$out"
echo 'Decrypted locally; review the numbered screenshots before accepting any finding.'
