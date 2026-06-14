#!/usr/bin/env fish

# Scan installed foreign packages NOT on the Atomic Arch list for campaign-like
# obfuscation/supply-chain patterns (npm/bun hooks, base64 pipes, curl|bash, etc.).
# Exit 1 = malicious hook IOC; exit 2 = broader heuristic hits only; exit 0 = clean.

source (dirname (dirname (status filename)))/_init.fish

for arg in $argv
    switch $arg
        case --help -h
            echo "Usage: scan/similar-heuristics.fish [--local] [--report] [--quiet] [--quick]"
            echo ""
            echo "Heuristic scan of installed foreign packages not on the Atomic Arch list."
            echo "Flags malicious npm/bun hooks as compromise; other pattern hits are warnings."
            aur_common_flags_help
            exit 0
    end
end

aur_validate_known_flags $argv
aur_parse_common_args $argv
aur_begin_report_if_requested similar-heuristics-

set -l list_file (aur_atomic_arch_list_file_path)
if test $AUR_OPT_local = false
    aur_load_atomic_arch_list false >/dev/null
end

if not test -f $list_file
    aur_log "ERROR: list file missing at $list_file"
    exit $AUR_EXIT_COMPROMISE
end

aur_log "=== Similar heuristics scan (non-listed foreign packages) ==="
aur_log ""

set -l candidates (aur_foreign_installed_not_on_list $list_file)
set -l candidate_count (count $candidates)
aur_summary_set similar_heuristics_candidates $candidate_count
aur_log "Installed foreign packages not on Atomic Arch list: $candidate_count"
aur_log ""

set -l hook_hits 0
set -l heuristic_hits 0

for pkg in $candidates
    set -l files (aur_pkg_similar_heuristics_files $pkg)
    test (count $files) -gt 0; or continue

    set -l has_hook false
    set -l has_heuristic false
    for f in $files
        if aur_file_has_hook_pattern $f
            set has_hook true
        end
        if aur_file_has_similar_heuristics $f
            set has_heuristic true
        end
    end

    if test $has_hook = false; and test $has_heuristic = false
        continue
    end

    if test $has_hook = true
        set hook_hits (math $hook_hits + 1)
        aur_finding_add similar_heuristics_hook $pkg
        aur_log "  [CRITICAL] $pkg — malicious hook pattern"
    else
        set heuristic_hits (math $heuristic_hits + 1)
        aur_finding_add similar_heuristics_review $pkg
        aur_log "  [REVIEW]   $pkg — similar supply-chain/obfuscation pattern"
    end

    for f in $files
        aur_log "             $f"
        set -l lines (aur_file_similar_heuristics_lines $f | head -n 5)
        for line in $lines
            aur_log "               "(string trim -- $line)
        end
    end
end

aur_summary_set similar_heuristics_hook $hook_hits
aur_summary_set similar_heuristics_review $heuristic_hits

aur_log ""
if test $hook_hits -eq 0; and test $heuristic_hits -eq 0
    aur_log "[OK] No similar heuristics in non-listed foreign packages"
    exit $AUR_EXIT_CLEAN
end

if test $hook_hits -gt 0
    aur_log "$hook_hits non-listed package(s) with malicious hooks — treat as compromise."
    aur_mark_compromised
    exit $AUR_EXIT_COMPROMISE
end

aur_log "$heuristic_hits non-listed package(s) with heuristic matches — manual review recommended."
exit $AUR_EXIT_WARN
