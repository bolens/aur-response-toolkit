#!/usr/bin/env fish

# Cross-reference pacman logs with the 2018 xeactor list during Jun 7–Jul 10, 2018.
# Unlike check-xeactor-pkgs, this finds packages that were installed then removed.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan/xeactor-timeline.fish [--local] [--all-time] [--report] [--quiet]"
            echo ""
            echo "Scan pacman logs for known 2018 xeactor packages during $AUR_XEACTOR_WINDOW_LABEL."
            echo "  --all-time  Match xeactor packages in logs at any date"
            echo "Opt in via --xeactor or AUR_ENABLE_XEACTOR=1 in config."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv

if not aur_xeactor_enabled
    aur_log "xeactor timeline skipped (use --xeactor or set AUR_ENABLE_XEACTOR=1)"
    exit $AUR_EXIT_CLEAN
end

aur_begin_report_if_requested xeactor-timeline-

aur_log "=== xeactor pacman install timeline ==="
if test $AUR_OPT_all_time = true
    aur_log "Scanning pacman logs for 2018 xeactor packages (all dates; --all-time)"
else
    aur_log "Scanning pacman logs for 2018 xeactor packages, $AUR_XEACTOR_WINDOW_LABEL"
end
aur_log ""

aur_require_pacman_logs

set -l list_file (aur_xeactor_list_file_path)
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
    aur_collect_xeactor_window_alpm_events_all $events
end

set -l raw (aur_timeline_hits_from_events $events $list_file | string collect)
set -l hit_count (aur_safe_count "$raw")

set -l repeat_events (mktemp)
set -l saved_all_time $AUR_OPT_all_time
set -g AUR_OPT_all_time false
aur_collect_xeactor_window_alpm_events_all $repeat_events
set -g AUR_OPT_all_time $saved_all_time
aur_report_timeline_repeat_updates $repeat_events $list_file xeactor_timeline_repeat_updates xeactor_timeline_repeat_updates "during $AUR_XEACTOR_WINDOW_LABEL"
rm -f $repeat_events $events

if test $hit_count -eq 0
    aur_log "[OK] No xeactor packages in pacman logs during $AUR_XEACTOR_WINDOW_LABEL"
else
    aur_summary_set xeactor_timeline_hits $hit_count
    aur_log "[FOUND] $hit_count xeactor timeline hit(s):"
    for hit in (string split \n -- "$raw")
        test -n "$hit"; or continue
        aur_finding_add xeactor_timeline_hits $hit
        aur_log "  $hit"
    end
    aur_log ""
    aur_log "Removed packages still appear. Review each — only installs during the attack window are HIGH risk."
    exit $AUR_EXIT_WARN
end

aur_log ""
exit $AUR_EXIT_CLEAN
