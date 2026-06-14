#!/usr/bin/env fish

# Print concrete rotation commands from discovered credential stores

set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
source $AUR_RESPONSE_DIR/lib/common.fish

aur_validate_known_flags $argv
aur_parse_common_args $argv

aur_log "=== Rotation command hints ==="
aur_log ""

# SSH
set -l ssh_keys
for f in $HOME/.ssh/id_* $HOME/.ssh/*@*
    if test -f $f; and not string match -q '*.pub' -- $f
        set -a ssh_keys $f
    end
end
if test (count $ssh_keys) -gt 0
    aur_log "## SSH"
    for k in $ssh_keys
        aur_log "  ssh-keygen -t ed25519 -f $k.new"
        aur_log "  # deploy $k.new.pub to servers, then: mv $k $k.compromised && mv $k.new $k"
    end
    aur_log ""
end

# GitHub
if test -f $HOME/.config/gh/hosts.yml -o -f $HOME/.git-credentials
    aur_log "## GitHub"
    aur_log "  gh auth logout"
    aur_log "  gh auth login"
    aur_log "  # Revoke all PATs: https://github.com/settings/tokens"
    if test -f $HOME/.git-credentials
        aur_log "  rm $HOME/.git-credentials  # after re-auth"
    end
    aur_log ""
end

# Docker registries
if test -f $HOME/.docker/config.json
    aur_log "## Docker registries"
    set -l registries
    if command -q jq
        set registries (jq -r '.auths | keys[]?' $HOME/.docker/config.json 2>/dev/null)
    else
        set registries (aur_grep -oE '"[^"]+":\s*\{' $HOME/.docker/config.json 2>/dev/null | sed 's/": {$//; s/^"//')
    end
    for reg in $registries
        test -n "$reg"; or continue
        aur_log "  docker logout $reg"
    end
    # Also try credsStore registries from fish history
    if string match -qir 'docker login' (cat $HOME/.local/share/fish/fish_history 2>/dev/null)
        aur_log "  # Registries from history — logout each:"
        while read -l line
            if string match -qr 'docker login (\S+)' -- $line
                aur_log "  docker logout "(string match -r 'docker login (\S+)' $line)[2]
            end
        end <$HOME/.local/share/fish/fish_history
    end
    aur_log ""
end

# npm
if test -f $HOME/.npmrc
    aur_log "## npm"
    aur_log "  npm logout"
    aur_log "  # Revoke tokens: https://www.npmjs.com/settings/~tokens"
    aur_log "  echo 'ignore-scripts=true' >> ~/.npmrc"
    aur_log ""
end

# Discord
if test -d $HOME/.config/discord
    aur_log "## Discord"
    aur_log "  Change password + enable 2FA: https://discord.com/channels/@me"
    aur_log "  Settings → Authorized Apps → revoke all"
    aur_log ""
end

aur_log "Homelab env files: rotate secrets in $AUR_DEV_ROOT/docker/stacks/*/stack.env"
aur_log "After rotation: fish $AUR_SCRIPTS_DIR/scrub-history.fish --all-shells --dry-run"
