#!/usr/bin/env fish

source (dirname (dirname (status filename)))/lib/test-utils.fish

test_reset_counters
test_section "findings persistence"

set -l _state $AUR_STATE_FILE
set -l _reports $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"
aur_state_init
aur_finding_add installed_infected beef
aur_finding_add installed_infected foo
aur_finding_add timeline_hits "line-one"
set -l list (aur_finding_list installed_infected)
assert_eq "two infected findings" 2 (count $list)
assert_contains "beef in findings" beef (string join \n -- $list)
assert_eq "foo finding" foo $list[2]

test_section "exit code finalization"
set -g AUR_OPT_fail_on all
assert_eq "compromise exit" $AUR_EXIT_COMPROMISE (aur_finalize_exit true false false | tail -1)
assert_eq "warn exit" $AUR_EXIT_WARN (aur_finalize_exit false true false | tail -1)
assert_eq "insufficient exit" $AUR_EXIT_INSUFFICIENT (aur_finalize_exit false false true | tail -1)
set -g AUR_OPT_fail_on compromise
assert_eq "warn ignored with fail-on compromise" $AUR_EXIT_CLEAN (aur_finalize_exit false true false | tail -1)
assert_eq "compromise with fail-on compromise" $AUR_EXIT_COMPROMISE (aur_finalize_exit true false false | tail -1)

test_section "version flag"
set -l ver_out (fish $AUR_RESPONSE_DIR/run.fish --version 2>&1 | string collect)
assert_match "version prints semver" 'atomic-arch-response-toolkit 1\.2\.0' "$ver_out"

rm -rf $AUR_REPORTS_DIR
set -g AUR_STATE_FILE $_state
set -g AUR_REPORTS_DIR $_reports

test_finish "test-exit-findings.fish"
exit $status
