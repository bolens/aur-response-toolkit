# Shared helpers for AUR malware response scripts.
# Scripts set AUR_RESPONSE_DIR before sourcing; lib/ can also derive it from its own path.

if not set -q AUR_RESPONSE_DIR
    set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
end

# --- Version ---
set -g AUR_VERSION_FILE "$AUR_RESPONSE_DIR/VERSION"
if test -f $AUR_VERSION_FILE
    set -g AUR_VERSION (string trim (cat $AUR_VERSION_FILE))
else
    set -g AUR_VERSION dev
end

# --- Exit codes (stable contract for CI/automation; see README) ---
set -g AUR_EXIT_CLEAN 0
set -g AUR_EXIT_COMPROMISE 1
set -g AUR_EXIT_WARN 2
set -g AUR_EXIT_INSUFFICIENT 3
set -g AUR_EXIT_INVALID 4

# --- Paths (defaults; override in ~/.config/atomic-arch-response/config.fish) ---
set -g AUR_SCRIPTS_DIR "$AUR_RESPONSE_DIR/scripts"
set -g AUR_DATA_DIR "$AUR_RESPONSE_DIR/data"
set -g AUR_LIST_FILE "$AUR_DATA_DIR/infected-pkgs.txt"
# Tests redirect the infected list without touching data/infected-pkgs.txt.
if set -q AUR_TEST_LIST_FILE
    set -g AUR_LIST_FILE $AUR_TEST_LIST_FILE
end
set -g AUR_LIST_PREVIOUS "$AUR_DATA_DIR/infected-pkgs.previous.txt"
set -g AUR_REPORTS_DIR "$AUR_RESPONSE_DIR/reports"
set -g AUR_SUMMARY_FILE "$AUR_RESPONSE_DIR/reports/latest-summary.json"
set -g AUR_FINDINGS_FILE "$AUR_RESPONSE_DIR/reports/.scan-findings.json"
set -g AUR_FINDINGS_LIST_FILE "$AUR_REPORTS_DIR/.scan-findings.list"

# Remote infected-list sources merged on each online fetch (see aur_load_infected_list).
set -g AUR_LIST_URL_ARCH "https://md.archlinux.org/s/SxbqukK6IA"
set -g AUR_LIST_URL_CSCS "https://cscs.pastes.sh/raw/aurvulntest20260611.sh"

# Arch package naming rules — filters HTML noise and invalid tokens from scraped lists.
set -g AUR_PKG_PATTERN '^[a-z0-9][a-z0-9_.+\-]*[a-z0-9]$'
set -g AUR_COMPROMISE_YEAR 2026
# Compromise window: Jun 9–14 2026 (Atomic Arch campaign active period).
# WINDOW_LOG_RE matches pacman.log timestamps; INSTALL_* matches pacman -Qi "Install Date".
set -g AUR_WINDOW_LOG_RE '2026-06-(09|10|11|12|13|14)'
set -g AUR_WINDOW_INSTALL_DAYS_RE '(0?[9]|1[0-4])'
set -g AUR_WINDOW_INSTALL_MONTH Jun
set -g AUR_WINDOW_LABEL "Jun 9–14, $AUR_COMPROMISE_YEAR"
# Malicious npm/bun hooks injected into PKGBUILDs, .install scripts, and shell rc files.
set -g AUR_HOOK_PATTERN 'atomic-lockfile|js-digest|lockfile-js|bun install js-digest|npm install atomic-lockfile|npm install lockfile-js'

# Known SHA256 of the deps infostealer binary (ioctl.fail / Sonatype IOC).
set -g AUR_MALWARE_SHA256_DEPS 6144D433F8A0316869877B5F834C801251BBB936E5F1577C5680878C7443C98B
set -g AUR_MALICIOUS_NPM atomic-lockfile js-digest lockfile-js
# Exfil endpoints referenced by the campaign (history scan + live ss checks).
set -g AUR_IOC_DOMAINS temp.sh olrh4mibs62l6kkuvvjyc5lrercqg5tz543r4lsw3o6mh5qb7g7sneid.onion
set -g AUR_HISTORY_SECRET_PATTERN 'password|token|ghp_|github_pat|api[_-]?key|secret|BEGIN (RSA|OPENSSH)|CLOUDFLARE|AWS_|docker login|npm login|hash-password|changepassword'
if not set -q AUR_DEV_ROOT
    set -g AUR_DEV_ROOT "$HOME/dev"
