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

aur_begin_report_if_requested chaos-rat-pkg-scan-

set -l exit_code $AUR_EXIT_CLEAN

set -l chaos_pkgs (aur_load_chaos_rat_list $AUR_OPT_local)
if test $status -ne 0
    exit $AUR_EXIT_INSUFFICIENT
end

set -l pkg_count (count $chaos_pkgs)
if test $pkg_count -eq 0
    aur_log "ERROR: parsed 0 Chaos RAT packages, something went wrong."
    exit $AUR_EXIT_INSUFFICIENT
end

if test $AUR_OPT_all_time = true
    aur_log "Checking $pkg_count known Chaos RAT packages (--all-time; ignoring $AUR_CHAOS_RAT_WINDOW_LABEL)"
else
    aur_log "Checking $pkg_count known Chaos RAT packages ($AUR_CHAOS_RAT_WINDOW_LABEL window)..."
end
aur_log ""

set -l found (aur_installed_chaos_rat_pkgs)

set -g AUR_CHAOS_RAT_FOUND_IN_WINDOW
set -g AUR_CHAOS_RAT_FOUND_OUTSIDE_WINDOW

if test (count $found) -gt 0
    set exit_code $AUR_EXIT_WARN
    aur_summary_set chaos_rat_installed (count $found)
    aur_log "WARNING: "(count $found)" Chaos RAT package(s) installed:"
    aur_log ""

    for pkg in $found
        aur_classify_chaos_rat_pkg $pkg
    end
    aur_summary_set chaos_rat_high_risk (count $AUR_CHAOS_RAT_FOUND_IN_WINDOW)

    aur_log ""
    aur_log "Suggested removal (review HIGH first; separate threat from Atomic Arch):"
    aur_log "  fish (aur_script_path recovery/remove-packages.fish) --list chaos-rat"
    aur_log "  # or: sudo pacman -Rns "(string join ' ' $found)
else
    aur_log "Clean: none of the known Chaos RAT packages are installed."
end

exit $exit_code
