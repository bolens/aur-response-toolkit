#!/usr/bin/env fish

# Cross-reference pacman logs with the infected list during the compromise window.
# Unlike check-infected-pkgs, this finds packages that were installed then removed.

set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
source $AUR_RESPONSE_DIR/lib/common.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan-pacman-timeline.fish [--local] [--report] [--quiet]"
            echo ""
            echo "Scan pacman logs for known infected packages during $AUR_WINDOW_LABEL."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv
aur_begin_report_if_requested pacman-timeline-

aur_log "=== Pacman install timeline (compromise window) ==="
aur_log "Scanning pacman logs for infected packages, $AUR_WINDOW_LABEL"
aur_log ""

if not aur_pacman_logs_accessible
    aur_insufficient_data "no readable pacman logs under /var/log/pacman.log*"
    aur_log_insufficient_help
    exit $AUR_EXIT_INSUFFICIENT
end

if not test -f $AUR_LIST_FILE
    aur_insufficient_data "$AUR_LIST_FILE missing"
    exit $AUR_EXIT_INSUFFICIENT
end

set -l events (mktemp)
aur_collect_window_alpm_events_all $events
set -l raw (aur_timeline_hits_from_events $events $AUR_LIST_FILE | string collect)
set -l hit_count (aur_safe_count "$raw")
rm -f $events

if test $hit_count -eq 0
    aur_log "[OK] No infected packages in pacman logs during compromise window"
else
    aur_mark_compromised
    aur_summary_set timeline_hits $hit_count
    aur_log "[FOUND] $hit_count timeline hit(s):"
    for hit in (string split \n -- "$raw")
        test -n "$hit"; or continue
        aur_finding_add timeline_hits $hit
        aur_log "  $hit"
    end
    aur_log ""
    # Removed packages still appear in logs — not automatically malicious; user must triage.
    aur_log "Removed packages still appear. Review each — upgrades during window may be benign"
    aur_log "if you intentionally updated that day (e.g. beef gaming pkg)."
    exit $AUR_EXIT_COMPROMISE
end

aur_log ""
exit $AUR_EXIT_CLEAN