end
set -g AUR_DEPS_SEARCH_PATHS $HOME/.cache $HOME/.local $HOME/.npm $HOME/node_modules /var/lib/pacman /var/tmp /var/lib
set -g AUR_LIST_MAX_AGE_DAYS 7
if not set -q AUR_LIST_URL_EXTRA
    set -g AUR_LIST_URL_EXTRA ""
end

if not set -q AUR_STATE_FILE
    set -g AUR_STATE_FILE "$AUR_RESPONSE_DIR/reports/.scan-state"
end

# User config (optional overrides; legacy ~/.config/aur-response/ still honored)
set -l _aur_user_config "$HOME/.config/atomic-arch-response/config.fish"
if set -q XDG_CONFIG_HOME
    set _aur_user_config "$XDG_CONFIG_HOME/atomic-arch-response/config.fish"
end
if not test -f $_aur_user_config
    set -l _aur_legacy_config "$HOME/.config/aur-response/config.fish"
    if set -q XDG_CONFIG_HOME
        set _aur_legacy_config "$XDG_CONFIG_HOME/aur-response/config.fish"
    end
    test -f $_aur_legacy_config; and set _aur_user_config $_aur_legacy_config
end
test -f $_aur_user_config; and source $_aur_user_config

# Grep compatibility shim: scripts use common grep flags; translate to rg when available.
# Unknown flags fall through to grep so callers never need to branch on which tool exists.
function aur_grep
    if not command -q rg
        command grep $argv
        return $status
    end

    set -l rg_flags
    set -l args $argv
    set -l skip_next false

    while test (count $args) -gt 0
        set -l arg $args[1]
        if test "$skip_next" = true
            set skip_next false
            set args $args[2..-1]
            continue
        end

        switch $arg
            case --
                set args $args[2..-1]
                break
            case -F --fixed-strings
                set -a rg_flags -F
                set args $args[2..-1]
            case -x --line-regexp
                set -a rg_flags -x
                set args $args[2..-1]
            case -q --quiet --silent
                set -a rg_flags -q
                set args $args[2..-1]
            case -o --only-matching
                set -a rg_flags -o
                set args $args[2..-1]
            case -E --extended-regexp
                set args $args[2..-1]
            case -m1
                set -a rg_flags -m 1
                set args $args[2..-1]
            case '-m*'
                set -a rg_flags -m (string sub -s 3 -- $arg)
                set args $args[2..-1]
            case -m
                set -a rg_flags -m $args[2]
                set skip_next true
                set args $args[2..-1]
            case '-*'
                # Flag we do not translate — delegate to grep unchanged.
                command grep $argv
                return $status
            case '*'
                break
        end
    end

    command rg $rg_flags -- $args
end

function aur_version
    echo $AUR_VERSION
end

# Summary counters — also persisted to $AUR_STATE_FILE so child scripts can update totals.
set -g AUR_SUMMARY_installed_infected 0
set -g AUR_SUMMARY_installed_high_risk 0
set -g AUR_SUMMARY_timeline_hits 0
set -g AUR_SUMMARY_window_aur_pkgs 0
set -g AUR_SUMMARY_artifact_critical 0
set -g AUR_SUMMARY_credential_exposed 0
set -g AUR_SUMMARY_hardening_warn 0
set -g AUR_SUMMARY_list_added 0
set -g AUR_SUMMARY_list_removed 0
set -g AUR_SUMMARY_insufficient_data 0
set -g AUR_SUMMARY_runtime_iocs 0

set -g AUR_OPT_local false
set -g AUR_OPT_report false
set -g AUR_OPT_audit false
set -g AUR_OPT_quiet false
set -g AUR_OPT_quick false
set -g AUR_OPT_if_compromised false
set -g AUR_OPT_fail_on all
set -g AUR_OPT_prune_days 0

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
    for arg in $argv
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
            case --if-compromised
                set -g AUR_OPT_if_compromised true
            case --fail-on=*
                set -g AUR_OPT_fail_on (string sub -s 10 -- $arg)
            case --fail-on
                # value must follow; handled below
            case --fail-on:compromise --fail-on:all --fail-on:none
                set -g AUR_OPT_fail_on (string sub -s 10 -- $arg)
            case --prune-days=*
                set -g AUR_OPT_prune_days (string sub -s 13 -- $arg)
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
    echo "  --local            Use bundled infected-pkgs.txt (no network fetch)"
    echo "  --report           Append output to reports/"
    echo "  --quiet            Suppress stdout (reports/json still written)"
    echo "  --quick            Faster scans (narrower artifact search)"
    echo "  --if-compromised   Only fail credential audit when compromise detected"
    echo "  --fail-on MODE     Exit policy: all (default), compromise, none"
