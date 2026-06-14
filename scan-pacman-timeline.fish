#!/usr/bin/env fish

set -g AUR_RESPONSE_DIR (dirname (status filename))
source $AUR_RESPONSE_DIR/lib/common.fish

set -l write_report false
for arg in $argv
    test "$arg" = --report; and set write_report true
end

if test $write_report = true
    aur_begin_report pacman-timeline-
end

aur_log "=== Pacman install timeline (compromise window) ==="
aur_log "Scanning /var/log/pacman.log for infected packages, Jun 9–14 $AUR_COMPROMISE_YEAR"
aur_log ""

if not test -f /var/log/pacman.log
    aur_log "WARN: /var/log/pacman.log not found"
    exit 0
end

if not test -f $AUR_LIST_FILE
    aur_log "WARN: $AUR_LIST_FILE missing"
    exit 0
end

set -l infected_pkgs (cat $AUR_LIST_FILE)
set -l log_hits

while read -l line
    if not string match -qr '\[ALPM\] (installed|upgraded|reinstalled)' -- $line
        continue
    end
    if not aur_log_line_in_compromise_window $line
        continue
    end
    for pkg in $infected_pkgs
        # Exact package name match (avoids substring false positives)
        if string match -qr "\[ALPM\] (installed|upgraded|reinstalled) $pkg \(" -- $line
            set -a log_hits "$line"
            break
        end
    end
end </var/log/pacman.log

if test (count $log_hits) -eq 0
    aur_log "[OK] No infected packages in pacman.log during compromise window"
else
    aur_summary_set timeline_hits (count $log_hits)
    aur_log "[FOUND] "(count $log_hits)" timeline hit(s):"
    for hit in $log_hits
        aur_log "  $hit"
    end
    aur_log ""
    aur_log "Removed packages still appear. Review each — upgrades during window may be benign"
    aur_log "if you intentionally updated that day (e.g. beef gaming pkg)."
    exit 1
end

aur_log ""
