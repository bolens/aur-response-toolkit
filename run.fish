#!/usr/bin/env fish

# AUR malware response — full scan orchestrator

set -g AUR_RESPONSE_DIR (dirname (status filename))
source $AUR_RESPONSE_DIR/lib/common.fish

set -l use_local false
set -l force_audit false
set -l write_report false
set -l output_json false
set -l skip_pkg_check false
set -l exit_code 0

for arg in $argv
    switch $arg
        case --local; set use_local true
        case --audit; set force_audit true
        case --report; set write_report true
        case --json; set output_json true
        case --skip-pkg-check; set skip_pkg_check true
        case --help -h
            echo "Usage: run.fish [--local] [--audit] [--report] [--json]"
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
            echo "Helpers: remove-infected.fish  rotate-hints.fish  scrub-history.fish"
            exit 0
    end
end

if test $write_report = true
    aur_begin_report full-scan-
end

aur_state_init

function run_step --argument-names label script extra_args
    aur_log ">>> $label"
    aur_log ""
    fish $AUR_RESPONSE_DIR/$script $extra_args
    set -l step_status $status
    aur_log ""
    return $step_status
end

set -l step_args
test $use_local = true; and set -a step_args --local
test $write_report = true; and set -a step_args --report

aur_log "############################################"
aur_log "# AUR malware response — full scan"
aur_log "############################################"
aur_log ""

# Step 1
if test $skip_pkg_check = false
    set -l pkg_args $step_args --no-chain
    run_step "Step 1/7: Infected package scan" check-infected-pkgs.fish $pkg_args
    set -l s $status
    test $s -ne 0; and set exit_code $s; and set force_audit true
end

# Step 2
run_step "Step 2/7: AUR activity window" scan-aur-window.fish $step_args
set -l s $status
test $s -ne 0; and set exit_code $s; and set force_audit true

# Step 3
run_step "Step 3/7: Pacman timeline" scan-pacman-timeline.fish $step_args
set -l s $status
test $s -ne 0; and set exit_code $s; and set force_audit true

# Step 4
run_step "Step 4/7: Malware artifacts" scan-malware-artifacts.fish $step_args
set -l s $status
test $s -ne 0; and set exit_code $s; and set force_audit true

# Step 5
run_step "Step 5/7: Build hardening" scan-hardening.fish $step_args
set -l s $status
test $s -ne 0; and set exit_code $s

# Step 6 & 7
if test $force_audit = true
    run_step "Step 6/7: Credential audit" audit-stolen-credentials.fish $step_args
    set -l s $status
    test $s -ne 0; and set exit_code $s

    run_step "Step 7/7: Rotation hints" rotate-hints.fish
else
    aur_log ">>> Step 6/7: Credential audit skipped (use --audit to force)"
    aur_log ">>> Step 7/7: Rotation hints skipped"
    aur_log ""
end

aur_state_load_summary
aur_print_summary_dashboard $exit_code
aur_write_summary_json $exit_code

aur_log ""
aur_log "############################################"
if test $exit_code -ne 0
    aur_log "# Result: ISSUES FOUND (exit $exit_code)"
else
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
