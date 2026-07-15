#!/usr/bin/env fish

# Compare bundled atomic-arch-pkgs.txt against a fresh online merge and report whether
# installed foreign packages would be missed by a stale --local list.
# Exit 1 = installed package only on fresh list; exit 3 = fetch/data failure; exit 0 = no impact.
# Never overwrites the bundled list file (writes the merge to a temp path).

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: check/list-freshness.fish [--report] [--quiet]"
            echo ""
            echo "Compare bundled data/lists/atomic-arch-pkgs.txt to online sources and check"
            echo "whether installed foreign packages appear only on the fresh merged list."
            echo "Does not modify the bundled list on disk."
            echo ""
            echo "Flags:"
            echo "  --report  Append output to reports/"
            echo "  --quiet   Suppress stdout (reports still written)"
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv
aur_begin_report_if_requested list-freshness-

# Always compare against the shipped bundle (or test override), not an XDG online cache.
set -l bundled_file (aur_atomic_arch_list_bundled_path)
if set -q AUR_TEST_LIST_FILE
    set bundled_file $AUR_TEST_LIST_FILE
end
if not test -f $bundled_file
    aur_insufficient_data "bundled list missing at $bundled_file"
    exit $AUR_EXIT_INSUFFICIENT
end

set -l bundled_sorted (mktemp)
set -l fresh_sorted (mktemp)
set -l fresh_file (mktemp)
set -l added (mktemp)
set -l removed (mktemp)
set -l installed_sorted (mktemp)
set -l temps $bundled_sorted $fresh_sorted $fresh_file $added $removed $installed_sorted

sort -u $bundled_file | aur_filter_pkg_lines >$bundled_sorted
set -l bundled_count (wc -l < $bundled_sorted | string trim)
set -l bundled_age (aur_list_staleness_days $bundled_file)

aur_log "=== Atomic Arch list freshness check ==="
aur_log "Bundled list: $bundled_count packages ($bundled_file, age $bundled_age days)"
aur_warn_local_list_stale $bundled_file
aur_log ""

set -gx AUR_ATOMIC_ARCH_LIST_WRITE_FILE $fresh_file
aur_load_atomic_arch_list false >/dev/null
set -l fetch_status $status
set -e AUR_ATOMIC_ARCH_LIST_WRITE_FILE

if test $fetch_status -ne 0
    aur_insufficient_data "failed to fetch fresh Atomic Arch list"
    rm -f $temps
    exit $AUR_EXIT_INSUFFICIENT
end

if not test -s $fresh_file
    aur_insufficient_data "fresh Atomic Arch list empty after fetch"
    rm -f $temps
    exit $AUR_EXIT_INSUFFICIENT
end

sort -u $fresh_file | aur_filter_pkg_lines >$fresh_sorted
set -l fresh_count (wc -l < $fresh_sorted | string trim)
aur_log "Fresh online list: $fresh_count packages (temp merge; bundled list unchanged)"
aur_log ""

comm -13 $bundled_sorted $fresh_sorted >$added
comm -23 $bundled_sorted $fresh_sorted >$removed
set -l add_n (wc -l < $added | string trim)
set -l rem_n (wc -l < $removed | string trim)

aur_summary_set list_freshness_added $add_n
aur_summary_set list_freshness_removed $rem_n
aur_log "Delta vs bundled snapshot: +$add_n added, -$rem_n removed"
if test $add_n -gt 0
    aur_log "  New on fresh list (first 20):"
    head -n 20 $added | while read -l pkg
        aur_log "    + $pkg"
        aur_finding_add list_freshness_added $pkg
    end
end
if test $rem_n -gt 0
    aur_log "  Dropped from bundled (first 10):"
    head -n 10 $removed | while read -l pkg
        aur_log "    - $pkg"
    end
end
aur_log ""

aur_installed_foreign_packages | sort >$installed_sorted

set -l fresh_hits (comm -12 $installed_sorted $fresh_sorted)
set -l stale_miss (comm -12 $installed_sorted $added)

aur_log "Installed foreign packages on fresh list: "(count $fresh_hits)
if test (count $fresh_hits) -gt 0
    for pkg in $fresh_hits
        aur_log "  [KNOWN] $pkg"
        aur_classify_atomic_arch_installed_pkg $pkg
    end
else
    aur_log "  [OK] None"
end
aur_log ""

set -l exit_code $AUR_EXIT_CLEAN
aur_log "Installed packages only on fresh list (bundled would miss): "(count $stale_miss)
if test (count $stale_miss) -gt 0
    for pkg in $stale_miss
        aur_log "  [STALE-MISS] $pkg"
        aur_finding_add list_staleness_installed $pkg
        aur_classify_atomic_arch_installed_pkg $pkg
    end
    aur_log ""
    aur_log "Bundled --local scan would miss "(count $stale_miss)" installed package(s)."
    aur_mark_compromised
    set exit_code $AUR_EXIT_COMPROMISE
else
    aur_log "  [OK] No installed packages only on fresh list"
    if test $add_n -gt 0
        aur_log ""
        aur_log "List grew by $add_n name(s) but none are installed — --local staleness has no impact here."
    end
end

rm -f $temps
exit $exit_code
