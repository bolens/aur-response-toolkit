#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "findings persistence"

set -l _state $AUR_STATE_FILE
set -l _reports $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"
aur_state_init
aur_finding_add atomic_arch_installed beef
aur_finding_add atomic_arch_installed foo
aur_finding_add atomic_arch_timeline_hits line-one
set -l list (aur_finding_list atomic_arch_installed)
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

test_section "fail-on none suppresses all severities"
set -g AUR_OPT_fail_on none
assert_eq "compromise suppressed with fail-on none" $AUR_EXIT_CLEAN (aur_finalize_exit true false false | tail -1)
assert_eq "chaos rat suppressed with fail-on none" $AUR_EXIT_CLEAN (aur_finalize_exit false false false true | tail -1)
assert_eq "shai hulud suppressed with fail-on none" $AUR_EXIT_CLEAN (aur_finalize_exit false false false false true | tail -1)
assert_eq "insufficient suppressed with fail-on none" $AUR_EXIT_CLEAN (aur_finalize_exit false false true | tail -1)
set -g AUR_OPT_fail_on all

test_section "fail-on campaign does not suppress atomic compromise"
set -g AUR_OPT_fail_on chaos-rat
assert_eq "atomic compromise still exits 1 under fail-on chaos-rat" $AUR_EXIT_COMPROMISE (aur_finalize_exit true false false | tail -1)
assert_eq "generic warn suppressed under fail-on chaos-rat" $AUR_EXIT_CLEAN (aur_finalize_exit false true false | tail -1)
set -g AUR_OPT_fail_on all

test_section "version flag"
set -l ver_out (fish $AUR_RESPONSE_DIR/run.fish --version 2>&1 | string collect)
assert_match "version prints semver" "aur-response-toolkit $AUR_VERSION" "$ver_out"

rm -rf $AUR_REPORTS_DIR
set -g AUR_STATE_FILE $_state
set -g AUR_REPORTS_DIR $_reports

test_finish "test-exit-findings.fish"
exit $status
