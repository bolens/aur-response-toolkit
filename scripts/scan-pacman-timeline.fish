#!/usr/bin/env fish

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

set -l has_log false
for log_path in (aur_pacman_log_paths)
    set has_log true
    break
end
if test $has_log = false
    aur_log "WARN: no pacman logs found under /var/log/pacman.log*"
    exit 0
end

if not test -f $AUR_LIST_FILE
    aur_log "WARN: $AUR_LIST_FILE missing"
    exit 0
end

set -l events (mktemp)
aur_collect_window_alpm_events_all $events
set -l raw (aur_timeline_hits_from_events $events $AUR_LIST_FILE | string collect)
set -l hit_count (aur_safe_count "$raw")
rm -f $events

if test $hit_count -eq 0
    aur_log "[OK] No infected packages in pacman logs during compromise window"
else
    aur_summary_set timeline_hits $hit_count
    aur_log "[FOUND] $hit_count timeline hit(s):"
    string split \n -- "$raw" | while read -l hit
        test -n "$hit"; and aur_log "  $hit"
    end
    aur_log ""
    aur_log "Removed packages still appear. Review each — upgrades during window may be benign"
    aur_log "if you intentionally updated that day (e.g. beef gaming pkg)."
    exit 1
end

aur_log ""
