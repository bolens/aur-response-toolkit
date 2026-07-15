#!/usr/bin/env fish

# Cross-reference pacman logs with the 2018 xeactor list during Jun 7–Jul 10, 2018.
# Unlike check-xeactor-pkgs, this finds packages that were installed then removed.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan/xeactor-timeline.fish [--local] [--all-time] [--report] [--quiet]"
            echo ""
            echo "Scan pacman logs for known 2018 xeactor packages during $AUR_XEACTOR_WINDOW_LABEL."
            echo "  --all-time  Match xeactor packages in logs at any date"
            echo "Opt in via --xeactor or AUR_ENABLE_XEACTOR=1 in config."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv

if not aur_xeactor_enabled
    aur_log "xeactor timeline skipped (use --xeactor or set AUR_ENABLE_XEACTOR=1)"
    exit $AUR_EXIT_CLEAN
end

aur_run_optional_campaign_timeline xeactor
exit $status
