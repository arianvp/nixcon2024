#!/usr/bin/env bash

set -euo pipefail

token=$(curl -sSf -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

get_tags() {
    curl -sSf -H "X-aws-ec2-metadata-token: $token" "http://169.254.169.254/latest/meta-data/tags/instance"
}

get_tag() {
    curl -sSf -H "X-aws-ec2-metadata-token: $token" "http://169.254.169.254/latest/meta-data/tags/instance/$1"
}

for tag in $(get_tags); do
  case $tag in
    Installable)
      installable=$(get_tag Installable)
      ;;
    Substituters)
      substituters=$(get_tag Substituters)
      ;;
    TrustedPublicKeys)
      trustedPublicKeys=$(get_tag TrustedPublicKeys)
  esac
done

profile=/nix/var/nix/profiles/system
installable=${installable:-}
substituters=${substituters:-}
trustedPublicKeys=${trustedPublicKeys:-}

if [ -z "$installable" ]; then
  echo "No installable tag found. exiting."
  exit 0
fi

nix build \
  --extra-experimental-features 'nix-command flakes' \
  --extra-trusted-public-keys "$trustedPublicKeys" \
  --extra-substituters "$substituters" \
  --profile "$profile" \
  --refresh \
  "$installable"

"$profile/bin/switch-to-configuration" boot

if [ "$(readlink -f /run/current-system)" == "$(readlink -f /nix/var/nix/profiles/system)" ]; then
  echo "Already booted into desired configuration. exiting."
  exit 0
fi

systemctl start kexec.target --job-mode=replace-irreversibly --no-block