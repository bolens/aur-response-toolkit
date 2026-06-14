# Shared helpers for AUR malware response scripts
# Expect callers to set AUR_RESPONSE_DIR before sourcing, or derive from lib path.

if not set -q AUR_RESPONSE_DIR
    set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
end
set -g AUR_SCRIPTS_DIR "$AUR_RESPONSE_DIR/scripts"
set -g AUR_DATA_DIR "$AUR_RESPONSE_DIR/data"
set -g AUR_LIST_FILE "$AUR_DATA_DIR/infected-pkgs.txt"
if set -q AUR_TEST_LIST_FILE
    set -g AUR_LIST_FILE $AUR_TEST_LIST_FILE
end
set -g AUR_LIST_PREVIOUS "$AUR_DATA_DIR/infected-pkgs.previous.txt"
set -g AUR_REPORTS_DIR "$AUR_RESPONSE_DIR/reports"
set -g AUR_SUMMARY_FILE "$AUR_RESPONSE_DIR/reports/latest-summary.json"

set -g AUR_LIST_URL_ARCH "https://md.archlinux.org/s/SxbqukK6IA"
set -g AUR_LIST_URL_CSCS "https://cscs.pastes.sh/raw/aurvulntest20260611.sh"

set -g AUR_PKG_PATTERN '^[a-z0-9][a-z0-9_.+\-]*[a-z0-9]$'
set -g AUR_COMPROMISE_YEAR 2026
set -g AUR_WINDOW_LOG_RE '2026-06-(09|10|11|12|13|14)'
set -g AUR_WINDOW_INSTALL_DAYS_RE '(0?[9]|1[0-4])'
set -g AUR_WINDOW_INSTALL_MONTH Jun
set -g AUR_WINDOW_LABEL "Jun 9–14, $AUR_COMPROMISE_YEAR"
set -g AUR_HOOK_PATTERN 'atomic-lockfile|js-digest|lockfile-js|bun install js-digest|npm install atomic-lockfile|npm install lockfile-js'

set -g AUR_MALWARE_SHA256_DEPS 6144D433F8A0316869877B5F834C801251BBB936E5F1577C5680878C7443C98B
set -g AUR_MALICIOUS_NPM atomic-lockfile js-digest lockfile-js
set -g AUR_IOC_DOMAINS temp.sh olrh4mibs62l6kkuvvjyc5lrercqg5tz543r4lsw3o6mh5qb7g7sneid.onion
set -g AUR_HISTORY_SECRET_PATTERN 'password|token|ghp_|github_pat|api[_-]?key|secret|BEGIN (RSA|OPENSSH)|CLOUDFLARE|AWS_|docker login|npm login|hash-password|changepassword'
set -g AUR_DEV_ROOT (set -q AUR_DEV_ROOT; and echo $AUR_DEV_ROOT; or echo "$HOME/dev")
set -g AUR_DEPS_SEARCH_PATHS $HOME/.cache $HOME/.local $HOME/.npm $HOME/node_modules /var/lib/pacman /var/tmp /var/lib

set -g AUR_STATE_FILE "$AUR_RESPONSE_DIR/reports/.scan-state"

# Prefer ripgrep when available; fall back to grep for the flags we use.
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
                command grep $argv
                return $status
            case '*'
                break
        end
    end

    command rg $rg_flags -- $args
end

# Summary counters — persisted to $AUR_STATE_FILE for cross-process use
set -g AUR_SUMMARY_installed_infected 0
set -g AUR_SUMMARY_installed_high_risk 0
set -g AUR_SUMMARY_timeline_hits 0
set -g AUR_SUMMARY_window_aur_pkgs 0
set -g AUR_SUMMARY_artifact_critical 0
set -g AUR_SUMMARY_credential_exposed 0
set -g AUR_SUMMARY_hardening_warn 0
set -g AUR_SUMMARY_list_added 0
set -g AUR_SUMMARY_list_removed 0

