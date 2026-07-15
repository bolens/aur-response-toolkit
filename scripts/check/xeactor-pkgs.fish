#!/usr/bin/env fish

# Compare installed foreign packages against the 2018 xeactor AUR list.
# HIGH risk = installed during Jun 7–Jul 10, 2018; LOW = list match but outside window.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: check/xeactor-pkgs.fish [--local] [--all-time] [--report] [--quiet]"
            echo ""
            echo "Check installed packages against the 2018 xeactor AUR package list."
            echo "  --all-time  Flag any installed xeactor package (ignore $AUR_XEACTOR_WINDOW_LABEL window)"
            echo "Opt in via --xeactor or AUR_ENABLE_XEACTOR=1 in config."
            echo "Findings exit 2 (warn) unless --fail-on suppresses warnings."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv

if not aur_xeactor_enabled
    aur_log "xeactor scan skipped (use --xeactor or set AUR_ENABLE_XEACTOR=1)"
    exit $AUR_EXIT_CLEAN
end

aur_run_optional_campaign_pkg_check xeactor
exit $status
