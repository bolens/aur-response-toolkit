#!/usr/bin/env fish

# All foreign (AUR) packages touched during compromise window — catches unknowns not yet on list

set -g AUR_RESPONSE_DIR (dirname (status filename))
source $AUR_RESPONSE_DIR/lib/common.fish

set -l write_report false
for arg in $argv
    test "$arg" = --report; and set write_report true
end

if test $write_report = true
    aur_begin_report aur-window-
end

aur_log "=== AUR activity window scan ==="
aur_log "Foreign packages installed/upgraded Jun 9–14, $AUR_COMPROMISE_YEAR (any pkg)"
aur_log ""

if not test -f /var/log/pacman.log
    aur_log "WARN: /var/log/pacman.log not found"
    exit 0
end

set -l foreign_pkgs (pacman -Qmq 2>/dev/null)
set -l window_hits
set -l window_unknown

while read -l line
    if not string match -qr '\[ALPM\] (installed|upgraded|reinstalled)' -- $line
        continue
    end
    if not aur_log_line_in_compromise_window $line
        continue
    end
    for pkg in $foreign_pkgs
        if string match -qr "\[ALPM\] (installed|upgraded|reinstalled) $pkg \(" -- $line
            set -a window_hits "$pkg|$line"
            break
        end
    end
end </var/log/pacman.log

# Deduplicate by package name, keep first line
set -l seen_pkgs
set -l unique_hits
for hit in $window_hits
    set -l pkg (string split '|' $hit)[1]
    if contains $pkg $seen_pkgs
        continue
    end
    set -a seen_pkgs $pkg
    set -a unique_hits $hit
end

if test (count $unique_hits) -eq 0
    aur_log "[OK] No foreign package activity in compromise window"
    exit 0
end

aur_summary_set window_aur_pkgs (count $unique_hits)
aur_log "[INFO] "(count $unique_hits)" foreign package(s) touched during window:"

set -l infected_pkgs
test -f $AUR_LIST_FILE; and set infected_pkgs (cat $AUR_LIST_FILE)

for hit in $unique_hits
    set -l pkg (string split '|' $hit)[1]
    set -l line (string split '|' $hit)[2]
    if contains $pkg $infected_pkgs
        aur_log "  [KNOWN]  $pkg"
    else
        aur_log "  [NEW?]   $pkg  — not on infected list, investigate"
        set -a window_unknown $pkg
    end
    aur_log "           $line"
end

if test (count $window_unknown) -gt 0
    aur_log ""
    aur_log "Packages not on list but active during window — manual review recommended."
    exit 1
end

aur_log ""
exit 0
