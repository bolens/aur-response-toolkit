#!/usr/bin/env fish

# Apply recommended post-incident hardening (non-destructive by default)

set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
source $AUR_RESPONSE_DIR/lib/common.fish

set -l apply false
for arg in $argv
    switch $arg
        case --apply
            set apply true
        case --help -h
            echo "Usage: apply-hardening.fish [--apply]"
            echo ""
            echo "Show or apply hardening recommendations from scan-hardening.fish."
            echo "  --apply  Write ignore-scripts=true to ~/.npmrc if missing"
            exit 0
        case '-*'
            echo "Unknown option: $arg" >&2
            exit $AUR_EXIT_INVALID
    end
end

aur_log "=== Apply hardening recommendations ==="
aur_log ""

set -l changed false

# ignore-scripts blocks npm lifecycle hooks — the primary vector for atomic-lockfile/js-digest.
if test -f $HOME/.npmrc
    if string match -qir 'ignore-scripts\s*=\s*true' (cat $HOME/.npmrc)
        aur_log "[OK] ~/.npmrc already has ignore-scripts=true"
    else if test $apply = true
        echo 'ignore-scripts=true' >>$HOME/.npmrc
        aur_log "[APPLIED] Added ignore-scripts=true to ~/.npmrc"
        set changed true
    else
        aur_log "[DRY-RUN] Would append ignore-scripts=true to ~/.npmrc (use --apply)"
    end
else if test $apply = true
    echo 'ignore-scripts=true' >$HOME/.npmrc
    aur_log "[APPLIED] Created ~/.npmrc with ignore-scripts=true"
    set changed true
else
    aur_log "[DRY-RUN] Would create ~/.npmrc with ignore-scripts=true (use --apply)"
end

aur_log ""
aur_log "paru: ensure PKGBUILD review is enabled (avoid NoReview = All in paru.conf)"
aur_log "yay:  avoid \"noconfirm\": true in ~/.config/yay/config.json"
aur_log "      Review PKGBUILDs before building any AUR package."
aur_log ""
aur_log "Optional: fish $AUR_SCRIPTS_DIR/scan-hardening.fish"

if test $changed = true
    exit $AUR_EXIT_CLEAN
end
exit $AUR_EXIT_CLEAN
