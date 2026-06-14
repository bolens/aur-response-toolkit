#!/usr/bin/env fish

set -g AUR_RESPONSE_DIR (dirname (status filename))
source $AUR_RESPONSE_DIR/lib/common.fish

set -l write_report false
for arg in $argv
    if test "$arg" = --report
        set write_report true
    end
end

if test $write_report = true; and not set -q AUR_REPORT_FILE[1]
    aur_begin_report credential-audit-
end

set -g AUR_AUDIT_SSH_KEYS
set -g AUR_AUDIT_GIT_PATHS
set -g AUR_AUDIT_DOCKER_PATHS
set -g AUR_AUDIT_ENV_FILES
set -g AUR_AUDIT_HISTORY_FILES

function audit_path --argument-names path desc
    if test -e $path
        set -l mtime (aur_file_mtime $path)
        aur_log "  [EXPOSED] $desc"
        aur_log "            $path  (mtime: $mtime)"
        return 0
    end
    return 1
end

function audit_find --argument-names base pattern desc
    if not test -d $base
        return 0
    end
    set -l found false
    for f in (find $base -name $pattern 2>/dev/null)
        set found true
        set -l mtime (aur_file_mtime $f)
        aur_log "  [EXPOSED] $desc"
        aur_log "            $f  (mtime: $mtime)"
    end
end

aur_log "=== AUR worm credential exposure audit ==="
aur_log "Based on ioctl.fail / Sonatype analysis of the 'deps' infostealer"
aur_log ""

