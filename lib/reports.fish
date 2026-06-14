function aur_json_escape --argument-names value
    # Minimal JSON string escaping for the hand-built fallback when jq is absent.
    printf '%s' $value \
        | string replace -a '\\' '\\\\' \
        | string replace -a '"' '\\"' \
        | string replace -a \n '\\n' \
        | string replace -a \r '\\r' \
        | string replace -a \t '\\t'
end

function aur_json_string_array --argument-names items
    if test (count $argv) -eq 0
        echo '[]'
        return
    end
    set -l parts
    for item in $argv
        set -a parts "\"$(aur_json_escape $item)\""
    end
    echo '['(string join ', ' $parts)']'
end

# Maps exit code to a stable severity label for JSON consumers and dashboards.
function aur_compute_severity --argument-names exit_code
    switch $exit_code
        case $AUR_EXIT_COMPROMISE
            echo critical
        case $AUR_EXIT_WARN
            echo warning
        case $AUR_EXIT_INSUFFICIENT
            echo insufficient
        case '*'
            echo clean
    end
end

# Reports, JSON summary, and retention.

# Build JSON string arrays via jq when available; otherwise use aur_json_string_array.
function aur_jq_string_array_from_list
    if test (count $argv) -eq 0
        echo -n '[]'
        return
    end
    printf '%s\n' $argv | jq -Rc . | jq -sc .
end

function aur_log_insufficient_help
    aur_log ""
    aur_log "Insufficient data — pacman logs could not be read."
    aur_log "  Try: sudo fish $AUR_RESPONSE_DIR/run.fish"(set -q argv[1]; and echo " $argv[1]"; or echo "")
    aur_log "  Logs expected: /var/log/pacman.log*"
end

