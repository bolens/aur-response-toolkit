# CLI flags, logging, state, and exit policy.

function aur_version
    echo $AUR_VERSION
end

# Summary counters — also persisted to $AUR_STATE_FILE so child scripts can update totals.
set -g AUR_SUMMARY_atomic_arch_installed 0
set -g AUR_SUMMARY_atomic_arch_high_risk 0
set -g AUR_SUMMARY_atomic_arch_timeline_hits 0
set -g AUR_SUMMARY_atomic_arch_timeline_repeat_updates 0
set -g AUR_SUMMARY_window_aur_pkgs 0
set -g AUR_SUMMARY_artifact_critical 0
set -g AUR_SUMMARY_credential_exposed 0
set -g AUR_SUMMARY_hardening_warn 0
set -g AUR_SUMMARY_list_added 0
set -g AUR_SUMMARY_list_removed 0
set -g AUR_SUMMARY_insufficient_data 0
set -g AUR_SUMMARY_runtime_iocs 0
set -g AUR_SUMMARY_chaos_rat_installed 0
set -g AUR_SUMMARY_chaos_rat_high_risk 0
set -g AUR_SUMMARY_chaos_rat_timeline_hits 0
set -g AUR_SUMMARY_shai_hulud_installed 0
set -g AUR_SUMMARY_shai_hulud_high_risk 0
set -g AUR_SUMMARY_shai_hulud_timeline_hits 0
set -g AUR_SUMMARY_xeactor_installed 0
set -g AUR_SUMMARY_xeactor_high_risk 0
set -g AUR_SUMMARY_xeactor_timeline_hits 0

set -g AUR_OPT_local false
set -g AUR_OPT_report false
set -g AUR_OPT_audit false
set -g AUR_OPT_quiet false
set -g AUR_OPT_quick false
set -g AUR_OPT_if_compromised false
set -g AUR_OPT_fail_on all
set -g AUR_OPT_prune_days 0
set -g AUR_OPT_all_time false
set -g AUR_OPT_chaos_rat false
set -g AUR_OPT_shai_hulud false
set -g AUR_OPT_xeactor false

# Parse shared CLI flags into globals. Resets all AUR_OPT_* on each call so scripts
# can invoke this after their own argv parsing without inheriting stale values.
function aur_parse_common_args
    set -g AUR_OPT_local false
    set -g AUR_OPT_report false
    set -g AUR_OPT_audit false
    set -g AUR_OPT_quiet false
    set -g AUR_OPT_quick false
    set -g AUR_OPT_if_compromised false
    set -g AUR_OPT_fail_on all
    set -g AUR_OPT_prune_days 0
    set -g AUR_OPT_all_time false
    set -g AUR_OPT_chaos_rat false
    set -g AUR_OPT_shai_hulud false
    set -g AUR_OPT_xeactor false
    for arg in $argv
        if string match -qr '^--fail-on=' -- $arg
            set -g AUR_OPT_fail_on (string replace -r '^--fail-on=' '' -- $arg)
            continue
        end
        if string match -qr '^--prune-days=' -- $arg
            set -g AUR_OPT_prune_days (string replace -r '^--prune-days=' '' -- $arg)
            continue
        end
        switch $arg
            case --local
                set -g AUR_OPT_local true
            case --report
                set -g AUR_OPT_report true
            case --audit
                set -g AUR_OPT_audit true
            case --quiet
                set -g AUR_OPT_quiet true
            case --quick
                set -g AUR_OPT_quick true
            case --all-time
                set -g AUR_OPT_all_time true
            case --chaos-rat
                set -g AUR_OPT_chaos_rat true
            case --shai-hulud
                set -g AUR_OPT_shai_hulud true
            case --xeactor
                set -g AUR_OPT_xeactor true
            case --if-compromised
                set -g AUR_OPT_if_compromised true
            case --fail-on
                # value must follow; handled below
            case --fail-on:compromise --fail-on:all --fail-on:none --fail-on:chaos-rat --fail-on:shai-hulud --fail-on:xeactor
                set -g AUR_OPT_fail_on (string replace -r '^--fail-on:' '' -- $arg)
            case --prune-days
                # value must follow; handled below
            case --version
                continue
        end
    end
    # --fail-on VALUE and --prune-days N as two argv tokens
    set -l i 1
    while test $i -le (count $argv)
        if test "$argv[$i]" = --fail-on; and test $i -lt (count $argv)
            set -g AUR_OPT_fail_on $argv[(math $i + 1)]
        end
        if test "$argv[$i]" = --prune-days; and test $i -lt (count $argv)
            set -g AUR_OPT_prune_days $argv[(math $i + 1)]
        end
        set i (math $i + 1)
    end
