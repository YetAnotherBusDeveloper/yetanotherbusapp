#!/usr/bin/env bash
# Adapted from mobile-agent-testers/scripts/encrypt_results.sh (LICENSE.upstream).
# usage: encrypt.sh SESSION_DIR PERSONA PUBLIC_PEM NEW_OUTPUT_DIR
set -euo pipefail
umask 077
session=$1 name=$2 pub=$3 out=$4
[[ $name =~ ^[a-z][a-z0-9_-]*$ && -d "$session/results" && ! -L "$session/results" ]]
mkdir -m 700 "$out"  # fresh, outside the agent workspace
# Only ordinary report files/directories. Fail closed, including on partial encryption.
[[ -z $(find "$session/results" ! -type d ! -type f -printf x -quit) ]]
key=$(openssl rand -hex 32)
tar -C "$session" -czf - results | MAT_AES_KEY=$key openssl enc -aes-256-cbc -pbkdf2 -salt \
  -pass env:MAT_AES_KEY -out "$out/$name.tgz.enc"
printf %s "$key" | openssl pkeyutl -encrypt -pubin -inkey "$pub" -pkeyopt rsa_padding_mode:oaep \
  -out "$out/$name.key.bin"
