#!/usr/bin/env fish

# Cross-reference pacman logs with the Chaos RAT list during the Jul 16–18, 2025 window.
# Unlike check-chaos-rat-pkgs, this finds packages that were installed then removed.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan/chaos-rat-timeline.fish [--local] [--all-time] [--report] [--quiet]"
            echo ""
            echo "Scan pacman logs for known Chaos RAT packages during $AUR_CHAOS_RAT_WINDOW_LABEL."
            echo "  --all-time  Match Chaos RAT packages in logs at any date"
            echo "Opt in via --chaos-rat or AUR_ENABLE_CHAOS_RAT=1 in config."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv

if not aur_chaos_rat_enabled
    aur_log "Chaos RAT timeline skipped (use --chaos-rat or set AUR_ENABLE_CHAOS_RAT=1)"
    exit $AUR_EXIT_CLEAN
end

aur_run_optional_campaign_timeline chaos-rat
exit $status
