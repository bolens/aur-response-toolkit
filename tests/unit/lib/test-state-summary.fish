#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "state key overwrite and summary increment"

set -l _state $AUR_STATE_FILE
set -l _reports $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"
aur_state_init

aur_state_set atomic_arch_timeline_hits 1
aur_state_set atomic_arch_timeline_hits 5
assert_eq "state set overwrites key" 5 (aur_state_get atomic_arch_timeline_hits)

set -g AUR_SUMMARY_atomic_arch_timeline_hits 0
aur_summary_set atomic_arch_timeline_hits 0
aur_summary_inc atomic_arch_timeline_hits 2
aur_summary_inc atomic_arch_timeline_hits 3
assert_eq "summary inc persists" 5 (aur_state_get atomic_arch_timeline_hits)
assert_eq "summary inc updates memory" 5 $AUR_SUMMARY_atomic_arch_timeline_hits

test_section "insufficient data records finding and counter"

set -l _quiet $AUR_OPT_quiet
set -g AUR_OPT_quiet true
aur_insufficient_data "pacman logs unreadable in test"
set -g AUR_OPT_quiet $_quiet
assert_eq "insufficient counter" 1 (aur_state_get insufficient_data)
assert_eq "insufficient finding" "pacman logs unreadable in test" (aur_finding_list insufficient_data)[1]

test_section "finalize exit priority with fail-on compromise"

set -g AUR_OPT_fail_on compromise
assert_eq "insufficient beats fail-on compromise" $AUR_EXIT_INSUFFICIENT (aur_finalize_exit true true true | tail -1)
assert_eq "compromise with fail-on compromise" $AUR_EXIT_COMPROMISE (aur_finalize_exit true false false | tail -1)
assert_eq "warn suppressed under fail-on compromise" $AUR_EXIT_CLEAN (aur_finalize_exit false true false | tail -1)
set -g AUR_OPT_fail_on all

test_section "report file is singleton per run"

set -l _report $AUR_REPORT_FILE[1]
set -e AUR_REPORT_FILE
set -g AUR_OPT_report false
aur_begin_report test-report-
set -l first $AUR_REPORT_FILE
aur_begin_report test-report-
assert_eq "second begin_report reuses file" $first $AUR_REPORT_FILE
test -f $first
assert_status "report file exists" 0
if set -q _report[1]
    set -gx AUR_REPORT_FILE $_report
else
    set -e AUR_REPORT_FILE
end

rm -rf $AUR_REPORTS_DIR
set -g AUR_STATE_FILE $_state
set -g AUR_REPORTS_DIR $_reports

test_finish "test-state-summary.fish"
exit $status
