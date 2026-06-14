#!/usr/bin/env fish

set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
source $AUR_RESPONSE_DIR/lib/common.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan-hardening.fish [--report] [--quiet]"
            echo ""
            echo "Check npm ignore-scripts, AUR helper review settings, and IOC history refs."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv
aur_begin_report_if_requested hardening-

set -l warns 0

aur_log "=== Build environment hardening ==="
aur_log ""

# npm ignore-scripts
if test -f $HOME/.npmrc
    if string match -qir 'ignore-scripts\s*=\s*true' (cat $HOME/.npmrc)
        aur_log "[OK] npm ignore-scripts=true in ~/.npmrc"
    else
        aur_log "[WARN] npm ignore-scripts not enabled — add to ~/.npmrc:"
        aur_log "       ignore-scripts=true"
        set warns (math $warns + 1)
    end
else
    aur_log "[WARN] No ~/.npmrc — create one with ignore-scripts=true"
    set warns (math $warns + 1)
end

# paru/yay review settings
for cfg in $HOME/.config/paru/paru.conf $HOME/.config/yay/config.json
    if not test -f $cfg
        continue
    end
    if string match -qir 'NoReview|noconfirm' (cat $cfg)
        aur_log "[WARN] $cfg may skip PKGBUILD review (NoReview/noconfirm)"
        set warns (math $warns + 1)
    else
        aur_log "[OK] $cfg — no obvious auto-install flags"
    end
end

# bun on PATH (used in js-digest wave)
if command -q bun
    aur_log "[INFO] bun found at "(command -v bun)" — optional; review if installed during $AUR_WINDOW_LABEL"
else
    aur_log "[OK] bun not on PATH"
end

# IOC references in shell history
aur_log ""
aur_log "=== Network IOC references in shell history ==="
set -l ioc_hits 0
for domain in $AUR_IOC_DOMAINS
    for h in $HOME/.bash_history $HOME/.zsh_history $HOME/.local/share/fish/fish_history
        if not test -f $h
            continue
        end
        if string match -qir $domain (cat $h 2>/dev/null)
            aur_log "  [INFO] $domain referenced in $h"
            set ioc_hits (math $ioc_hits + 1)
        end
    end
end
if test $ioc_hits -eq 0
    aur_log "  [OK] No IOC domains in shell histories"
end

aur_summary_set hardening_warn $warns
aur_log ""
if test $warns -gt 0
    aur_log "$warns hardening warning(s) — see above"
    exit 1
end
aur_log "Hardening checks passed"
exit 0
