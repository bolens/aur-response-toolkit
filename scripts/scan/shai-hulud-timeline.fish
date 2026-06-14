#!/usr/bin/env fish

# Cross-reference pacman logs with the Shai-Hulud list during the May 16–17, 2026 window.
# Unlike check-shai-hulud-pkgs, this finds packages that were installed then removed.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan/shai-hulud-timeline.fish [--local] [--all-time] [--report] [--quiet]"
            echo ""
            echo "Scan pacman logs for known Shai-Hulud packages during $AUR_SHAI_HULUD_WINDOW_LABEL."
            echo "  --all-time  Match Shai-Hulud packages in logs at any date"
            echo "Opt in via --shai-hulud or AUR_ENABLE_SHAI_HULUD=1 in config."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv

if not aur_shai_hulud_enabled
    aur_log "Shai-Hulud timeline skipped (use --shai-hulud or set AUR_ENABLE_SHAI_HULUD=1)"
    exit $AUR_EXIT_CLEAN
end

aur_begin_report_if_requested shai-hulud-timeline-

aur_log "=== Shai-Hulud pacman install timeline ==="
if test $AUR_OPT_all_time = true
    aur_log "Scanning pacman logs for Shai-Hulud packages (all dates; --all-time)"
else
    aur_log "Scanning pacman logs for Shai-Hulud packages, $AUR_SHAI_HULUD_WINDOW_LABEL"
end
aur_log ""

aur_require_pacman_logs

set -l list_file (aur_shai_hulud_list_file_path)
if not test -f $list_file
    aur_insufficient_data "$list_file missing"
    exit $AUR_EXIT_INSUFFICIENT
end

set -l events (mktemp)
if test $AUR_OPT_all_time = true
    for log_path in (aur_pacman_log_paths)
        aur_read_pacman_log $log_path | while read -l line
            aur_is_alpm_install_line $line; or continue
            set -l pkg (aur_extract_alpm_pkg_from_line $line)
            test -n "$pkg"; or continue
            echo "$pkg|$line" >>$events
        end
    end
else
    aur_collect_shai_hulud_window_alpm_events_all $events
end

set -l raw (aur_timeline_hits_from_events $events $list_file | string collect)
set -l hit_count (aur_safe_count "$raw")
rm -f $events

if test $hit_count -eq 0
    aur_log "[OK] No Shai-Hulud packages in pacman logs during $AUR_SHAI_HULUD_WINDOW_LABEL"
else
    aur_summary_set shai_hulud_timeline_hits $hit_count
    aur_log "[FOUND] $hit_count Shai-Hulud timeline hit(s):"
    for hit in (string split \n -- "$raw")
        test -n "$hit"; or continue
        aur_finding_add shai_hulud_timeline_hits $hit
        aur_log "  $hit"
    end
    set -l repeat_events (mktemp)
    set -l saved_all_time $AUR_OPT_all_time
    set -g AUR_OPT_all_time false
    aur_collect_shai_hulud_window_alpm_events_all $repeat_events
    set -g AUR_OPT_all_time $saved_all_time
    aur_report_timeline_repeat_updates $repeat_events $list_file shai_hulud_timeline_repeat_updates shai_hulud_timeline_repeat_updates "during $AUR_SHAI_HULUD_WINDOW_LABEL"
    rm -f $repeat_events
    aur_log ""
    aur_log "Removed packages still appear. Review each — only installs during the attack window are HIGH risk."
    exit $AUR_EXIT_WARN
end

aur_log ""
exit $AUR_EXIT_CLEAN
