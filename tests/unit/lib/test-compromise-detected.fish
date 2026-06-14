#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "compromise detection for audit exit policy"

set -l _state $AUR_STATE_FILE
set -l _reports $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"

set -l compromised false
if aur_compromise_detected
    set compromised true
end
assert_eq "no stale compromise flag" false $compromised

aur_mark_compromised
set compromised false
if aur_compromise_detected
    set compromised true
end
assert_eq "compromise flag detected" true $compromised

rm -rf $AUR_REPORTS_DIR
set -g AUR_STATE_FILE $_state
set -g AUR_REPORTS_DIR $_reports

test_finish "test-compromise-detected.fish"
exit $status
