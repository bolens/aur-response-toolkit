#!/usr/bin/env fish

# Non-compromise warnings: npm ignore-scripts, AUR helper auto-install settings, IOC history refs.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan/hardening.fish [--report] [--quiet]"
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

# npm ignore-scripts (.npmrc + npm config)
if aur_npm_ignore_scripts_enabled
    if test -f $HOME/.npmrc; and string match -qir 'ignore-scripts\s*=\s*true' (cat $HOME/.npmrc)
        aur_log "[OK] npm ignore-scripts=true in ~/.npmrc"
    else
        aur_log "[OK] npm config ignore-scripts=true"
    end
else
    aur_log "[WARN] npm ignore-scripts not enabled — add to ~/.npmrc:"
    aur_log "       ignore-scripts=true"
    set warns (math $warns + 1)
end

# bun on PATH and env hooks
if command -q bun
    aur_log "[INFO] bun found at "(command -v bun)" — optional; review if installed during $AUR_WINDOW_LABEL"
else
    aur_log "[OK] bun not on PATH"
end
if set -q BUN_INSTALL
    aur_log "[WARN] BUN_INSTALL is set ($BUN_INSTALL) — bun hook env present"
    set warns (math $warns + 1)
end
if set -q BUN_INSTALL_BIN
    aur_log "[WARN] BUN_INSTALL_BIN is set ($BUN_INSTALL_BIN) — bun hook env present"
    set warns (math $warns + 1)
end

# AUR helper review settings (paru, yay, pamac, trizen, aura, aurman)
for cfg in (aur_helper_hardening_config_paths)
    if not test -f $cfg
        continue
    end
    if string match -qir 'NoReview|noconfirm|NoConfirm|noConfirm|NoEdit' (cat $cfg)
        aur_log "[WARN] $cfg may skip PKGBUILD review (NoReview/noconfirm/NoConfirm/NoEdit)"
        set warns (math $warns + 1)
    else
        aur_log "[OK] $cfg — no obvious auto-install flags"
    end
end

# AUR helper --noconfirm / --no-confirm in shell history during compromise window
aur_log ""
aur_log "=== AUR helper usage during compromise window ==="
set -l noconfirm_hits 0
# Only [WARN] when risky flags correlate with foreign pkg activity in the window.
for h in (aur_shell_history_paths)
    if aur_history_noconfirm_during_window $h
        aur_log "  [WARN] AUR helper auto-install flags in $h and foreign AUR activity during $AUR_WINDOW_LABEL"
        set noconfirm_hits (math $noconfirm_hits + 1)
        set warns (math $warns + 1)
    else if aur_history_has_noconfirm_aur $h
        aur_log "  [INFO] AUR helper auto-install flags in $h (no correlated window activity)"
    end
end
if test $noconfirm_hits -eq 0
    aur_log "  [OK] No risky AUR helper installs logged during window"
end

# IOC references in shell history
aur_log ""
aur_log "=== Network IOC references in shell history ==="
set -l ioc_hits 0
for domain in $AUR_IOC_DOMAINS
    for h in (aur_shell_history_paths)
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
    exit $AUR_EXIT_WARN
end
aur_log "Hardening checks passed"
exit $AUR_EXIT_CLEAN
