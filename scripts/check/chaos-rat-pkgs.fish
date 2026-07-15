#!/usr/bin/env fish

# Compare installed foreign packages against the Chaos RAT / cracked-software list.
# HIGH risk = installed during Jul 16–18, 2025; LOW = list match but outside window.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: check/chaos-rat-pkgs.fish [--local] [--all-time] [--report] [--quiet]"
            echo ""
            echo "Check installed packages against the Chaos RAT AUR package list."
            echo "  --all-time  Flag any installed Chaos RAT package (ignore $AUR_CHAOS_RAT_WINDOW_LABEL window)"
            echo "Opt in via --chaos-rat or AUR_ENABLE_CHAOS_RAT=1 in config."
            echo "Findings exit 2 (warn) unless --fail-on suppresses warnings."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv

if not aur_chaos_rat_enabled
    aur_log "Chaos RAT scan skipped (use --chaos-rat or set AUR_ENABLE_CHAOS_RAT=1)"
    exit $AUR_EXIT_CLEAN
end

aur_run_optional_campaign_pkg_check chaos-rat
exit $status