end

function aur_common_flags_help
    echo "Common flags:"
    echo "  --local            Use bundled atomic-arch-pkgs.txt (no network fetch)"
    echo "  --report           Append output to reports/"
    echo "  --quiet            Suppress stdout (reports/json still written)"
    echo "  --quick            Faster scans (narrower artifact search)"
    echo "  --all-time         Ignore compromise date window (any install / log hit)"
    echo "  --if-compromised   Only fail credential audit when compromise detected"
    echo "  --chaos-rat        Scan for Chaos RAT / cracked-software AUR packages (opt-in threat)"
    echo "  --shai-hulud       Scan for Mini Shai-Hulud AUR packages (opt-in threat)"
    echo "  --xeactor      Scan for 2018 xeactor AUR packages (opt-in threat)"
    echo "  --fail-on MODE     Exit policy: all (default), compromise, chaos-rat, shai-hulud, xeactor, none"
end

# Build argv list from parsed AUR_OPT_* globals plus optional extra flags (e.g. --no-chain).
function aur_build_step_args
    set -l args
    test $AUR_OPT_local = true; and set -a args --local
    test $AUR_OPT_report = true; and set -a args --report
    test $AUR_OPT_quiet = true; and set -a args --quiet
    test $AUR_OPT_quick = true; and set -a args --quick
    test $AUR_OPT_all_time = true; and set -a args --all-time
    test $AUR_OPT_chaos_rat = true; and set -a args --chaos-rat
    test $AUR_OPT_shai_hulud = true; and set -a args --shai-hulud
    test $AUR_OPT_xeactor = true; and set -a args --xeactor
    for flag in $argv
        set -a args $flag
    end
    printf '%s\n' $args
end

# Reject unknown dashed flags early (exit 4). Positional package names are ignored.
function aur_validate_known_flags
    set -l allowed \
        --help -h --version \
        --local --report --quiet --audit \
        --no-chain --json --skip-pkg-check \
        --dry-run --force --all-shells --verify \
        --quick --all-time --if-compromised --recover --chaos-rat --shai-hulud --xeactor \
        --fail-on all compromise chaos-rat shai-hulud xeactor none --prune-days
    for arg in $argv
        if contains -- $arg $allowed
            continue
        end
        if string match -qr '^--fail-on=' -- $arg
            continue
        end
        if string match -qr '^--prune-days=' -- $arg
            continue
        end
        if string match -qr '^-' -- $arg
            echo "Unknown option: $arg (see --help)" >&2
            exit $AUR_EXIT_INVALID
        end
    end
end

function aur_begin_report_if_requested --argument-names label
    if test $AUR_OPT_report = true
        aur_begin_report $label
    end
end

# Reset ephemeral scan state at the start of a full run (each step writes fresh findings).
function aur_state_init
    mkdir -p $AUR_REPORTS_DIR
    rm -f $AUR_STATE_FILE $AUR_FINDINGS_FILE $AUR_FINDINGS_LIST_FILE
end

# Simple key=value file shared across subprocesses (each scan step is a separate fish).
function aur_state_set --argument-names key value
    mkdir -p $AUR_REPORTS_DIR
    set -l tmp (mktemp)
    if test -f $AUR_STATE_FILE
        while read -l line
            set -l k (string split -m1 '=' -- $line)[1]
            if test "$k" != "$key"
                echo $line >>$tmp
            end
        end <$AUR_STATE_FILE
    end
    echo "$key=$value" >>$tmp
    mv $tmp $AUR_STATE_FILE
end

function aur_state_get --argument-names key
    if not test -f $AUR_STATE_FILE
        echo ""
        return
    end
    while read -l line
        set -l k (string split -m1 '=' -- $line)[1]
        if test "$k" = "$key"
            echo (string split -m1 '=' -- $line)[2]
            return
        end
    end <$AUR_STATE_FILE
    echo ""
end

# Mirror a counter in memory and on disk so run.fish can reload after child scripts exit.
function aur_summary_set --argument-names key value
    set -g AUR_SUMMARY_$key $value
    aur_state_set $key $value
