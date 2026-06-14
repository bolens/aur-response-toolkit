#!/usr/bin/env fish

# Print concrete rotation commands from audit findings (or rediscover if run standalone).

source (dirname (dirname (status filename)))/_init.fish

aur_validate_known_flags $argv
aur_parse_common_args $argv

aur_log "=== Rotation command hints ==="
aur_log ""

set -l ssh_keys (aur_finding_list audit_ssh_keys)
# use_findings=true when a prior audit wrote audit_ssh_keys to the findings store.
set -l use_findings false
if test (count $ssh_keys) -gt 0
    set use_findings true
end

set -l git_paths (aur_finding_list audit_git_paths)
set -l docker_paths (aur_finding_list audit_docker_paths)
set -l env_files (aur_finding_list audit_env_files)
set -l history_files (aur_finding_list audit_history_files)

# When run after run.fish, reuse audit findings; standalone mode rediscovers SSH keys from ~/.ssh.
if test $use_findings = false
    for f in $HOME/.ssh/id_* $HOME/.ssh/*@*
        if test -f $f; and not string match -q '*.pub' -- $f
            set -a ssh_keys $f
        end
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

set -l has_github false
if test (count $git_paths) -gt 0
    set has_github true
else if test -f $HOME/.config/gh/hosts.yml -o -f $HOME/.git-credentials
    set has_github true
end
if test $has_github = true
    aur_log "## GitHub"
    aur_log "  gh auth logout"
    aur_log "  gh auth login"
    aur_log "  # Revoke all PATs: https://github.com/settings/tokens"
    if test -f $HOME/.git-credentials
        aur_log "  rm $HOME/.git-credentials  # after re-auth"
    end
    aur_log ""
end

set -l has_docker false
if test (count $docker_paths) -gt 0
    set has_docker true
else if test -f $HOME/.docker/config.json
    set has_docker true
end
if test $has_docker = true
    aur_log "## Docker registries"
    if test -f $HOME/.docker/config.json
        set -l registries (aur_docker_config_registry_keys $HOME/.docker/config.json)
        for reg in $registries
            test -n "$reg"; or continue
            aur_log "  docker logout $reg"
        end
    end
    for h in $history_files (aur_shell_history_paths)
        test -f $h; or continue
        set -l hist_content (cat $h 2>/dev/null)
        if string match -qi '*docker login*' -- $hist_content
            aur_log "  # Registries from $h — logout each:"
            while read -l line
                if string match -qr 'docker login (\S+)' -- $line
                    aur_log "  docker logout "(string match -r 'docker login (\S+)' $line)[2]
                end
            end <$h
            break
        end
    end
    aur_log ""
end

if test -f $HOME/.npmrc
    aur_log "## npm"
    aur_log "  npm logout"
    aur_log "  # Revoke tokens: https://www.npmjs.com/settings/~tokens"
    aur_log "  echo 'ignore-scripts=true' >> ~/.npmrc"
    aur_log ""
end

if test -d $HOME/.config/discord
    aur_log "## Discord"
    aur_log "  Change password + enable 2FA: https://discord.com/channels/@me"
    aur_log "  Settings → Authorized Apps → revoke all"
    aur_log ""
end

if test (count $env_files) -gt 0
    aur_log "## Homelab env files ("(count $env_files)")"
    for f in $env_files
        aur_log "  # rotate secrets in $f"
    end
    aur_log ""
else
    aur_log "Homelab env files: rotate secrets in $AUR_DEV_ROOT/docker/stacks/*/stack.env"
end

aur_log "After rotation: fish (aur_script_path recovery/scrub-history.fish) --all-shells --dry-run"