set -g AUR_OPT_local false
set -g AUR_OPT_report false
set -g AUR_OPT_audit false
set -g AUR_OPT_quiet false

function aur_parse_common_args
    set -g AUR_OPT_local false
    set -g AUR_OPT_report false
    set -g AUR_OPT_audit false
    set -g AUR_OPT_quiet false
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
        end
    end
end

function aur_common_flags_help
    echo "Common flags:"
    echo "  --local   Use bundled infected-pkgs.txt (no network fetch)"
    echo "  --report  Append output to reports/"
    echo "  --quiet   Suppress stdout (reports/json still written)"
end

function aur_validate_known_flags
    set -l allowed \
        --help -h \
        --local --report --quiet --audit \
        --no-chain --json --skip-pkg-check \
        --dry-run --force --all-shells
    for arg in $argv
        if contains -- $arg $allowed
            continue
        end
        if string match -qr '^-' -- $arg
            echo "Unknown option: $arg (see --help)" >&2
            exit 2
        end
    end
end

function aur_begin_report_if_requested --argument-names label
    if test $AUR_OPT_report = true
        aur_begin_report $label
    end
end

function aur_state_init
    mkdir -p $AUR_REPORTS_DIR
    rm -f $AUR_STATE_FILE
end

function aur_state_set --argument-names key value
    mkdir -p $AUR_REPORTS_DIR
    set -l tmp (mktemp)
    if test -f $AUR_STATE_FILE
        while read -l line
            if not string match -qr "^$key=" -- $line
                echo $line >>$tmp
            end
        end <$AUR_STATE_FILE
    end
    echo "$key=$value" >>$tmp
    mv $tmp $AUR_STATE_FILE
end

function aur_state_get --argument-names key
    if not test -f $AUR_STATE_FILE
        echo 0
        return
    end
    while read -l line
        if string match -qr "^$key=" -- $line
            echo (string split -m1 '=' $line)[2]
            return
        end
    end <$AUR_STATE_FILE
    echo 0
end

function aur_summary_set --argument-names key value
    set -g AUR_SUMMARY_$key $value
    aur_state_set $key $value
end

function aur_state_load_summary
    for key in installed_infected installed_high_risk timeline_hits window_aur_pkgs artifact_critical credential_exposed hardening_warn list_added list_removed
        set -g AUR_SUMMARY_$key (aur_state_get $key)
    end
end

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

function aur_begin_report --argument-names label
    mkdir -p $AUR_REPORTS_DIR
    if set -q AUR_REPORT_FILE[1]
        return 0
    end
    set -gx AUR_REPORT_FILE "$AUR_REPORTS_DIR/$label"(date +%Y%m%d-%H%M%S)".log"
    aur_log "=== AUR malware response report ==="
    aur_log "Started: "(date '+%Y-%m-%d %H:%M:%S')
    aur_log "Host: "(hostname)
    aur_log ""
end

function aur_summary_inc --argument-names key amount
    set -l current (aur_state_get $key)
    aur_summary_set $key (math $current + $amount)
end

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

function aur_is_alpm_install_line --argument-names line
    string match -qr '\[ALPM\] (installed|upgraded|reinstalled)' -- $line
end

function aur_extract_alpm_pkg_from_line --argument-names line
    set -l parts (string match -r '\[ALPM\] (?:installed|upgraded|reinstalled) (\S+) \(' $line)
    echo $parts[2]
end

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

function aur_foreign_package_names
    if set -q AUR_TEST_FOREIGN_LIST
        cat $AUR_TEST_FOREIGN_LIST
        return $status
    end
    pacman -Qmq 2>/dev/null
end

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

function aur_find_deps_elf
    for base in $AUR_DEPS_SEARCH_PATHS
        test -e $base; or continue
        for candidate in (find $base -name deps -perm -111 -size +1M 2>/dev/null)
            if test (aur_sha256_file $candidate) = $AUR_MALWARE_SHA256_DEPS
                echo $candidate
            end
        end
    end
