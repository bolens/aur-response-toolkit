# Shared helpers for AUR malware response scripts
# Expect callers to set AUR_RESPONSE_DIR before sourcing, or derive from lib path.

if not set -q AUR_RESPONSE_DIR
    set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
end
set -g AUR_LIST_FILE "$AUR_RESPONSE_DIR/infected-pkgs.txt"
set -g AUR_LIST_PREVIOUS "$AUR_RESPONSE_DIR/infected-pkgs.previous.txt"
set -g AUR_REPORTS_DIR "$AUR_RESPONSE_DIR/reports"
set -g AUR_SUMMARY_FILE "$AUR_RESPONSE_DIR/reports/latest-summary.json"

set -g AUR_LIST_URL_ARCH "https://md.archlinux.org/s/SxbqukK6IA"
set -g AUR_LIST_URL_CSCS "https://cscs.pastes.sh/raw/aurvulntest20260611.sh"

set -g AUR_PKG_PATTERN '^[a-z0-9][a-z0-9_.+\-]*[a-z0-9]$'
set -g AUR_COMPROMISE_YEAR 2026

set -g AUR_MALWARE_SHA256_DEPS "6144D433F8A0316869877B5F834C801251BBB936E5F1577C5680878C7443C98B"
set -g AUR_MALICIOUS_NPM atomic-lockfile js-digest lockfile-js
set -g AUR_IOC_DOMAINS temp.sh olrh4mibs62l6kkuvvjyc5lrercqg5tz543r4lsw3o6mh5qb7g7sneid.onion

set -g AUR_STATE_FILE "$AUR_RESPONSE_DIR/reports/.scan-state"

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
        echo $line
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

function aur_install_in_compromise_window --argument-names pkg
    set -l info (pacman -Qi $pkg 2>/dev/null)
    if test $status -ne 0
        return 1
    end
    set -l date_line (string match -r 'Install Date\s*:\s*(.*)' $info)[2]
    if test -z "$date_line"
        return 1
    end
    if not string match -qr ".*$AUR_COMPROMISE_YEAR.*" -- $date_line
        return 1
    end
    if string match -qr '.* Jun\s+(9|10|11|12|13|14)\s.*' -- $date_line
        return 0
    end
    return 1
end

function aur_log_line_in_compromise_window --argument-names line
    string match -qr '2026-06-(09|10|11|12|13|14)' -- $line
end

function aur_pkg_install_date --argument-names pkg
    set -l info (pacman -Qi $pkg 2>/dev/null)
    if test $status -ne 0
        echo "unknown"
        return 1
    end
    string match -r 'Install Date\s*:\s*(.*)' $info | tail -1
end

function aur_pkg_install_reason --argument-names pkg
    set -l info (pacman -Qi $pkg 2>/dev/null)
    if test $status -ne 0
        echo "unknown"
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

function aur_parse_pkg_names --argument-names raw
    string join \n -- $raw \
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

function aur_list_delta --argument-names old_file new_pkgs
    if not test -f $old_file
        return 0
    end
    set -l old_pkgs (sort -u $old_file)
    set -l added (comm -13 (echo $old_pkgs | sort) (echo $new_pkgs | sort))
    set -l removed (comm -23 (echo $old_pkgs | sort) (echo $new_pkgs | sort))
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
        if string match -qir 'password|token|ghp_|github_pat|api[_-]?key|secret|BEGIN (RSA|OPENSSH)|CLOUDFLARE|AWS_|docker login|npm login' -- $line
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

function aur_write_summary_json --argument-names exit_code
    mkdir -p $AUR_REPORTS_DIR
    set -l ts (date '+%Y-%m-%dT%H:%M:%S%z')
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
  "report_file": "%s"
}\n' \
        $ts (hostname) $exit_code \
        $AUR_SUMMARY_installed_infected $AUR_SUMMARY_installed_high_risk \
        $AUR_SUMMARY_timeline_hits $AUR_SUMMARY_window_aur_pkgs \
        $AUR_SUMMARY_artifact_critical $AUR_SUMMARY_credential_exposed \
        $AUR_SUMMARY_hardening_warn $AUR_SUMMARY_list_added $AUR_SUMMARY_list_removed \
        (set -q AUR_REPORT_FILE[1]; and echo $AUR_REPORT_FILE; or echo "") \
        >$AUR_SUMMARY_FILE
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
