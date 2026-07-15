#!/usr/bin/env fish

# Compare installed foreign packages against the Mini Shai-Hulud AUR list.
# HIGH risk = installed during May 16–17, 2026; LOW = list match but outside window.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: check/shai-hulud-pkgs.fish [--local] [--all-time] [--report] [--quiet]"
            echo ""
            echo "Check installed packages against the Mini Shai-Hulud AUR package list."
            echo "  --all-time  Flag any installed Shai-Hulud package (ignore $AUR_SHAI_HULUD_WINDOW_LABEL window)"
            echo "Opt in via --shai-hulud or AUR_ENABLE_SHAI_HULUD=1 in config."
            echo "Findings exit 2 (warn) unless --fail-on suppresses warnings."
            echo ""
            echo "IMPORTANT: if gh-token-monitor persistence is present, disable it BEFORE rotating GitHub tokens."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv

if not aur_shai_hulud_enabled
    aur_log "Shai-Hulud scan skipped (use --shai-hulud or set AUR_ENABLE_SHAI_HULUD=1)"
    exit $AUR_EXIT_CLEAN
end

aur_run_optional_campaign_pkg_check shai-hulud
exit $status