end

# Reject unknown dashed flags early (exit 4). Positional package names are ignored.
function aur_validate_known_flags
    set -l allowed \
        --help -h --version \
        --local --report --quiet --audit \
        --no-chain --json --skip-pkg-check \
        --dry-run --force --all-shells --verify \
        --quick --if-compromised --recover \
        --fail-on all compromise none --prune-days
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
    for key in installed_infected installed_high_risk timeline_hits window_aur_pkgs artifact_critical credential_exposed hardening_warn list_added list_removed insufficient_data runtime_iocs compromised
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
function aur_finalize_exit --argument-names compromise warn insufficient
    set -l c 0
    set -l w 0
    set -l i 0
    test "$compromise" = true; and set c 1
    test "$warn" = true; and set w 1
    test "$insufficient" = true; and set i 1

    # Priority: insufficient > compromise > warn > clean. --fail-on can suppress lower severities.
    if test $i -eq 1; and contains -- $AUR_OPT_fail_on all compromise
        echo $AUR_EXIT_INSUFFICIENT
        return $AUR_EXIT_INSUFFICIENT
    end
    if test $c -eq 1; and contains -- $AUR_OPT_fail_on all compromise
        echo $AUR_EXIT_COMPROMISE
        return $AUR_EXIT_COMPROMISE
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
    aur_log "Host: "(hostname)
    aur_log ""
end

function aur_summary_inc --argument-names key amount
    set -l current (aur_state_get $key)
    if test -z "$current"
        set current 0
    end
    aur_summary_set $key (math $current + $amount)
end

# pacman -Qi uses "DD Mon YYYY" — different format from pacman.log ISO timestamps.
function aur_install_date_in_window --argument-names date_line
    if test -z "$date_line"
        return 1
    end
    if not string match -qr ".*$AUR_COMPROMISE_YEAR.*" -- $date_line
        return 1
    end
    if string match -qr ".*\\s$AUR_WINDOW_INSTALL_DAYS_RE\\s+$AUR_WINDOW_INSTALL_MONTH\\s+" -- $date_line
        return 0
    end
    return 1
end

function aur_install_in_compromise_window --argument-names pkg
    set -l info (pacman -Qi $pkg 2>/dev/null)
    if test $status -ne 0
        return 1
    end
    set -l date_line (string match -r 'Install Date\s*:\s*(.*)' $info)[2]
    aur_install_date_in_window $date_line
end

function aur_log_line_in_compromise_window --argument-names line
    string match -qr $AUR_WINDOW_LOG_RE -- $line
end

# Only installed|upgraded|reinstalled count; "removed" during the window is not a new install.
function aur_is_alpm_install_line --argument-names line
    string match -qr '\[ALPM\] (installed|upgraded|reinstalled)' -- $line
end

function aur_extract_alpm_pkg_from_line --argument-names line
    set -l parts (string match -r '\[ALPM\] (?:installed|upgraded|reinstalled) (\S+) \(' $line)
    echo $parts[2]
end

# Collect install/upgrade/reinstall events in the compromise window.
# Output format: "pkgname|full pacman log line" (pipe delimiter survives commas in log lines).
function aur_collect_window_alpm_events --argument-names log_path out_file
    while read -l line
        aur_is_alpm_install_line $line; or continue
        aur_log_line_in_compromise_window $line; or continue
        set -l pkg (aur_extract_alpm_pkg_from_line $line)
        test -n "$pkg"; or continue
        echo "$pkg|$line" >>$out_file
    end <$log_path
end

function aur_collect_window_alpm_events_all --argument-names out_file
    for log_path in (aur_pacman_log_paths)
        aur_collect_window_alpm_events $log_path $out_file
    end
end

function aur_pacman_logs_accessible
    set -l found false
    for log_path in (aur_pacman_log_paths)
        if test -r $log_path
            set found true
            break
        end
    end
    test $found = true
end

# pacman -Qmq = foreign (AUR) packages only; official repos are out of scope for this campaign.
function aur_foreign_package_names
    if set -q AUR_TEST_FOREIGN_LIST
        cat $AUR_TEST_FOREIGN_LIST
        return $status
    end
    pacman -Qmq 2>/dev/null