end

function aur_ebpf_rootkit_maps
    for map in hidden_pids hidden_names hidden_inodes
        test -e /sys/fs/bpf/$map; and echo /sys/fs/bpf/$map
    end
end

function aur_log_persistence_findings --argument-names heading
    set -l heading_text "$heading"
    test -n "$heading_text"; and aur_log $heading_text
    set -l deps (aur_find_deps_elf)
    set -l maps (aur_ebpf_rootkit_maps)
    set -l critical false
    for path in $maps
        aur_log "  [CRITICAL] $path"
        set critical true
    end
    for path in $deps
        aur_log "  [CRITICAL] deps ELF at $path"
        set critical true
    end
    if test $critical = false
        aur_log "  [OK]       No eBPF rootkit maps or known deps ELF binary"
    end
    if test $critical = true
        return 1
    end
    return 0
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

function aur_parse_pkg_names
    string join \n -- $argv \
        | sed 's/<[^>]*>//g' \
        | aur_filter_pkg_lines \
        | sort -u
end

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

function aur_load_infected_list --argument-names use_local
    if test "$use_local" = true
        if not test -f $AUR_LIST_FILE
            aur_log "ERROR: --local requires $AUR_LIST_FILE"
            return 1
        end
        aur_log "Using local list at $AUR_LIST_FILE"
        sort -u $AUR_LIST_FILE
        return 0
    end

    set -l all_pkgs
    set -l sources_used

    aur_log "Fetching infected package lists..."

    if test -f $AUR_LIST_FILE
        cp $AUR_LIST_FILE $AUR_LIST_PREVIOUS
    end

    set -l arch_tmp (aur_fetch_source $AUR_LIST_URL_ARCH)
    if test $status -eq 0
        set -l arch_pkgs (aur_parse_pkg_names (cat $arch_tmp))
        set all_pkgs $all_pkgs $arch_pkgs
        set -a sources_used "Arch ($AUR_LIST_URL_ARCH)"
        rm -f $arch_tmp
    else
        aur_log "WARN: failed to fetch $AUR_LIST_URL_ARCH"
    end

    set -l cscs_tmp (aur_fetch_source $AUR_LIST_URL_CSCS)
    if test $status -eq 0
        set -l cscs_pkgs (aur_parse_cscs_script $cscs_tmp)
        set all_pkgs $all_pkgs $cscs_pkgs
        set -a sources_used "cscs ($AUR_LIST_URL_CSCS)"
        rm -f $cscs_tmp
    else
        aur_log "WARN: failed to fetch $AUR_LIST_URL_CSCS"
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
    echo $all_pkgs
end

function aur_file_mtime --argument-names path
    stat -c '%y' $path 2>/dev/null | string split ' ' | head -1
end

function aur_sha256_file --argument-names path
    sha256sum $path 2>/dev/null | string split ' ' | head -1 | string upper
end

function aur_history_secret_hits --argument-names path
    if not test -f $path
        echo 0
        return
    end
    set -l count 0
    while read -l line
        if string match -qir $AUR_HISTORY_SECRET_PATTERN -- $line
            set count (math $count + 1)
        end
    end <$path
    echo $count
end

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

function aur_json_escape --argument-names value
    printf '%s' $value \
        | string replace -a '\\' '\\\\' \
        | string replace -a '"' '\\"' \
        | string replace -a \n '\\n' \
        | string replace -a \r '\\r' \
        | string replace -a \t '\\t'
end

