#!/usr/bin/env fish

set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
source $AUR_RESPONSE_DIR/lib/common.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: check-infected-pkgs.fish [--local] [--audit] [--report] [--quiet] [--no-chain]"
            echo ""
            echo "Check installed packages against the merged infected list."
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

aur_begin_report_if_requested infected-pkg-scan-

set -l exit_code 0

set -l infected_pkgs (aur_load_infected_list $AUR_OPT_local)
if test $status -ne 0
    exit 1
end

set -l pkg_count (count $infected_pkgs)
if test $pkg_count -eq 0
    aur_log "ERROR: parsed 0 packages, something went wrong."
    exit 1
end

aur_log "Checking $pkg_count known infected packages..."
aur_log ""

set -l installed_sorted (mktemp)
set -l infected_sorted (mktemp)
pacman -Qmq | sort >$installed_sorted
string join \n -- $infected_pkgs | sort >$infected_sorted
set -l found (comm -12 $installed_sorted $infected_sorted)
rm -f $installed_sorted $infected_sorted

set -g AUR_FOUND_PACKAGES $found
set -g AUR_FOUND_IN_WINDOW
set -g AUR_FOUND_OUTSIDE_WINDOW

if test (count $found) -gt 0
    set exit_code 1
    aur_summary_set installed_infected (count $found)
    aur_log "WARNING: "(count $found)" infected package(s) installed:"
    aur_log ""

    for pkg in $found
        set -l install_date (aur_pkg_install_date $pkg)
        set -l install_reason (aur_pkg_install_reason $pkg)
        if aur_install_in_compromise_window $pkg
            set -a AUR_FOUND_IN_WINDOW $pkg
            aur_log "  [HIGH]   $pkg"
            aur_log "           installed: $install_date | reason: $install_reason"
        else
            set -a AUR_FOUND_OUTSIDE_WINDOW $pkg
            aur_log "  [LOW]    $pkg"
            aur_log "           installed: $install_date | reason: $install_reason (outside $AUR_WINDOW_LABEL)"
        end
    end
    aur_summary_set installed_high_risk (count $AUR_FOUND_IN_WINDOW)

    aur_log ""
    aur_log "Suggested removal:"
    aur_log "  fish $AUR_SCRIPTS_DIR/remove-infected.fish"
    aur_log "  # or: sudo pacman -Rns "(string join ' ' $found)
else
    aur_log "Clean: none of the known infected packages are installed."
end

if test $no_chain = false; and test (count $found) -gt 0 -o $AUR_OPT_audit = true
    set -l audit_args
    test $AUR_OPT_report = true; and set audit_args --report
    test $AUR_OPT_quiet = true; and set -a audit_args --quiet
    fish $AUR_SCRIPTS_DIR/audit-stolen-credentials.fish $audit_args
    set -l audit_status $status
    test $audit_status -ne 0; and set exit_code $audit_status
end

exit $exit_code