end

# Includes rotated logs (pacman.log.*). Tests override via AUR_TEST_PACMAN_LOG_DIR.
function aur_pacman_log_paths
    if set -q AUR_TEST_PACMAN_LOG_DIR
        for log_path in $AUR_TEST_PACMAN_LOG_DIR/pacman.log $AUR_TEST_PACMAN_LOG_DIR/pacman.log.*
            test -f $log_path; and echo $log_path
        end
        return
    end
    for log_path in /var/log/pacman.log /var/log/pacman.log.*
        test -f $log_path; and echo $log_path
    end
end

function aur_event_line_from_hit --argument-names hit
    echo (string split -m1 '|' -- "$hit")[2]
end

# Intersect window events with the known infected list; return matching log lines only.
function aur_timeline_hits_from_events --argument-names events_file infected_list_file
    set -l infected_sorted (mktemp)
    set -l window_pkgs (mktemp)
    set -l matching (mktemp)
    set -l hits_raw (mktemp)

    sort -u $infected_list_file >$infected_sorted
    cut -d'|' -f1 $events_file | sort -u >$window_pkgs
    comm -12 $window_pkgs $infected_sorted >$matching

    while read -l pkg
        aur_grep -F "$pkg|" $events_file >>$hits_raw
    end <$matching

    if test -s $hits_raw
        while read -l hit
            aur_event_line_from_hit "$hit"
        end <$hits_raw
    end

    rm -f $infected_sorted $window_pkgs $matching $hits_raw
end

# Foreign (AUR) packages touched during the window — includes packages later removed.
function aur_foreign_packages_in_window --argument-names events_file foreign_list_file
    set -l foreign_sorted (mktemp)
    set -l window_pkgs (mktemp)
    set -l foreign_in_window (mktemp)

    sort -u $foreign_list_file >$foreign_sorted
    cut -d'|' -f1 $events_file | sort -u >$window_pkgs
    comm -12 $window_pkgs $foreign_sorted >$foreign_in_window
    cat $foreign_in_window

    rm -f $foreign_sorted $window_pkgs $foreign_in_window
end

# Count lines in a multiline string safely (fish empty-string pitfalls).
function aur_safe_count --argument-names multiline
    if test -z "$multiline"
        echo 0
        return
    end
    set -l tmp (mktemp)
    printf '%s\n' "$multiline" >$tmp
    set -l n (string match -r . <$tmp | count)
    rm -f $tmp
    echo $n
end

function aur_file_in_compromise_window --argument-names path
    set -l mtime (aur_file_mtime $path)
    string match -qr $AUR_WINDOW_LOG_RE -- $mtime
end

function aur_file_has_hook_pattern --argument-names file
    while read -l line
        if string match -qir $AUR_HOOK_PATTERN -- $line
            return 0
        end
    end <$file
    return 1
end

function aur_pkg_install_date --argument-names pkg
    set -l info (pacman -Qi $pkg 2>/dev/null)
    if test $status -ne 0
        echo unknown
        return 1
    end
    string match -r 'Install Date\s*:\s*(.*)' $info | tail -1
end

function aur_pkg_install_reason --argument-names pkg
    set -l info (pacman -Qi $pkg 2>/dev/null)
    if test $status -ne 0
        echo unknown
        return 1
    end
    string match -r 'Install Reason\s*:\s*(.*)' $info | tail -1
end

function aur_filter_pkg_lines
    while read -l line
        set line (string trim -- $line)
        if test -n "$line"; and string match -qr $AUR_PKG_PATTERN -- $line
            echo $line
        end
    end
end

# Strip HTML tags from Arch Security paste before validating package names.
function aur_parse_pkg_names
    string join \n -- $argv \
        | sed 's/<[^>]*>//g' \
        | aur_filter_pkg_lines \
        | sort -u
end

# CSCS advisory ships a bash array; extract package names between INFECTED_PKGS=( and ).
function aur_parse_cscs_script --argument-names file
    sed -n '/^INFECTED_PKGS=(/,/^)/p' $file \
        | while read -l line
        if string match -qr '^\)|^INFECTED_PKGS' -- $line
            continue
        end
        set line (string trim -- $line)
        if test -n "$line"; and string match -qr $AUR_PKG_PATTERN -- $line
            echo $line
        end
    end \
        | sort -u
