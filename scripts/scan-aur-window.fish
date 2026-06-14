#!/usr/bin/env fish

# All foreign (AUR) packages touched during compromise window — catches unknowns not yet on list.
# Exit 1 = critical unknown triage; exit 2 = benign unknowns needing manual review; exit 0 = clean.

set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
source $AUR_RESPONSE_DIR/lib/common.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan-aur-window.fish [--local] [--report] [--quiet] [--quick]"
            echo ""
            echo "List foreign packages touched in pacman logs during $AUR_WINDOW_LABEL."
            echo "Unknown packages with benign triage exit 2 (warn); malicious/critical exit 1."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv
aur_begin_report_if_requested aur-window-

aur_log "=== AUR activity window scan ==="
aur_log "Foreign packages installed/upgraded $AUR_WINDOW_LABEL (any pkg)"
aur_log ""

if not aur_pacman_logs_accessible
    aur_insufficient_data "no readable pacman logs under /var/log/pacman.log*"
    aur_log_insufficient_help
    exit $AUR_EXIT_INSUFFICIENT
end

set -l events (mktemp)
set -l foreign_sorted (mktemp)
set -l infected_sorted (mktemp)
set -l unknown_file (mktemp)

aur_collect_window_alpm_events_all $events
aur_foreign_package_names | sort >$foreign_sorted

if test -f $AUR_LIST_FILE
    sort -u $AUR_LIST_FILE >$infected_sorted
end

set -l raw (aur_foreign_packages_in_window $events $foreign_sorted | string collect)
set -l foreign_count (aur_safe_count "$raw")
if test $foreign_count -eq 0
    rm -f $events $foreign_sorted $infected_sorted $unknown_file
    aur_log "[OK] No foreign package activity in compromise window"
    exit $AUR_EXIT_CLEAN
end

aur_summary_set window_aur_pkgs $foreign_count
aur_log "[INFO] $foreign_count foreign package(s) touched during window:"

set -l critical_unknown 0
set -l unknown_count 0

for pkg in (string split \n -- "$raw")
    test -n "$pkg"; or continue
    set -l grep_hit (aur_grep -m1 -F "$pkg|" $events)
    set -l line (aur_event_line_from_hit "$grep_hit")
    if test -f $infected_sorted; and aur_grep -Fxq -- $pkg $infected_sorted
        aur_log "  [KNOWN]  $pkg"
    else
        aur_log "  [NEW?]   $pkg  — not on infected list, investigating"
        aur_finding_add unknown_window_pkgs $pkg
        echo $pkg >>$unknown_file
        set unknown_count (math $unknown_count + 1)
        # aur_triage_unknown_pkg exit 0 = critical (hooks or window install); stdout = issue lines.
        set -l triage_raw (aur_triage_unknown_pkg $pkg)
        set -l triage_critical (test $status -eq 0; and echo true; or echo false)
        set -l triage (string collect $triage_raw)
        if test -n "$triage"
            for tline in (string split \n -- "$triage")
                test -n "$tline"; or continue
                aur_log "           triage: $tline"
            end
        end
        if test $triage_critical = true
            set critical_unknown (math $critical_unknown + 1)
            aur_log "           severity: CRITICAL"
        else
            aur_log "           severity: review (benign triage)"
        end
    end
    aur_log "           $line"
end

rm -f $events $foreign_sorted $infected_sorted $unknown_file

if test $critical_unknown -gt 0
    aur_log ""
    aur_log "$critical_unknown unknown package(s) with critical triage — treat as compromise."
    aur_mark_compromised
    exit $AUR_EXIT_COMPROMISE
end

# Benign unknowns (not on list, no malicious hooks) still warrant review but are not compromise.
if test $unknown_count -gt 0
    aur_log ""
    aur_log "$unknown_count unknown package(s) in window with benign triage — manual review recommended."
    exit $AUR_EXIT_WARN
end

aur_log ""
exit $AUR_EXIT_CLEAN