function aur_write_summary_json --argument-names exit_code
    mkdir -p $AUR_REPORTS_DIR
    set -l ts (date '+%Y-%m-%dT%H:%M:%S%z')
    set -l host (aur_json_escape (hostname))
    set -l report_file ""
    set -q AUR_REPORT_FILE[1]; and set report_file (aur_json_escape $AUR_REPORT_FILE)
    set -l list_sha256 ""
    if test -f $AUR_LIST_FILE
        set list_sha256 (sha256sum $AUR_LIST_FILE | string split ' ' | head -1)
    end

    if command -q jq
        jq -n \
            --arg timestamp $ts \
            --arg host (hostname) \
            --argjson exit_code $exit_code \
            --argjson installed_infected $AUR_SUMMARY_installed_infected \
            --argjson installed_high_risk $AUR_SUMMARY_installed_high_risk \
            --argjson timeline_hits $AUR_SUMMARY_timeline_hits \
            --argjson window_aur_pkgs $AUR_SUMMARY_window_aur_pkgs \
            --argjson artifact_critical $AUR_SUMMARY_artifact_critical \
            --argjson credential_exposed $AUR_SUMMARY_credential_exposed \
            --argjson hardening_warn $AUR_SUMMARY_hardening_warn \
            --argjson list_added $AUR_SUMMARY_list_added \
            --argjson list_removed $AUR_SUMMARY_list_removed \
            --arg report_file (set -q AUR_REPORT_FILE[1]; and echo $AUR_REPORT_FILE; or echo "") \
            --arg list_sha256 $list_sha256 \
            '{
              timestamp: $timestamp,
              host: $host,
              exit_code: $exit_code,
              installed_infected: $installed_infected,
              installed_high_risk: $installed_high_risk,
              timeline_hits: $timeline_hits,
              window_aur_pkgs: $window_aur_pkgs,
              artifact_critical: $artifact_critical,
              credential_exposed: $credential_exposed,
              hardening_warn: $hardening_warn,
              list_added: $list_added,
              list_removed: $list_removed,
              report_file: $report_file,
              list_sha256: $list_sha256
            }' >$AUR_SUMMARY_FILE
        return
    end

    printf '{
  "timestamp": "%s",
  "host": "%s",
  "exit_code": %s,
  "installed_infected": %s,
  "installed_high_risk": %s,
  "timeline_hits": %s,
  "window_aur_pkgs": %s,
  "artifact_critical": %s,
  "credential_exposed": %s,
  "hardening_warn": %s,
  "list_added": %s,
  "list_removed": %s,
  "report_file": "%s",
  "list_sha256": "%s"
}\n' \
        $ts $host $exit_code \
        $AUR_SUMMARY_installed_infected $AUR_SUMMARY_installed_high_risk \
        $AUR_SUMMARY_timeline_hits $AUR_SUMMARY_window_aur_pkgs \
        $AUR_SUMMARY_artifact_critical $AUR_SUMMARY_credential_exposed \
        $AUR_SUMMARY_hardening_warn $AUR_SUMMARY_list_added $AUR_SUMMARY_list_removed \
        $report_file $list_sha256 >$AUR_SUMMARY_FILE
end

function aur_print_summary_dashboard --argument-names exit_code
    aur_log ""
    aur_log "=== Scan summary ==="
    aur_log "  Installed infected pkgs:  $AUR_SUMMARY_installed_infected ($AUR_SUMMARY_installed_high_risk high-risk)"
    aur_log "  Timeline hits:            $AUR_SUMMARY_timeline_hits"
    aur_log "  AUR pkgs in window:     $AUR_SUMMARY_window_aur_pkgs"
    aur_log "  Malware artifacts:        $AUR_SUMMARY_artifact_critical critical"
    aur_log "  Credential exposures:     $AUR_SUMMARY_credential_exposed"
    aur_log "  Hardening warnings:     $AUR_SUMMARY_hardening_warn"
    if test $AUR_SUMMARY_list_added -gt 0 -o $AUR_SUMMARY_list_removed -gt 0
        aur_log "  List changes:             +$AUR_SUMMARY_list_added / -$AUR_SUMMARY_list_removed"
    end
    aur_log "  JSON summary:             $AUR_SUMMARY_FILE"
end
