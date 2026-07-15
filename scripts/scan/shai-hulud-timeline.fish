#!/usr/bin/env fish

# Cross-reference pacman logs with the Shai-Hulud list during the May 16–17, 2026 window.
# Unlike check-shai-hulud-pkgs, this finds packages that were installed then removed.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan/shai-hulud-timeline.fish [--local] [--all-time] [--report] [--quiet]"
            echo ""
            echo "Scan pacman logs for known Shai-Hulud packages during $AUR_SHAI_HULUD_WINDOW_LABEL."
            echo "  --all-time  Match Shai-Hulud packages in logs at any date"
            echo "Opt in via --shai-hulud or AUR_ENABLE_SHAI_HULUD=1 in config."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv

if not aur_shai_hulud_enabled
    aur_log "Shai-Hulud timeline skipped (use --shai-hulud or set AUR_ENABLE_SHAI_HULUD=1)"
    exit $AUR_EXIT_CLEAN
end

aur_run_optional_campaign_timeline shai-hulud
exit $status
