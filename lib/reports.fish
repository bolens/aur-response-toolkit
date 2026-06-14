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

# Docker config registry keys: jq when available; aur_grep + fish string ops otherwise.
function aur_docker_config_registry_keys --argument-names config_file
    if command -q jq
        jq -r '.auths | keys[]?' $config_file 2>/dev/null
        return $status
    end
    aur_grep -oE '"[^"]+":\s*\{' $config_file 2>/dev/null \
        | string replace -a -r '": \{$' '' \
        | string replace -a -r '^"' ''
end

function aur_log_insufficient_help
    aur_log ""
    aur_log "Insufficient data — pacman logs could not be read."
    aur_log "  Try: sudo fish $AUR_RESPONSE_DIR/run.fish"(set -q argv[1]; and echo " $argv[1]"; or echo "")
    set -l log_dir (aur_pacman_log_dir)
    aur_log "  Logs expected: $log_dir/pacman.log*"
    aur_log "  Chroot/container: set AUR_PACMAN_LOG_DIR in ~/.config/aur-response/config.fish"
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
    set -l list_file (aur_atomic_arch_list_file_path)
    if test -f $list_file
        set list_sha256 (aur_sha256 $list_file)
    end
    set -l chaos_rat_list_sha256 ""
    set -l chaos_list_file (aur_chaos_rat_list_file_path)
    if test -f $chaos_list_file
        set chaos_rat_list_sha256 (aur_sha256 $chaos_list_file)
    end
    set -l severity (aur_compute_severity $exit_code)

    set -l finding_infected (aur_finding_list atomic_arch_installed)
    set -l finding_high_risk (aur_finding_list atomic_arch_high_risk)
    set -l finding_unknown (aur_finding_list unknown_window_pkgs)
    set -l finding_timeline (aur_finding_list atomic_arch_timeline_hits)
    set -l finding_timeline_repeat (aur_finding_list atomic_arch_timeline_repeat_updates)
    set -l finding_artifacts (aur_finding_list artifacts)
    set -l finding_runtime (aur_finding_list runtime_iocs)
    set -l finding_insufficient (aur_finding_list insufficient_data)
    set -l finding_chaos_rat (aur_finding_list chaos_rat_installed)
    set -l finding_chaos_high (aur_finding_list chaos_rat_high_risk)
    set -l finding_chaos_timeline (aur_finding_list chaos_rat_timeline_hits)
    set -l finding_shai_hulud (aur_finding_list shai_hulud_installed)
    set -l finding_shai_high (aur_finding_list shai_hulud_high_risk)
    set -l finding_shai_timeline (aur_finding_list shai_hulud_timeline_hits)
    set -l finding_xeactor (aur_finding_list xeactor_installed)
    set -l finding_xeactor_high (aur_finding_list xeactor_high_risk)
    set -l finding_xeactor_timeline (aur_finding_list xeactor_timeline_hits)

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
        set -l jq_timeline_repeat (aur_jq_string_array_from_list $finding_timeline_repeat | string collect)
        set -l jq_artifacts (aur_jq_string_array_from_list $finding_artifacts | string collect)
        set -l jq_runtime (aur_jq_string_array_from_list $finding_runtime | string collect)
        set -l jq_insufficient (aur_jq_string_array_from_list $finding_insufficient | string collect)
        set -l jq_chaos_rat (aur_jq_string_array_from_list $finding_chaos_rat | string collect)
        set -l jq_chaos_high (aur_jq_string_array_from_list $finding_chaos_high | string collect)
        set -l jq_chaos_timeline (aur_jq_string_array_from_list $finding_chaos_timeline | string collect)
        set -l jq_shai_hulud (aur_jq_string_array_from_list $finding_shai_hulud | string collect)
        set -l jq_shai_high (aur_jq_string_array_from_list $finding_shai_high | string collect)
        set -l jq_shai_timeline (aur_jq_string_array_from_list $finding_shai_timeline | string collect)
        set -l jq_xeactor (aur_jq_string_array_from_list $finding_xeactor | string collect)
        set -l jq_xeactor_high (aur_jq_string_array_from_list $finding_xeactor_high | string collect)
        set -l jq_xeactor_timeline (aur_jq_string_array_from_list $finding_xeactor_timeline | string collect)
        set -l jq_audit_ssh (aur_jq_string_array_from_list $audit_ssh | string collect)
        set -l jq_audit_git (aur_jq_string_array_from_list $audit_git | string collect)
        set -l jq_audit_docker (aur_jq_string_array_from_list $audit_docker | string collect)
        set -l jq_audit_env (aur_jq_string_array_from_list $audit_env | string collect)
        set -l jq_audit_history (aur_jq_string_array_from_list $audit_history | string collect)
        test -z "$jq_insufficient"; and set jq_insufficient '[]'
        test -z "$jq_chaos_rat"; and set jq_chaos_rat '[]'
        test -z "$jq_chaos_high"; and set jq_chaos_high '[]'
        test -z "$jq_chaos_timeline"; and set jq_chaos_timeline '[]'
        test -z "$jq_shai_hulud"; and set jq_shai_hulud '[]'
        test -z "$jq_shai_high"; and set jq_shai_high '[]'
        test -z "$jq_shai_timeline"; and set jq_shai_timeline '[]'
        test -z "$jq_xeactor"; and set jq_xeactor '[]'
        test -z "$jq_xeactor_high"; and set jq_xeactor_high '[]'
        test -z "$jq_xeactor_timeline"; and set jq_xeactor_timeline '[]'
        test -z "$jq_timeline_repeat"; and set jq_timeline_repeat '[]'
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
            --argjson atomic_arch_installed $AUR_SUMMARY_atomic_arch_installed \
            --argjson atomic_arch_high_risk $AUR_SUMMARY_atomic_arch_high_risk \
            --argjson atomic_arch_timeline_hits $AUR_SUMMARY_atomic_arch_timeline_hits \
            --argjson atomic_arch_timeline_repeat_updates $AUR_SUMMARY_atomic_arch_timeline_repeat_updates \
            --argjson window_aur_pkgs $AUR_SUMMARY_window_aur_pkgs \
            --argjson artifact_critical $AUR_SUMMARY_artifact_critical \
            --argjson credential_exposed $AUR_SUMMARY_credential_exposed \
            --argjson hardening_warn $AUR_SUMMARY_hardening_warn \
            --argjson list_added $AUR_SUMMARY_list_added \
            --argjson list_removed $AUR_SUMMARY_list_removed \
            --argjson insufficient_data $AUR_SUMMARY_insufficient_data \
            --argjson runtime_iocs $AUR_SUMMARY_runtime_iocs \
            --argjson chaos_rat_installed $AUR_SUMMARY_chaos_rat_installed \
            --argjson chaos_rat_high_risk $AUR_SUMMARY_chaos_rat_high_risk \
            --argjson chaos_rat_timeline_hits $AUR_SUMMARY_chaos_rat_timeline_hits \
            --argjson shai_hulud_installed $AUR_SUMMARY_shai_hulud_installed \
            --argjson shai_hulud_high_risk $AUR_SUMMARY_shai_hulud_high_risk \
            --argjson shai_hulud_timeline_hits $AUR_SUMMARY_shai_hulud_timeline_hits \
            --argjson xeactor_installed $AUR_SUMMARY_xeactor_installed \
            --argjson xeactor_high_risk $AUR_SUMMARY_xeactor_high_risk \
            --argjson xeactor_timeline_hits $AUR_SUMMARY_xeactor_timeline_hits \
            --arg report_file "$report_file_arg" \
            --arg list_sha256 "$list_sha256" \
            --arg chaos_rat_list_sha256 "$chaos_rat_list_sha256" \
            --argjson findings_atomic_arch_installed "$jq_infected" \
            --argjson findings_atomic_arch_high_risk "$jq_high_risk" \
            --argjson findings_unknown_window_pkgs "$jq_unknown" \
            --argjson findings_atomic_arch_timeline_hits "$jq_timeline" \
            --argjson findings_atomic_arch_timeline_repeat_updates "$jq_timeline_repeat" \
            --argjson findings_artifacts "$jq_artifacts" \
            --argjson findings_runtime_iocs "$jq_runtime" \
            --argjson findings_insufficient_data "$jq_insufficient" \
            --argjson findings_chaos_rat_installed "$jq_chaos_rat" \
            --argjson findings_chaos_rat_high_risk "$jq_chaos_high" \
            --argjson findings_chaos_rat_timeline_hits "$jq_chaos_timeline" \
            --argjson findings_shai_hulud_installed "$jq_shai_hulud" \
            --argjson findings_shai_hulud_high_risk "$jq_shai_high" \
            --argjson findings_shai_hulud_timeline_hits "$jq_shai_timeline" \
            --argjson findings_xeactor_installed "$jq_xeactor" \
            --argjson findings_xeactor_high_risk "$jq_xeactor_high" \
            --argjson findings_xeactor_timeline_hits "$jq_xeactor_timeline" \
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
              atomic_arch_installed: $atomic_arch_installed,
              atomic_arch_high_risk: $atomic_arch_high_risk,
              atomic_arch_timeline_hits: $atomic_arch_timeline_hits,
              atomic_arch_timeline_repeat_updates: $atomic_arch_timeline_repeat_updates,
              window_aur_pkgs: $window_aur_pkgs,
              artifact_critical: $artifact_critical,
              credential_exposed: $credential_exposed,
              hardening_warn: $hardening_warn,
              list_added: $list_added,
              list_removed: $list_removed,
              insufficient_data: $insufficient_data,
              runtime_iocs: $runtime_iocs,
              chaos_rat_installed: $chaos_rat_installed,
              chaos_rat_high_risk: $chaos_rat_high_risk,
              chaos_rat_timeline_hits: $chaos_rat_timeline_hits,
              shai_hulud_installed: $shai_hulud_installed,
              shai_hulud_high_risk: $shai_hulud_high_risk,
              shai_hulud_timeline_hits: $shai_hulud_timeline_hits,
              xeactor_installed: $xeactor_installed,
              xeactor_high_risk: $xeactor_high_risk,
              xeactor_timeline_hits: $xeactor_timeline_hits,
              report_file: $report_file,
              list_sha256: $list_sha256,
              chaos_rat_list_sha256: $chaos_rat_list_sha256,
              findings: {
                atomic_arch_installed: $findings_atomic_arch_installed,
                atomic_arch_high_risk: $findings_atomic_arch_high_risk,
                unknown_window_pkgs: $findings_unknown_window_pkgs,
                atomic_arch_timeline_hits: $findings_atomic_arch_timeline_hits,
                atomic_arch_timeline_repeat_updates: $findings_atomic_arch_timeline_repeat_updates,
                artifacts: $findings_artifacts,
                runtime_iocs: $findings_runtime_iocs,
                insufficient_data: $findings_insufficient_data,
                chaos_rat_installed: $findings_chaos_rat_installed,
                chaos_rat_high_risk: $findings_chaos_rat_high_risk,
                chaos_rat_timeline_hits: $findings_chaos_rat_timeline_hits,
                shai_hulud_installed: $findings_shai_hulud_installed,
                shai_hulud_high_risk: $findings_shai_hulud_high_risk,
                shai_hulud_timeline_hits: $findings_shai_hulud_timeline_hits,
                xeactor_installed: $findings_xeactor_installed,
                xeactor_high_risk: $findings_xeactor_high_risk,
                xeactor_timeline_hits: $findings_xeactor_timeline_hits,
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
  "atomic_arch_installed": %s,
  "atomic_arch_high_risk": %s,
  "atomic_arch_timeline_hits": %s,
  "atomic_arch_timeline_repeat_updates": %s,
  "window_aur_pkgs": %s,
  "artifact_critical": %s,
  "credential_exposed": %s,
  "hardening_warn": %s,
  "list_added": %s,
  "list_removed": %s,
  "insufficient_data": %s,
  "runtime_iocs": %s,
  "chaos_rat_installed": %s,
  "chaos_rat_high_risk": %s,
  "chaos_rat_timeline_hits": %s,
  "shai_hulud_installed": %s,
  "shai_hulud_high_risk": %s,
  "shai_hulud_timeline_hits": %s,
  "xeactor_installed": %s,
  "xeactor_high_risk": %s,
  "xeactor_timeline_hits": %s,
  "report_file": "%s",
  "list_sha256": "%s",
  "chaos_rat_list_sha256": "%s",
  "findings": {
    "atomic_arch_installed": %s,
    "atomic_arch_high_risk": %s,
    "unknown_window_pkgs": %s,
    "atomic_arch_timeline_hits": %s,
    "atomic_arch_timeline_repeat_updates": %s,
    "artifacts": %s,
    "runtime_iocs": %s,
    "insufficient_data": %s,
    "chaos_rat_installed": %s,
    "chaos_rat_high_risk": %s,
    "chaos_rat_timeline_hits": %s,
    "shai_hulud_installed": %s,
    "shai_hulud_high_risk": %s,
    "shai_hulud_timeline_hits": %s,
    "xeactor_installed": %s,
    "xeactor_high_risk": %s,
    "xeactor_timeline_hits": %s,
    "audit_ssh_keys": %s,
    "audit_git_paths": %s,
    "audit_docker_paths": %s,
    "audit_env_files": %s,
    "audit_history_files": %s
  }
}\n' \
        $ts $AUR_VERSION $host $exit_code $severity \
        $AUR_SUMMARY_atomic_arch_installed $AUR_SUMMARY_atomic_arch_high_risk \
        $AUR_SUMMARY_atomic_arch_timeline_hits $AUR_SUMMARY_atomic_arch_timeline_repeat_updates $AUR_SUMMARY_window_aur_pkgs \
        $AUR_SUMMARY_artifact_critical $AUR_SUMMARY_credential_exposed \
        $AUR_SUMMARY_hardening_warn $AUR_SUMMARY_list_added $AUR_SUMMARY_list_removed \
        $AUR_SUMMARY_insufficient_data $AUR_SUMMARY_runtime_iocs \
        $AUR_SUMMARY_chaos_rat_installed \
        $AUR_SUMMARY_chaos_rat_high_risk $AUR_SUMMARY_chaos_rat_timeline_hits \
        $AUR_SUMMARY_shai_hulud_installed \
        $AUR_SUMMARY_shai_hulud_high_risk $AUR_SUMMARY_shai_hulud_timeline_hits \
        $AUR_SUMMARY_xeactor_installed \
        $AUR_SUMMARY_xeactor_high_risk $AUR_SUMMARY_xeactor_timeline_hits \
        $report_file $list_sha256 $chaos_rat_list_sha256 \
        (aur_json_string_array $finding_infected) \
        (aur_json_string_array $finding_high_risk) \
        (aur_json_string_array $finding_unknown) \
        (aur_json_string_array $finding_timeline) \
        (aur_json_string_array $finding_timeline_repeat) \
        (aur_json_string_array $finding_artifacts) \
        (aur_json_string_array $finding_runtime) \
        (aur_json_string_array $finding_insufficient) \
        (aur_json_string_array $finding_chaos_rat) \
        (aur_json_string_array $finding_chaos_high) \
        (aur_json_string_array $finding_chaos_timeline) \
        (aur_json_string_array $finding_shai_hulud) \
        (aur_json_string_array $finding_shai_high) \
        (aur_json_string_array $finding_shai_timeline) \
        (aur_json_string_array $finding_xeactor) \
        (aur_json_string_array $finding_xeactor_high) \
        (aur_json_string_array $finding_xeactor_timeline) \
        (aur_json_string_array $audit_ssh) \
        (aur_json_string_array $audit_git) \
        (aur_json_string_array $audit_docker) \
        (aur_json_string_array $audit_env) \
        (aur_json_string_array $audit_history) >$AUR_SUMMARY_FILE
    cp $AUR_SUMMARY_FILE $AUR_FINDINGS_FILE
end
