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

aur_begin_report_if_requested shai-hulud-pkg-scan-

set -l exit_code $AUR_EXIT_CLEAN

set -l shai_pkgs (aur_load_shai_hulud_list $AUR_OPT_local)
if test $status -ne 0
    exit $AUR_EXIT_INSUFFICIENT
end

set -l pkg_count (count $shai_pkgs)
if test $pkg_count -eq 0
    aur_log "ERROR: parsed 0 Shai-Hulud packages, something went wrong."
    exit $AUR_EXIT_INSUFFICIENT
end

if test $AUR_OPT_all_time = true
    aur_log "Checking $pkg_count known Shai-Hulud packages (--all-time; ignoring $AUR_SHAI_HULUD_WINDOW_LABEL)"
else
    aur_log "Checking $pkg_count known Shai-Hulud packages ($AUR_SHAI_HULUD_WINDOW_LABEL window)..."
end
aur_log ""

set -l found (aur_installed_shai_hulud_pkgs)

set -g AUR_SHAI_HULUD_FOUND_IN_WINDOW
set -g AUR_SHAI_HULUD_FOUND_OUTSIDE_WINDOW

if test (count $found) -gt 0
    set exit_code $AUR_EXIT_WARN
    aur_summary_set shai_hulud_installed (count $found)
    aur_log "WARNING: "(count $found)" Shai-Hulud package(s) installed:"
    aur_log ""

    for pkg in $found
        aur_classify_shai_hulud_pkg $pkg
    end
    aur_summary_set shai_hulud_high_risk (count $AUR_SHAI_HULUD_FOUND_IN_WINDOW)

    aur_log ""
    aur_log "Suggested removal (review HIGH first; separate threat from Atomic Arch):"
    aur_log "  fish (aur_script_path recovery/remove-packages.fish) --list shai-hulud"
    aur_log "  # or: sudo pacman -Rns "(string join ' ' $found)
    aur_log ""
    aur_log "Before rotating GitHub tokens: stop gh-token-monitor if present (see scan/malware-artifacts.fish)."
else
    aur_log "Clean: none of the known Shai-Hulud packages are installed."
end

exit $exit_code
