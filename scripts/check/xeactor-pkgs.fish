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

aur_begin_report_if_requested xeactor-pkg-scan-

set -l exit_code $AUR_EXIT_CLEAN

set -l xeactor_pkgs (aur_load_xeactor_list $AUR_OPT_local)
if test $status -ne 0
    exit $AUR_EXIT_INSUFFICIENT
end

set -l pkg_count (count $xeactor_pkgs)
if test $pkg_count -eq 0
    aur_log "ERROR: parsed 0 xeactor packages, something went wrong."
    exit $AUR_EXIT_INSUFFICIENT
end

if test $AUR_OPT_all_time = true
    aur_log "Checking $pkg_count known 2018 xeactor packages (--all-time; ignoring $AUR_XEACTOR_WINDOW_LABEL)"
else
    aur_log "Checking $pkg_count known 2018 xeactor packages ($AUR_XEACTOR_WINDOW_LABEL window)..."
end
aur_log ""

set -l found (aur_installed_xeactor_pkgs)

set -g AUR_XEACTOR_FOUND_IN_WINDOW
set -g AUR_XEACTOR_FOUND_OUTSIDE_WINDOW

if test (count $found) -gt 0
    set exit_code $AUR_EXIT_WARN
    aur_summary_set xeactor_installed (count $found)
    aur_log "WARNING: "(count $found)" xeactor package(s) installed:"
    aur_log ""

    for pkg in $found
        aur_classify_xeactor_pkg $pkg
    end
    aur_summary_set xeactor_high_risk (count $AUR_XEACTOR_FOUND_IN_WINDOW)

    aur_log ""
    aur_log "Suggested removal (review HIGH first; separate 2018 xeactor incident):"
    aur_log "  fish (aur_script_path recovery/remove-packages.fish) --list xeactor"
    aur_log "  # or: sudo pacman -Rns "(string join ' ' $found)
else
    aur_log "Clean: none of the known 2018 xeactor packages are installed."
end

exit $exit_code
