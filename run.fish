#!/usr/bin/env fish

# AUR malware response — full scan orchestrator.
# Runs seven detection steps in order, aggregates exit severity, optional --recover wizard.

set -g AUR_RESPONSE_DIR (dirname (status filename))
source $AUR_RESPONSE_DIR/lib/common.fish

aur_parse_common_args $argv

set -l output_json false
set -l skip_pkg_check false
set -l recover_mode false
set -l compromise_found false
set -l warn_found false
set -l insufficient_found false
# force_audit gates steps 6–7; set by --audit/--recover or any compromise exit from steps 1–4.
set -l force_audit $AUR_OPT_audit

for arg in $argv
    switch $arg
        case --json
            set output_json true
        case --skip-pkg-check
            set skip_pkg_check true
        case --recover
            set recover_mode true
            set force_audit true
            set -g AUR_OPT_audit true
        case --version
            echo "atomic-arch-response-toolkit $AUR_VERSION"
            exit 0
        case --local --audit --report --quiet --quick --if-compromised
            # handled by aur_parse_common_args
        case --fail-on --fail-on=* --prune-days --prune-days=*
            # handled by aur_parse_common_args
        case --help -h
            echo "Usage: run.fish [--local] [--audit] [--report] [--json] [--quiet] [--recover]"
            echo "       [--quick] [--if-compromised] [--fail-on all|compromise|none] [--skip-pkg-check]"
            echo "       [--prune-days N]"
            echo ""
            echo "Exit codes:"
            echo "  0  clean"
            echo "  1  compromise indicators"
            echo "  2  warnings only (hardening, benign unknown AUR packages)"
            echo "  3  insufficient data (unreadable logs)"
            echo "  4  invalid arguments"
            echo ""
            echo "Steps:"
            echo "  1. Infected package scan"
            echo "  2. AUR activity window scan"
            echo "  3. Pacman timeline (known infected list)"
            echo "  4. Malware artifact scan"
            echo "  5. Build hardening check"
            echo "  6. Credential audit (if issues or --audit)"
            echo "  7. Rotation hints (if issues or --audit)"
            echo ""
            echo "  --recover     Interactive recovery wizard (remove → audit → rotate → scrub)"
            echo "  --quiet       Suppress scan output (still writes report/json)"
            echo "  --json        Print JSON summary to stdout at end"
            echo "  --prune-days  Delete report files older than N days"
            echo "  --version     Print toolkit version"
            echo ""
            echo "Helpers: scripts/remove-infected.fish  scripts/apply-hardening.fish  scripts/rotate-hints.fish"
            exit 0
        case '-*'
            echo "Unknown option: $arg" >&2
            exit $AUR_EXIT_INVALID
    end
end

# --recover prompts for user input; refuse when stdin is not a TTY (e.g. cron piping).
if test $recover_mode = true; and test $AUR_OPT_quiet = true
    if not test -t 0
        echo "error: --recover requires an interactive terminal (cannot use with --quiet on non-TTY stdin)" >&2
        exit $AUR_EXIT_INVALID
    end
end

if test $AUR_OPT_report = true
    aur_begin_report full-scan-
end

aur_state_init

# Each step runs in a subprocess so exit codes stay isolated; args propagate via step_args.
function run_step
    set -l label $argv[1]
    set -l script $argv[2]
    set -l script_args $argv[3..-1]
    aur_log ">>> $label"
    aur_log ""
    fish $AUR_SCRIPTS_DIR/$script $script_args
    set -l step_status $status
    aur_log ""
    return $step_status
end

# Map per-step exit codes into run-level severity flags for aur_finalize_exit.
function record_step_status
    set -l code $argv[1]
    switch $code
        case $AUR_EXIT_COMPROMISE
            set -g compromise_found true
        case $AUR_EXIT_WARN
            set -g warn_found true
        case $AUR_EXIT_INSUFFICIENT
            set -g insufficient_found true
    end
end

set -l step_args
# Forward orchestrator flags to every child script (local list, report, quiet, quick).
test $AUR_OPT_local = true; and set -a step_args --local
test $AUR_OPT_report = true; and set -a step_args --report
test $AUR_OPT_quiet = true; and set -a step_args --quiet
test $AUR_OPT_quick = true; and set -a step_args --quick

aur_log "############################################"
aur_log "# AUR malware response — full scan v$AUR_VERSION"
aur_log "############################################"
aur_log ""

# Step 1: installed packages vs known infected list (--no-chain avoids double audit; run.fish handles step 6).
if test $skip_pkg_check = false
    set -l pkg_args $step_args --no-chain
    run_step "Step 1/7: Infected package scan" check-infected-pkgs.fish $pkg_args
    record_step_status $status
    test $status -eq $AUR_EXIT_COMPROMISE; and set force_audit true
end

# Step 2: all foreign packages touched in window — catches packages not yet on public lists.
run_step "Step 2/7: AUR activity window" scan-aur-window.fish $step_args
record_step_status $status
test $status -eq $AUR_EXIT_COMPROMISE; and set force_audit true
test $status -eq $AUR_EXIT_INSUFFICIENT; and set insufficient_found true

