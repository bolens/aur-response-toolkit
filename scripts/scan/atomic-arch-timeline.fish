#!/usr/bin/env fish

# Cross-reference pacman logs with the infected list during the compromise window.
# Unlike check/atomic-arch-pkgs.fish, this finds packages that were installed then removed.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan/atomic-arch-timeline.fish [--local] [--all-time] [--report] [--quiet]"
            echo ""
            echo "Scan pacman logs for known infected packages during $AUR_WINDOW_LABEL."
            echo "  --all-time  Match infected packages in logs at any date"
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv
aur_begin_report_if_requested atomic-arch-timeline-

aur_log "=== Pacman install timeline ==="
if test $AUR_OPT_all_time = true
    aur_log "Scanning pacman logs for infected packages (all dates; --all-time)"
else
    aur_log "Scanning pacman logs for infected packages, $AUR_WINDOW_LABEL"
end
aur_log ""

aur_require_pacman_logs

if not test -f (aur_atomic_arch_list_file_path)
    set -l list_file (aur_atomic_arch_list_file_path)
    aur_insufficient_data "$list_file missing"
    exit $AUR_EXIT_INSUFFICIENT
end

set -l events (mktemp)
aur_collect_window_alpm_events_all $events
set -l list_file (aur_atomic_arch_list_file_path)
set -l raw (aur_timeline_hits_from_events $events $list_file | string collect)
set -l hit_count (aur_safe_count "$raw")

set -l repeat_events (mktemp)
aur_collect_attack_window_alpm_events_all $repeat_events
set -l repeat_found false
if aur_report_timeline_repeat_updates $repeat_events $list_file atomic_arch_timeline_repeat_updates atomic_arch_timeline_repeat_updates "during $AUR_WINDOW_LABEL"
    set repeat_found true
end
rm -f $repeat_events $events

if test $hit_count -eq 0
    aur_log "[OK] No infected packages in pacman logs during compromise window"
else
    aur_mark_compromised
    aur_summary_set atomic_arch_timeline_hits $hit_count
    aur_log "[FOUND] $hit_count timeline hit(s):"
    for hit in (string split \n -- "$raw")
        test -n "$hit"; or continue
        aur_finding_add atomic_arch_timeline_hits $hit
        aur_log "  $hit"
    end
    if test $repeat_found = true
        aur_log ""
        aur_log "[REPEAT] Known infected package(s) updated more than once during the window."
        aur_log "         Treat the earliest update as highest risk — a later update may be clean post-takedown."
    end
    aur_log ""
    # Removed packages still appear in logs — not automatically malicious; user must triage.
    aur_log "Removed packages still appear. Review each — upgrades during window may be benign"
    aur_log "if you intentionally updated that day (e.g. beef gaming pkg)."
    exit $AUR_EXIT_COMPROMISE
end

aur_log ""
exit $AUR_EXIT_CLEAN