end

function aur_fetch_source --argument-names url
    set -l tmp (mktemp)
    curl -fsSL --max-time 30 "$url" -o $tmp
    if test $status -ne 0
        rm -f $tmp
        return 1
    end
    echo $tmp
end

# Returns "tmpfile|sha256" so callers can log source integrity without re-reading.
function aur_fetch_source_with_sha --argument-names url
    set -l tmp (aur_fetch_source $url)
    if test $status -ne 0
        return 1
    end
    set -l sha (sha256sum $tmp | string split ' ' | head -1)
    echo "$tmp|$sha"
end

function aur_list_staleness_days --argument-names path
    if not test -f $path
        echo -1
        return
    end
    set -l mtime (stat -c %Y $path 2>/dev/null)
    set -l now (date +%s)
    math "($now - $mtime) / 86400"
end

function aur_warn_local_list_stale
    set -l age (aur_list_staleness_days $AUR_LIST_FILE)
    if test $age -lt 0
        return
    end
    if test $age -gt $AUR_LIST_MAX_AGE_DAYS
        aur_log "WARN: bundled list is $age days old (>$AUR_LIST_MAX_AGE_DAYS) — run without --local for fresh data"
    end
end

# Compare freshly fetched list to the previous copy (comm -13 = only in new, -23 = only in old).
function aur_list_delta --argument-names old_file
    if not test -f $old_file
        return 0
    end
    set -l new_pkgs $argv[2..-1]
    set -l old_sorted (mktemp)
    set -l new_sorted (mktemp)
    sort -u $old_file >$old_sorted
    printf '%s\n' $new_pkgs | sort -u >$new_sorted
    set -l added (comm -13 $old_sorted $new_sorted)
    set -l removed (comm -23 $old_sorted $new_sorted)
    rm -f $old_sorted $new_sorted
    set -g AUR_SUMMARY_list_added (count $added)
    set -g AUR_SUMMARY_list_removed (count $removed)
    if test (count $added) -gt 0
        aur_log "List delta: "(count $added)" new package(s) since last fetch:"
        for p in $added
            aur_log "  + $p"
        end
    end
    if test (count $removed) -gt 0
        aur_log "List delta: "(count $removed)" removed from list:"
        for p in $removed
            aur_log "  - $p"
        end
    end
    if test (count $added) -eq 0; and test (count $removed) -eq 0
        aur_log "List delta: no changes since last fetch"
    end
end

