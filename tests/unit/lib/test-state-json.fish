#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "summary json output"

set -l _summary $AUR_SUMMARY_FILE
set -l _reports $AUR_REPORTS_DIR
set -l _had_test_list false
if set -q AUR_TEST_LIST_FILE
    set -l _saved_list $AUR_TEST_LIST_FILE
    set _had_test_list true
end
set -g AUR_REPORTS_DIR (mktemp -d)
set -g AUR_SUMMARY_FILE "$AUR_REPORTS_DIR/latest-summary.json"
test_set_fixture_list lists/atomic-arch-pkgs.txt

set -g AUR_SUMMARY_atomic_arch_installed 1
set -g AUR_SUMMARY_atomic_arch_high_risk 0
set -g AUR_SUMMARY_atomic_arch_timeline_hits 2
set -g AUR_SUMMARY_window_aur_pkgs 5
set -g AUR_SUMMARY_artifact_critical 0
set -g AUR_SUMMARY_credential_exposed 3
set -g AUR_SUMMARY_hardening_warn 1
set -g AUR_SUMMARY_list_added 0
set -g AUR_SUMMARY_list_removed 0
set -g AUR_SUMMARY_insufficient_data 0
set -g AUR_SUMMARY_runtime_iocs 0
set -g AUR_SUMMARY_chaos_rat_installed 2
set -g AUR_SUMMARY_chaos_rat_high_risk 1
set -g AUR_SUMMARY_chaos_rat_timeline_hits 3
set -g AUR_SUMMARY_shai_hulud_installed 1
set -g AUR_SUMMARY_shai_hulud_high_risk 1
set -g AUR_SUMMARY_shai_hulud_timeline_hits 0
set -g AUR_SUMMARY_xeactor_installed 0
set -g AUR_SUMMARY_xeactor_high_risk 0
set -g AUR_SUMMARY_xeactor_timeline_hits 1

set -gx AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"
aur_state_init
aur_finding_add atomic_arch_timeline_hits "sample hit line"
aur_finding_add atomic_arch_installed beef
aur_finding_add chaos_rat_installed librewolf-fix-bin
aur_finding_add shai_hulud_installed gnome-vfs
aur_finding_add xeactor_timeline_hits acroread

aur_write_summary_json 1
test -f $AUR_SUMMARY_FILE
assert_status "json file written" 0

if command -q jq
    assert_eq "json exit_code" 1 (jq -r .exit_code $AUR_SUMMARY_FILE)
    assert_eq "json atomic_arch_timeline_hits" 2 (jq -r .atomic_arch_timeline_hits $AUR_SUMMARY_FILE)
    assert_eq "json version" "$AUR_VERSION" (jq -r .version $AUR_SUMMARY_FILE)
    assert_eq "json severity" "critical" (jq -r .severity $AUR_SUMMARY_FILE)
    assert_match "json list_sha256 present" '.+' (jq -r .list_sha256 $AUR_SUMMARY_FILE)
    assert_eq "json findings beef" "beef" (jq -r '.findings.atomic_arch_installed[0]' $AUR_SUMMARY_FILE)
    assert_eq "json chaos_rat_installed counter" 2 (jq -r .chaos_rat_installed $AUR_SUMMARY_FILE)
    assert_eq "json shai_hulud_installed counter" 1 (jq -r .shai_hulud_installed $AUR_SUMMARY_FILE)
    assert_eq "json xeactor_timeline_hits counter" 1 (jq -r .xeactor_timeline_hits $AUR_SUMMARY_FILE)
    assert_eq "json chaos_rat finding" "librewolf-fix-bin" (jq -r '.findings.chaos_rat_installed[0]' $AUR_SUMMARY_FILE)
    assert_eq "json shai_hulud finding" "gnome-vfs" (jq -r '.findings.shai_hulud_installed[0]' $AUR_SUMMARY_FILE)
    assert_eq "json xeactor timeline finding" "acroread" (jq -r '.findings.xeactor_timeline_hits[0]' $AUR_SUMMARY_FILE)
    set -l parsed (jq . $AUR_SUMMARY_FILE 2>/dev/null)
    assert_status "json parses cleanly" 0
else
    assert_match "fallback json exit_code" '"exit_code": 1' (cat $AUR_SUMMARY_FILE)
    assert_match "fallback list_sha256" '"list_sha256": "[a-f0-9]+"' (cat $AUR_SUMMARY_FILE)
end

rm -rf $AUR_REPORTS_DIR
set -g AUR_SUMMARY_FILE $_summary
set -g AUR_REPORTS_DIR $_reports
if test $_had_test_list = true
    set -gx AUR_TEST_LIST_FILE $_saved_list
else
    test_clear_list_file
end

test_section "common args parsing"
aur_parse_common_args --local --report --quiet
assert_eq "opt local" true $AUR_OPT_local
assert_eq "opt report" true $AUR_OPT_report
assert_eq "opt quiet" true $AUR_OPT_quiet
aur_parse_common_args --all-time
assert_eq "opt all-time" true $AUR_OPT_all_time
aur_parse_common_args
assert_eq "opt reset local" false $AUR_OPT_local
assert_eq "opt reset all-time" false $AUR_OPT_all_time

test_finish "test-state-json.fish"
exit $status
