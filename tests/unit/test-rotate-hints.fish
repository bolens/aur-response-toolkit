#!/usr/bin/env fish

source (dirname (dirname (status filename)))/lib/test-utils.fish

test_reset_counters
test_section "rotate-hints SSH from audit findings"

set -l _state $AUR_STATE_FILE
set -l _reports $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"
aur_state_init
aur_finding_add audit_ssh_keys /home/test/.ssh/id_ed25519

set -l tmp_home (mktemp -d)
set -l hints (env AUR_STATE_FILE=$AUR_STATE_FILE HOME=$tmp_home fish $AUR_SCRIPTS_DIR/rotate-hints.fish 2>&1 | string collect)
assert_match "ssh keygen hint" 'ssh-keygen -t ed25519 -f /home/test/.ssh/id_ed25519.new' "$hints"

rm -rf $AUR_REPORTS_DIR $tmp_home
set -g AUR_STATE_FILE $_state
set -g AUR_REPORTS_DIR $_reports

test_finish "test-rotate-hints.fish"
exit $status