aur_log "## 1. SSH keys"
for f in $HOME/.ssh/id_* $HOME/.ssh/*@*
    if test -f $f; and not string match -q '*.pub' -- $f
        if audit_path $f "private key"
            set -a AUR_AUDIT_SSH_KEYS $f
        end
    end
end
audit_path $HOME/.ssh/config "SSH config (hosts, keys, proxies)"
audit_path $HOME/.ssh/known_hosts "known_hosts"

aur_log ""
aur_log "## 2. Git / GitHub"
for p in $HOME/.git-credentials $HOME/.gitconfig $HOME/.config/gh/hosts.yml $HOME/.config/gh/config.yml $HOME/.config/git/credentials
    if audit_path $p (basename $p)
        set -a AUR_AUDIT_GIT_PATHS $p
    end
end

aur_log ""
aur_log "## 3. Docker / Podman / Kubernetes / AWS"
for p in $HOME/.docker/config.json $HOME/.config/containers/auth.json $HOME/.docker/.token_seed $HOME/.kube/config $HOME/.aws/credentials $HOME/.aws/config
    if audit_path $p (basename $p)
        set -a AUR_AUDIT_DOCKER_PATHS $p
    end
end

aur_log ""
aur_log "## 4. Browsers (cookies/sessions)"
audit_path "$HOME/.config/BraveSoftware/Brave-Browser/Default/Cookies" "Brave cookies"
audit_path "$HOME/.config/BraveSoftware/Brave-Browser/Default/Login Data" "Brave saved passwords"
audit_path "$HOME/.config/google-chrome/Default/Cookies" "Chrome cookies"
audit_path "$HOME/.config/google-chrome/Default/Login Data" "Chrome saved passwords"
audit_path "$HOME/.config/chromium/Default/Cookies" "Chromium cookies"
audit_path "$HOME/.config/Microsoft Edge/Default/Cookies" "Edge cookies"
audit_path "$HOME/.config/vivaldi/Default/Cookies" "Vivaldi cookies"
audit_path "$HOME/.config/opera/Default/Cookies" "Opera cookies"
audit_find $HOME/.mozilla/firefox cookies.sqlite "Firefox cookies"
audit_find $HOME/.mozilla/firefox logins.json "Firefox saved logins"

aur_log ""
aur_log "## 5. Chat / collaboration"
audit_path $HOME/.config/discord "Discord"
audit_path $HOME/.config/Slack "Slack"
audit_path "$HOME/.config/Microsoft/Microsoft Teams" "Microsoft Teams"
audit_find $HOME/.var/app/com.slack.Slack/config/Slack "*" "Slack Flatpak"
audit_find $HOME/.var/app/com.discordapp.Discord/config/discord "*" "Discord Flatpak"

aur_log ""
aur_log "## 6. npm / Node / IDE / password managers"
audit_path $HOME/.npmrc "npm token/config"
audit_path $HOME/.config/Cursor/User/globalStorage/state.vscdb "Cursor IDE state"
audit_path $HOME/.config/bws/data.json "Bitwarden Secrets Manager CLI"
audit_path $HOME/.config/Bitwarden\ CLI/data.json "Bitwarden CLI"
audit_find $HOME/.npm cookies.sqlite "npm cache artifact"

aur_log ""
aur_log "## 7. Vault / GPG / VPN"
audit_path $HOME/.vault-token "Vault token"
audit_path $HOME/.vault/token "Vault token (alt)"
audit_path $HOME/.gnupg/pubring.kbx "GPG keyring"
audit_find $HOME/.config .ovpn "OpenVPN profile"
audit_find $HOME/Downloads .ovpn "OpenVPN profile (Downloads)"
audit_path $HOME/.config/Tailscale/tailscaled.state "Tailscale state"
audit_find $HOME/.config/netbird .json "Netbird state"

aur_log ""
aur_log "## 8. Shell histories (secret pattern scan)"
for h in $HOME/.bash_history $HOME/.zsh_history $HOME/.local/share/fish/fish_history
    if test -f $h
        set -l hits (aur_history_secret_hits $h)
        if test "$hits" -gt 0
            aur_log "  [EXPOSED] $h — $hits potential secret references"
            set -a AUR_AUDIT_HISTORY_FILES $h
        else
            aur_log "  [OK]      $h — no obvious secret patterns"
        end
    end
end

aur_log ""
aur_log "## 9. Env / secret files under ~/dev"
set -l env_count 0
while read -l f
    set env_count (math $env_count + 1)
    set -a AUR_AUDIT_ENV_FILES $f
    if aur_env_has_secrets $f
        aur_log "  [EXPOSED] $f  (contains TOKEN/SECRET/PASSWORD keys)"
    else
        aur_log "  [EXPOSED] $f"
    end
end <(find $HOME/dev -maxdepth 5 \( -name '.env' -o -name 'secrets.env' -o -name 'stack.env' -o -name 'shared.env' -o -name 'harbor.yml' \) 2>/dev/null)

if test $env_count -eq 0
    aur_log "  [OK] No env/secret files found under ~/dev"
end

aur_log ""
aur_log "## 10. Env file triage (key names only, no values)"
set -l triage_count 0
for f in $AUR_AUDIT_ENV_FILES
    if not aur_env_has_secrets $f
        continue
    end
    set triage_count (math $triage_count + 1)
    aur_log "  $f:"
    while read -l line
        set -l key (string match -r '^(?:export\s+)?([A-Z0-9_]+)\s*=' $line)[2]
        if test -n "$key"
            if string match -qir '(TOKEN|SECRET|PASSWORD|API_KEY|APIKEY|PRIVATE|CREDENTIAL)' -- $key
                aur_log "    - $key=***"
            end
        end
    end <$f
end
if test $triage_count -eq 0
    aur_log "  [OK] No high-risk key names detected in env files"
end

aur_log ""
aur_log "## 11. Malware persistence (quick check)"
if test -e /sys/fs/bpf/hidden_pids
    aur_log "  [CRITICAL] eBPF rootkit maps present under /sys/fs/bpf/"
else
    aur_log "  [OK]       No eBPF rootkit maps"
end

set -l deps_found false
for candidate in (find $HOME /var/lib -name deps -perm -111 -size +1M 2>/dev/null)
    set -l hash (aur_sha256_file $candidate)
    if test "$hash" = $AUR_MALWARE_SHA256_DEPS
        aur_log "  [CRITICAL] deps ELF at $candidate"
        set deps_found true
    end
end
if test $deps_found = false
    aur_log "  [OK]       No known deps ELF binary"
end

aur_log ""
aur_log "=== Rotation checklist (derived from findings) ==="

if test (count $AUR_AUDIT_SSH_KEYS) -gt 0
    aur_log "SSH — rotate and re-deploy these private keys:"
    for k in $AUR_AUDIT_SSH_KEYS
        aur_log "  - $k"
    end
    aur_log "  Update authorized_keys on every host in ~/.ssh/known_hosts"
else
    aur_log "SSH — no private keys found"
end

if test (count $AUR_AUDIT_GIT_PATHS) -gt 0
    aur_log "Git/GitHub — revoke tokens and re-auth:"
    aur_log "  gh auth logout && gh auth login"
    for p in $AUR_AUDIT_GIT_PATHS
        aur_log "  - review $p"
    end
else
    aur_log "Git/GitHub — no credential stores found"
end

if test (count $AUR_AUDIT_DOCKER_PATHS) -gt 0
    aur_log "Docker/cloud — logout and rotate registry credentials:"
    aur_log "  docker logout  # for each registry in ~/.docker/config.json"
    for p in $AUR_AUDIT_DOCKER_PATHS
        aur_log "  - review $p"
    end
else
    aur_log "Docker/cloud — no credential stores found"
end

if test (count $AUR_AUDIT_ENV_FILES) -gt 0
    aur_log "Homelab — rotate secrets in "(count $AUR_AUDIT_ENV_FILES)" env files under ~/dev"
    aur_log "  Prioritize stacks with TOKEN/SECRET/PASSWORD keys (see section 10)"
else
    aur_log "Homelab — no env files under ~/dev"
end

if test (count $AUR_AUDIT_HISTORY_FILES) -gt 0
    aur_log "Shell history — rotate any credentials referenced in:"
    for h in $AUR_AUDIT_HISTORY_FILES
        aur_log "  - $h"
    end
    aur_log "  Scrub after rotation: fish $AUR_RESPONSE_DIR/scrub-history.fish"
else
    aur_log "Shell history — no obvious secret patterns"
end

aur_log ""
aur_log "Browser/chat — sign out all sessions; rotate Discord/Brave/saved passwords"
aur_log ""

set -l exposed_count (math (count $AUR_AUDIT_SSH_KEYS) + (count $AUR_AUDIT_GIT_PATHS) + (count $AUR_AUDIT_DOCKER_PATHS) + (count $AUR_AUDIT_ENV_FILES) + (count $AUR_AUDIT_HISTORY_FILES))
aur_summary_set credential_exposed $exposed_count