end

function aur_state_load_summary
    for key in atomic_arch_installed atomic_arch_high_risk atomic_arch_timeline_hits atomic_arch_timeline_repeat_updates window_aur_pkgs artifact_critical credential_exposed hardening_warn list_added list_removed insufficient_data runtime_iocs chaos_rat_installed chaos_rat_high_risk chaos_rat_timeline_hits shai_hulud_installed shai_hulud_high_risk shai_hulud_timeline_hits xeactor_installed xeactor_high_risk xeactor_timeline_hits compromised
        set -l val (aur_state_get $key)
        test -z "$val"; and set val 0
        set -g AUR_SUMMARY_$key $val
    end
end

# Sticky flag: any step that sees compromise indicators sets this for audit/exit logic.
function aur_mark_compromised
    aur_state_set compromised 1
    set -g AUR_SUMMARY_compromised 1
end

function aur_compromise_detected
    test (aur_state_get compromised) = 1
end

function aur_insufficient_data --argument-names reason
    aur_summary_inc insufficient_data 1
    aur_finding_add insufficient_data "$reason"
    aur_log "[INSUFFICIENT] $reason"
end

# Echoes the exit code on stdout (for `tail -1` capture) and returns it as $status.
function aur_finalize_exit --argument-names compromise warn insufficient chaos_rat shai_hulud xeactor
    set -l c 0
    set -l w 0
    set -l i 0
    set -l cr 0
    set -l sh 0
    set -l lg 0
    test "$compromise" = true; and set c 1
    test "$warn" = true; and set w 1
    test "$insufficient" = true; and set i 1
    test "$chaos_rat" = true; and set cr 1
    test "$shai_hulud" = true; and set sh 1
    test "$xeactor" = true; and set lg 1

    # Priority: insufficient > compromise > optional-campaign warn > generic warn > clean. --fail-on can suppress lower severities.
    if test $i -eq 1; and contains -- $AUR_OPT_fail_on all compromise
        echo $AUR_EXIT_INSUFFICIENT
        return $AUR_EXIT_INSUFFICIENT
    end
    if test $c -eq 1; and contains -- $AUR_OPT_fail_on all compromise chaos-rat shai-hulud xeactor
        echo $AUR_EXIT_COMPROMISE
        return $AUR_EXIT_COMPROMISE
    end
    if test $cr -eq 1; and contains -- $AUR_OPT_fail_on all chaos-rat
        echo $AUR_EXIT_WARN
        return $AUR_EXIT_WARN
    end
    if test $sh -eq 1; and contains -- $AUR_OPT_fail_on all shai-hulud
        echo $AUR_EXIT_WARN
        return $AUR_EXIT_WARN
    end
    if test $lg -eq 1; and contains -- $AUR_OPT_fail_on all xeactor
        echo $AUR_EXIT_WARN
        return $AUR_EXIT_WARN
    end
    if test $w -eq 1; and test "$AUR_OPT_fail_on" = all
        echo $AUR_EXIT_WARN
        return $AUR_EXIT_WARN
    end
    echo $AUR_EXIT_CLEAN
    return $AUR_EXIT_CLEAN
end

# Writes to stdout unless --quiet; mirrors the same lines into the active report file.
function aur_log
    for line in $argv
        if test $AUR_OPT_quiet != true
            echo $line
        end
        if set -q AUR_REPORT_FILE[1]
            echo $line >>$AUR_REPORT_FILE
        end
    end
end

# One report per run; AUR_REPORT_FILE is global so aur_log appends throughout.
function aur_begin_report --argument-names label
    mkdir -p $AUR_REPORTS_DIR
    if set -q AUR_REPORT_FILE[1]
        return 0
    end
    set -gx AUR_REPORT_FILE "$AUR_REPORTS_DIR/$label"(date +%Y%m%d-%H%M%S)".log"
    aur_log "=== AUR malware response report ==="
    aur_log "Toolkit version: $AUR_VERSION"
    aur_log "Started: "(date '+%Y-%m-%d %H:%M:%S')
    aur_log "Host: "(aur_hostname)
    aur_log ""
end

function aur_summary_inc --argument-names key amount
    set -l current (aur_state_get $key)
    if test -z "$current"
        set current 0
    end
    aur_summary_set $key (math $current + $amount)
end