# Load merged infected list: local file, or fetch Arch + CSCS (+ optional extra URL) and union.
# On fetch failure, falls back to the bundled data/infected-pkgs.txt if present.
function aur_load_infected_list --argument-names use_local
    if test "$use_local" = true
        if not test -f $AUR_LIST_FILE
            aur_log "ERROR: --local requires $AUR_LIST_FILE"
            return 1
        end
        aur_warn_local_list_stale
        aur_log "Using local list at $AUR_LIST_FILE"
        sort -u $AUR_LIST_FILE
        return 0
    end

    set -l all_pkgs
    set -l sources_used
    set -l source_shas

    aur_log "Fetching infected package lists..."

    if test -f $AUR_LIST_FILE
        cp $AUR_LIST_FILE $AUR_LIST_PREVIOUS
    end

    set -l arch_fetch (aur_fetch_source_with_sha $AUR_LIST_URL_ARCH)
    if test $status -eq 0
        set -l arch_parts (string split '|' -- $arch_fetch)
        set -l arch_tmp $arch_parts[1]
        set -l arch_sha $arch_parts[2]
        set -l arch_pkgs (aur_parse_pkg_names (cat $arch_tmp))
        set all_pkgs $all_pkgs $arch_pkgs
        set -a sources_used "Arch ($AUR_LIST_URL_ARCH)"
        set -a source_shas "arch=$arch_sha"
        rm -f $arch_tmp
    else
        aur_log "WARN: failed to fetch $AUR_LIST_URL_ARCH"
    end

    set -l cscs_fetch (aur_fetch_source_with_sha $AUR_LIST_URL_CSCS)
    if test $status -eq 0
        set -l cscs_parts (string split '|' -- $cscs_fetch)
        set -l cscs_tmp $cscs_parts[1]
        set -l cscs_sha $cscs_parts[2]
        set -l cscs_pkgs (aur_parse_cscs_script $cscs_tmp)
        set all_pkgs $all_pkgs $cscs_pkgs
        set -a sources_used "cscs ($AUR_LIST_URL_CSCS)"
        set -a source_shas "cscs=$cscs_sha"
        rm -f $cscs_tmp
    else
        aur_log "WARN: failed to fetch $AUR_LIST_URL_CSCS"
    end

    if test -n "$AUR_LIST_URL_EXTRA"
        set -l extra_fetch (aur_fetch_source_with_sha $AUR_LIST_URL_EXTRA)
        if test $status -eq 0
            set -l extra_parts (string split '|' -- $extra_fetch)
            set -l extra_tmp $extra_parts[1]
            set -l extra_sha $extra_parts[2]
            set -l extra_pkgs (aur_parse_pkg_names (cat $extra_tmp))
            set all_pkgs $all_pkgs $extra_pkgs
            set -a sources_used "extra ($AUR_LIST_URL_EXTRA)"
            set -a source_shas "extra=$extra_sha"
            rm -f $extra_tmp
        else
            aur_log "WARN: failed to fetch $AUR_LIST_URL_EXTRA"
        end
    end

    if test (count $all_pkgs) -eq 0
        if test -f $AUR_LIST_FILE
            aur_log "All fetches failed; using local list at $AUR_LIST_FILE"
            sort -u $AUR_LIST_FILE
            return 0
        end
        aur_log "ERROR: all remote sources failed and no local list at $AUR_LIST_FILE"
        return 1
    end

    set all_pkgs (string join \n -- $all_pkgs | sort -u)
    aur_list_delta $AUR_LIST_PREVIOUS $all_pkgs
    string join \n -- $all_pkgs >$AUR_LIST_FILE
    aur_log "Merged list saved to $AUR_LIST_FILE ("(count $all_pkgs)" packages)"
    for src in $sources_used
        aur_log "  - $src"
    end
    for sha_line in $source_shas
        aur_log "  - source SHA256 $sha_line"
        aur_finding_add list_source_sha256 $sha_line
    end
    echo $all_pkgs
end

function aur_file_mtime --argument-names path
    stat -c '%y' $path 2>/dev/null | string split ' ' | head -1
end

function aur_sha256_file --argument-names path
    sha256sum $path 2>/dev/null | string split ' ' | head -1 | string upper
end

# Key-name heuristic only — never reads or logs secret values from env files.
function aur_env_has_secrets --argument-names path
    if not test -f $path
        return 1
    end
    while read -l line
        if string match -qir '^(export\s+)?[A-Z0-9_]*(TOKEN|SECRET|PASSWORD|API_KEY|APIKEY|PRIVATE_KEY|CREDENTIAL)[A-Z0-9_]*\s*=' -- $line
            return 0
        end
    end <$path
    return 1
end

# Pull in findings, history, IOC, and report helpers after all base paths/constants exist.
set -g _aur_lib (dirname (status filename))
source $_aur_lib/findings.fish
source $_aur_lib/history.fish
source $_aur_lib/ioc.fish
source $_aur_lib/reports.fish

function aur_print_summary_dashboard --argument-names exit_code
    aur_log ""
    aur_log "=== Scan summary ==="
    aur_log "  Toolkit version:          $AUR_VERSION"
    aur_log "  Installed infected pkgs:  $AUR_SUMMARY_installed_infected ($AUR_SUMMARY_installed_high_risk high-risk)"
    aur_log "  Timeline hits:            $AUR_SUMMARY_timeline_hits"
    aur_log "  AUR pkgs in window:       $AUR_SUMMARY_window_aur_pkgs"
    aur_log "  Malware artifacts:        $AUR_SUMMARY_artifact_critical critical"
    aur_log "  Runtime IOCs:             $AUR_SUMMARY_runtime_iocs"
    aur_log "  Credential exposures:     $AUR_SUMMARY_credential_exposed"
    aur_log "  Hardening warnings:       $AUR_SUMMARY_hardening_warn"
    aur_log "  Insufficient data:        $AUR_SUMMARY_insufficient_data"
    if test $AUR_SUMMARY_list_added -gt 0 -o $AUR_SUMMARY_list_removed -gt 0
        aur_log "  List changes:             +$AUR_SUMMARY_list_added / -$AUR_SUMMARY_list_removed"
    end
    aur_log "  Severity:                 "(aur_compute_severity $exit_code)
    aur_log "  JSON summary:             $AUR_SUMMARY_FILE"
end
