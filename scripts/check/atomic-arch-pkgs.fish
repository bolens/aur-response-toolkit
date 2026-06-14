#!/usr/bin/env fish

# Compare installed foreign packages against the merged infected list.
# HIGH risk = installed during compromise window; LOW = infected pkg but outside window.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: check/atomic-arch-pkgs.fish [--local] [--all-time] [--audit] [--report] [--quiet] [--no-chain]"
            echo ""
            echo "Check installed packages against the merged infected list."
            echo "  --all-time  Flag any installed infected package (ignore date window)"
            aur_common_flags_help
            echo "  --audit     Chain credential audit on findings"
            echo "  --no-chain  Skip chained credential audit"
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv

set -l no_chain false
for arg in $argv
    test "$arg" = --no-chain; and set no_chain true
end

aur_begin_report_if_requested atomic-arch-pkg-scan-

set -l exit_code $AUR_EXIT_CLEAN

set -l infected_pkgs (aur_load_and_read_atomic_arch_list $AUR_OPT_local)
if test $status -ne 0
    exit $AUR_EXIT_COMPROMISE
end

set -l pkg_count (count $infected_pkgs)
if test $pkg_count -eq 0
    aur_log "ERROR: parsed 0 packages, something went wrong."
    exit $AUR_EXIT_COMPROMISE
end

aur_log "Checking $pkg_count known infected packages..."
aur_log ""

set -l found (aur_installed_atomic_arch_pkgs $infected_pkgs)

set -g AUR_FOUND_PACKAGES $found
set -g AUR_FOUND_IN_WINDOW
set -g AUR_FOUND_OUTSIDE_WINDOW

if test (count $found) -gt 0
    set exit_code $AUR_EXIT_COMPROMISE
    aur_mark_compromised
    aur_summary_set atomic_arch_installed (count $found)
    aur_log "WARNING: "(count $found)" infected package(s) installed:"
    aur_log ""

    for pkg in $found
        aur_classify_atomic_arch_installed_pkg $pkg
    end
    aur_summary_set atomic_arch_high_risk (count $AUR_FOUND_IN_WINDOW)

    aur_log ""
    aur_log "Suggested removal:"
    aur_log "  fish (aur_script_path recovery/remove-packages.fish)"
    aur_log "  # or: sudo pacman -Rns "(string join ' ' $found)
else
    aur_log "Clean: none of the known infected packages are installed."
end

# Chain credential audit when infected pkgs found, or when --audit forces it.
if test $no_chain = false; and test (count $found) -gt 0 -o $AUR_OPT_audit = true
    set -l audit_args (aur_build_step_args)
    test (count $found) -gt 0; or set -a audit_args --if-compromised
    fish (aur_script_path audit/stolen-credentials.fish) $audit_args
    set -l audit_status $status
    # Preserve compromise exit (1) over audit warn (2) when both fire.
    if test $audit_status -ne $AUR_EXIT_CLEAN; and test $exit_code -eq $AUR_EXIT_CLEAN
        set exit_code $audit_status
    end
end

exit $exit_code
