#!/usr/bin/env bash

set -euo pipefail

action='{{ action }}'
installable='{{ installable }}'
profile='{{ profile }}'
substituters='{{ substituters }}'
trustedPublicKeys='{{ trustedPublicKeys }}'

nix build \
  --extra-experimental-features 'nix-command flakes' \
  --extra-trusted-public-keys "$trustedPublicKeys" \
  --extra-substituters "$substituters" \
  --refresh \
  --profile "$profile" \
  "$installable"

if [ "$(readlink -f /run/current-system)" == "$(readlink -f "$profile")" ]; then
  echo "Already booted into the desired configuration"
  exit 0
fi

if [ "$action" == "reboot" ]; then
  action="boot"
  do_reboot=1
fi

sudo "$profile/bin/switch-to-configuration" "$action"

if [ "$do_reboot" == 1 ]; then
  exit 194
fi