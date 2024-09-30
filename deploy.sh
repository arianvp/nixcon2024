#!/bin/sh

function list_tags() {

}

function get_tag_value() {
    name=$1
}

for tag in $(list_tags); do
    value=$(get_tag_value $tag)
    case $tag in
        Profile)
            profile=$value
            ;;
        Installable)
            installable=$value
            ;;
        Substituters)
            substituters=$value
            ;;
        TrustedPublicKeys)
            trusted_public_keys=$value
            ;;
    esac
done

# set to empty if unset
profile=${profile:-'/nix/var/nix/profiles/system'}
installable=${installable:-}
substituters=${substituters:-}
trusted_public_keys=${trusted_public_keys:-}

nix build \
    --extra-experimental-features 'nix-command flakes' \
    --extra-trusted-public-keys "$trusted_public_keys" \
    --extra-substituters "$substituters" \
    --profile "$profile" \
    --refresh \
    "$installable"

"$profile/bin/switch-to-configuration" boot
systemctl start kexec.target --job-mode=replace-irreversibly --no-block