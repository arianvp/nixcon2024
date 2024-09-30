#!/bin/sh
set -e
key_name=$1

if [ -z "$key_name" ]; then
  echo "Usage: $0 <key-name>"
  exit 1
fi

nix key generate-secret --key-name "$key_name" > key.sec
gh secret set NIX_SECRET_KEY < key.sec
nix key convert-secret-to-public < key.sec > key.pub
gh variable set NIX_PUBLIC_KEY < key.pub
