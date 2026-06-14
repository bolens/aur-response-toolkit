#!/usr/bin/env fish

source (dirname (dirname (status filename)))/lib/test-utils.fish

test_reset_counters
test_section "hook pattern detection"

begin
    aur_file_has_hook_pattern (test_fixture_path PKGBUILD.malicious)
    assert_status "malicious PKGBUILD detected" 0
end
begin
    aur_file_has_hook_pattern (test_fixture_path PKGBUILD.clean)
    assert_status "clean PKGBUILD passes" 1
end

test_section "env and history secrets"
begin
    aur_env_has_secrets (test_fixture_path env-secrets.env)
    assert_status "env with TOKEN detected" 0
end
begin
    aur_env_has_secrets (test_fixture_path env-clean.env)
    assert_status "clean env passes" 1
end

assert_eq "history secret hits" 2 (aur_history_secret_hits (test_fixture_path history-secrets.txt))

test_section "json escaping"
assert_eq "escape quotes" 'say \"hi\"' (aur_json_escape 'say "hi"')
begin
    string match -qr '\\\\' (aur_json_escape 'path\to')
    assert_status "escape backslash doubles" 0
end

test_section "state file roundtrip"
set -l _state $AUR_STATE_FILE
set -l _reports $AUR_REPORTS_DIR
set -g AUR_REPORTS_DIR (mktemp -d)
set -g AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"
aur_state_init
aur_summary_set timeline_hits 3
aur_summary_set list_added 2
assert_eq "state get timeline" 3 (aur_state_get timeline_hits)
assert_eq "state get list_added" 2 (aur_state_get list_added)
set -g AUR_SUMMARY_timeline_hits 0
aur_state_load_summary
assert_eq "state load summary" 3 $AUR_SUMMARY_timeline_hits
rm -rf $AUR_REPORTS_DIR
set -g AUR_STATE_FILE $_state
set -g AUR_REPORTS_DIR $_reports

test_section "quiet logging"
set -l _quiet $AUR_OPT_quiet
set -g AUR_OPT_quiet true
set -l quiet_out (aur_log "should-not-print")
set -g AUR_OPT_quiet false
set -l loud_out (aur_log "should-print")
assert_eq "quiet suppresses stdout" "" $quiet_out
assert_eq "normal logs print" "should-print" $loud_out
set -g AUR_OPT_quiet $_quiet

test_finish "test-hooks-secrets.fish"
exit $status
