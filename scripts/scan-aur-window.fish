#!/usr/bin/env fish

# All foreign (AUR) packages touched during compromise window — catches unknowns not yet on list

set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
source $AUR_RESPONSE_DIR/lib/common.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan-aur-window.fish [--local] [--report] [--quiet]"
            echo ""
            echo "List foreign packages touched in pacman logs during $AUR_WINDOW_LABEL."
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

set -l has_log false
for log_path in (aur_pacman_log_paths)
    set has_log true
    break
end
if test $has_log = false
    aur_log "WARN: no pacman logs found under /var/log/pacman.log*"
    exit 0
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
    exit 0
end

aur_summary_set window_aur_pkgs $foreign_count
aur_log "[INFO] $foreign_count foreign package(s) touched during window:"

string split \n -- "$raw" | while read -l pkg
    test -n "$pkg"; or continue
    set -l grep_hit (aur_grep -m1 -F "$pkg|" $events)
    set -l line (aur_event_line_from_hit "$grep_hit")
    if test -f $infected_sorted; and aur_grep -Fxq -- $pkg $infected_sorted
        aur_log "  [KNOWN]  $pkg"
    else
        aur_log "  [NEW?]   $pkg  — not on infected list, investigate"
        echo $pkg >>$unknown_file
    end
    aur_log "           $line"
end

set -l unknown_count 0
if test -s $unknown_file
    set unknown_count (aur_safe_count (cat $unknown_file | string collect))
end

rm -f $events $foreign_sorted $infected_sorted $unknown_file

if test $unknown_count -gt 0
    aur_log ""
    aur_log "Packages not on list but active during window — manual review recommended."
    exit 1
end

aur_log ""
exit 0