# Step 3: pacman log intersection with infected list — catches removed packages still in logs.
run_step "Step 3/7: Pacman timeline" scan-pacman-timeline.fish $step_args
record_step_status $status
test $status -eq $AUR_EXIT_COMPROMISE; and set force_audit true
test $status -eq $AUR_EXIT_INSUFFICIENT; and set insufficient_found true

# Step 4: filesystem/runtime IOCs (deps ELF, hooks, eBPF, cron, etc.).
run_step "Step 4/7: Malware artifacts" scan-malware-artifacts.fish $step_args
record_step_status $status
test $status -eq $AUR_EXIT_COMPROMISE; and set force_audit true

# Step 5: preventive hardening checks (npm ignore-scripts, AUR helper settings).
run_step "Step 5/7: Build hardening" scan-hardening.fish $step_args
record_step_status $status

# Steps 6–7 run when compromise was found or user passed --audit/--recover.
# --if-compromised on audit avoids failing inventory-only runs when no compromise detected.
if test $force_audit = true
    set -l audit_args $step_args
    # Compromise-driven audit: inventory runs but only fails when upstream marked compromised.
    if test $force_audit = true; and test $AUR_OPT_audit = false
        set -a audit_args --if-compromised
    end
    run_step "Step 6/7: Credential audit" audit-stolen-credentials.fish $audit_args
    record_step_status $status

    run_step "Step 7/7: Rotation hints" rotate-hints.fish $step_args
else
    aur_log ">>> Step 6/7: Credential audit skipped (use --audit to force)"
    aur_log ">>> Step 7/7: Rotation hints skipped"
    aur_log ""
end

# Guided recovery: remove → rotate hints → scrub history → quick re-scan.
if test $recover_mode = true; and test $compromise_found = true
    aur_log "=== Recovery wizard ==="
    aur_log ""
    fish $AUR_SCRIPTS_DIR/remove-infected.fish --dry-run
    read -l -P "Run remove-infected.fish now? [y/N] " do_remove
    if string match -qi 'y*' -- $do_remove
        fish $AUR_SCRIPTS_DIR/remove-infected.fish
        fish $AUR_SCRIPTS_DIR/remove-infected.fish --verify
    end
    fish $AUR_SCRIPTS_DIR/rotate-hints.fish $step_args
    fish $AUR_SCRIPTS_DIR/scrub-history.fish --all-shells --dry-run
    read -l -P "Scrub shell histories (all shells)? [y/N] " do_scrub
    if string match -qi 'y*' -- $do_scrub
        fish $AUR_SCRIPTS_DIR/scrub-history.fish --all-shells
    end
    aur_log ""
    aur_log "=== Post-recovery verification scan ==="
    aur_log ""
    set -l verify_args --quiet --quick --no-chain
    test $AUR_OPT_local = true; and set -a verify_args --local
    fish $AUR_SCRIPTS_DIR/check-infected-pkgs.fish $verify_args
    set -l post_pkg $status
    fish $AUR_SCRIPTS_DIR/scan-malware-artifacts.fish --quiet --quick
    set -l post_artifacts $status
    # Post-recovery: only re-check install state and artifacts (not full 7-step scan).
    if test $post_pkg -eq $AUR_EXIT_COMPROMISE; or test $post_artifacts -eq $AUR_EXIT_COMPROMISE
        aur_log "[WARN] Post-recovery scan still reports compromise indicators."
        set compromise_found true
    else
        aur_log "[OK] Post-recovery quick scan found no compromise indicators."
    end
    aur_log ""
end

if test $AUR_OPT_prune_days -gt 0
    aur_prune_reports $AUR_OPT_prune_days
end

# Re-read child-script state (steps write compromised=1 via aur_mark_compromised).
aur_state_load_summary
test (aur_state_get compromised) -eq 1; and set compromise_found true

# aur_finalize_exit prints the code and returns it; tail -1 captures stdout reliably in fish.
set -l exit_code (aur_finalize_exit $compromise_found $warn_found $insufficient_found | tail -1)
aur_print_summary_dashboard $exit_code
aur_write_summary_json $exit_code

aur_log ""
aur_log "############################################"
switch $exit_code
    case $AUR_EXIT_COMPROMISE
        aur_log "# Result: COMPROMISE INDICATORS (exit $exit_code)"
    case $AUR_EXIT_WARN
        aur_log "# Result: WARNINGS ONLY (exit $exit_code)"
    case $AUR_EXIT_INSUFFICIENT
        aur_log "# Result: INSUFFICIENT DATA (exit $exit_code)"
        aur_log_insufficient_help
    case $AUR_EXIT_CLEAN
        aur_log "# Result: CLEAN"
end
if set -q AUR_REPORT_FILE[1]
    aur_log "# Report: $AUR_REPORT_FILE"
end
aur_log "############################################"

if test $output_json = true
    cat $AUR_SUMMARY_FILE
end

exit $exit_code