function aur_prune_reports --argument-names days
    if test -z "$days"; or test $days -le 0
        return 0
    end
    if not test -d $AUR_REPORTS_DIR
        return 0
    end
    set -l pruned 0
    # Prune timestamped .log reports and the rolling latest-summary.json.
    for f in $AUR_REPORTS_DIR/*.log $AUR_REPORTS_DIR/latest-summary.json
        test -f $f; or continue
        set -l age (aur_list_staleness_days $f)
        if test $age -ge $days
            rm -f $f
            set pruned (math $pruned + 1)
        end
    end
    if test $pruned -gt 0
        aur_log "Pruned $pruned report file(s) older than $days days"
    end
end

# Category names mirrored in latest-summary.json findings.* and audit_* sections.
function aur_audit_finding_categories
    echo audit_ssh_keys audit_git_paths audit_docker_paths audit_env_files audit_history_files
end

# Write machine-readable summary for automation (--json) and CI consumers.
# Also copies to .scan-findings.json for tools that read findings without the full summary.
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
    set -l severity (aur_compute_severity $exit_code)

    set -l finding_infected (aur_finding_list installed_infected)
    set -l finding_high_risk (aur_finding_list installed_high_risk)
    set -l finding_unknown (aur_finding_list unknown_window_pkgs)
    set -l finding_timeline (aur_finding_list timeline_hits)
    set -l finding_artifacts (aur_finding_list artifacts)
    set -l finding_runtime (aur_finding_list runtime_iocs)
    set -l finding_insufficient (aur_finding_list insufficient_data)

    set -l audit_ssh (aur_finding_list audit_ssh_keys)
    set -l audit_git (aur_finding_list audit_git_paths)
    set -l audit_docker (aur_finding_list audit_docker_paths)
    set -l audit_env (aur_finding_list audit_env_files)
    set -l audit_history (aur_finding_list audit_history_files)

    set -l report_file_arg ""
    set -q AUR_REPORT_FILE[1]; and set report_file_arg $AUR_REPORT_FILE

    if command -q jq
        set -l jq_infected (aur_jq_string_array_from_list $finding_infected | string collect)
        set -l jq_high_risk (aur_jq_string_array_from_list $finding_high_risk | string collect)
        set -l jq_unknown (aur_jq_string_array_from_list $finding_unknown | string collect)
        set -l jq_timeline (aur_jq_string_array_from_list $finding_timeline | string collect)
        set -l jq_artifacts (aur_jq_string_array_from_list $finding_artifacts | string collect)
        set -l jq_runtime (aur_jq_string_array_from_list $finding_runtime | string collect)
        set -l jq_insufficient (aur_jq_string_array_from_list $finding_insufficient | string collect)
        set -l jq_audit_ssh (aur_jq_string_array_from_list $audit_ssh | string collect)
        set -l jq_audit_git (aur_jq_string_array_from_list $audit_git | string collect)
        set -l jq_audit_docker (aur_jq_string_array_from_list $audit_docker | string collect)
        set -l jq_audit_env (aur_jq_string_array_from_list $audit_env | string collect)
        set -l jq_audit_history (aur_jq_string_array_from_list $audit_history | string collect)
        test -z "$jq_insufficient"; and set jq_insufficient '[]'
        test -z "$jq_audit_ssh"; and set jq_audit_ssh '[]'
        test -z "$jq_audit_git"; and set jq_audit_git '[]'
        test -z "$jq_audit_docker"; and set jq_audit_docker '[]'
        test -z "$jq_audit_env"; and set jq_audit_env '[]'
        test -z "$jq_audit_history"; and set jq_audit_history '[]'
        jq -n \
            --arg timestamp "$ts" \
            --arg version "$AUR_VERSION" \
            --arg host (hostname) \
            --argjson exit_code $exit_code \
            --arg severity "$severity" \
            --argjson installed_infected $AUR_SUMMARY_installed_infected \
            --argjson installed_high_risk $AUR_SUMMARY_installed_high_risk \
            --argjson timeline_hits $AUR_SUMMARY_timeline_hits \
            --argjson window_aur_pkgs $AUR_SUMMARY_window_aur_pkgs \
            --argjson artifact_critical $AUR_SUMMARY_artifact_critical \
            --argjson credential_exposed $AUR_SUMMARY_credential_exposed \
            --argjson hardening_warn $AUR_SUMMARY_hardening_warn \
            --argjson list_added $AUR_SUMMARY_list_added \
            --argjson list_removed $AUR_SUMMARY_list_removed \
            --argjson insufficient_data $AUR_SUMMARY_insufficient_data \
            --argjson runtime_iocs $AUR_SUMMARY_runtime_iocs \
            --arg report_file "$report_file_arg" \
            --arg list_sha256 "$list_sha256" \
            --argjson findings_installed_infected "$jq_infected" \
            --argjson findings_installed_high_risk "$jq_high_risk" \
            --argjson findings_unknown_window_pkgs "$jq_unknown" \
            --argjson findings_timeline_hits "$jq_timeline" \
            --argjson findings_artifacts "$jq_artifacts" \
            --argjson findings_runtime_iocs "$jq_runtime" \
            --argjson findings_insufficient_data "$jq_insufficient" \
            --argjson findings_audit_ssh_keys "$jq_audit_ssh" \
            --argjson findings_audit_git_paths "$jq_audit_git" \
            --argjson findings_audit_docker_paths "$jq_audit_docker" \
            --argjson findings_audit_env_files "$jq_audit_env" \
            --argjson findings_audit_history_files "$jq_audit_history" \
            '{
              timestamp: $timestamp,
              version: $version,
              host: $host,
              exit_code: $exit_code,
              severity: $severity,
              installed_infected: $installed_infected,
              installed_high_risk: $installed_high_risk,
              timeline_hits: $timeline_hits,
              window_aur_pkgs: $window_aur_pkgs,
              artifact_critical: $artifact_critical,
              credential_exposed: $credential_exposed,
              hardening_warn: $hardening_warn,
              list_added: $list_added,
              list_removed: $list_removed,
              insufficient_data: $insufficient_data,
              runtime_iocs: $runtime_iocs,
              report_file: $report_file,
              list_sha256: $list_sha256,
              findings: {
                installed_infected: $findings_installed_infected,
                installed_high_risk: $findings_installed_high_risk,
                unknown_window_pkgs: $findings_unknown_window_pkgs,
                timeline_hits: $findings_timeline_hits,
                artifacts: $findings_artifacts,
                runtime_iocs: $findings_runtime_iocs,
                insufficient_data: $findings_insufficient_data,
                audit_ssh_keys: $findings_audit_ssh_keys,
                audit_git_paths: $findings_audit_git_paths,
                audit_docker_paths: $findings_audit_docker_paths,
                audit_env_files: $findings_audit_env_files,
                audit_history_files: $findings_audit_history_files
              }
            }' >$AUR_SUMMARY_FILE
        cp $AUR_SUMMARY_FILE $AUR_FINDINGS_FILE
        return
    end

    # jq not installed — hand-built JSON with aur_json_escape (arrays only; sufficient for CI/minimal systems).
    printf '{
  "timestamp": "%s",
  "version": "%s",
  "host": "%s",
  "exit_code": %s,
  "severity": "%s",
  "installed_infected": %s,
  "installed_high_risk": %s,
  "timeline_hits": %s,
  "window_aur_pkgs": %s,
  "artifact_critical": %s,
  "credential_exposed": %s,
  "hardening_warn": %s,
  "list_added": %s,
  "list_removed": %s,
  "insufficient_data": %s,
  "runtime_iocs": %s,
  "report_file": "%s",
  "list_sha256": "%s",
  "findings": {
    "installed_infected": %s,
    "installed_high_risk": %s,
    "unknown_window_pkgs": %s,
    "timeline_hits": %s,
    "artifacts": %s,
    "runtime_iocs": %s,
    "insufficient_data": %s,
    "audit_ssh_keys": %s,
    "audit_git_paths": %s,
    "audit_docker_paths": %s,
    "audit_env_files": %s,
    "audit_history_files": %s
  }
}\n' \
        $ts $AUR_VERSION $host $exit_code $severity \
        $AUR_SUMMARY_installed_infected $AUR_SUMMARY_installed_high_risk \
        $AUR_SUMMARY_timeline_hits $AUR_SUMMARY_window_aur_pkgs \
        $AUR_SUMMARY_artifact_critical $AUR_SUMMARY_credential_exposed \
        $AUR_SUMMARY_hardening_warn $AUR_SUMMARY_list_added $AUR_SUMMARY_list_removed \
        $AUR_SUMMARY_insufficient_data $AUR_SUMMARY_runtime_iocs \
        $report_file $list_sha256 \
        (aur_json_string_array $finding_infected) \
        (aur_json_string_array $finding_high_risk) \
        (aur_json_string_array $finding_unknown) \
        (aur_json_string_array $finding_timeline) \
        (aur_json_string_array $finding_artifacts) \
        (aur_json_string_array $finding_runtime) \
        (aur_json_string_array $finding_insufficient) \
        (aur_json_string_array $audit_ssh) \
        (aur_json_string_array $audit_git) \
        (aur_json_string_array $audit_docker) \
        (aur_json_string_array $audit_env) \
        (aur_json_string_array $audit_history) >$AUR_SUMMARY_FILE
    cp $AUR_SUMMARY_FILE $AUR_FINDINGS_FILE
end
