#!/usr/bin/env fish

source (dirname (dirname (status filename)))/lib/test-utils.fish

test_reset_counters
test_section "summary json output"

set -l _summary $AUR_SUMMARY_FILE
set -l _reports $AUR_REPORTS_DIR
set -l _list $AUR_LIST_FILE
set -g AUR_REPORTS_DIR (mktemp -d)
set -g AUR_SUMMARY_FILE "$AUR_REPORTS_DIR/latest-summary.json"
set -g AUR_LIST_FILE (test_fixture_path infected-pkgs.txt)

set -g AUR_SUMMARY_installed_infected 1
set -g AUR_SUMMARY_installed_high_risk 0
set -g AUR_SUMMARY_timeline_hits 2
set -g AUR_SUMMARY_window_aur_pkgs 5
set -g AUR_SUMMARY_artifact_critical 0
set -g AUR_SUMMARY_credential_exposed 3
set -g AUR_SUMMARY_hardening_warn 1
set -g AUR_SUMMARY_list_added 0
set -g AUR_SUMMARY_list_removed 0

aur_write_summary_json 1
test -f $AUR_SUMMARY_FILE
assert_status "json file written" 0

if command -q jq
    assert_eq "json exit_code" 1 (jq -r .exit_code $AUR_SUMMARY_FILE)
    assert_eq "json timeline_hits" 2 (jq -r .timeline_hits $AUR_SUMMARY_FILE)
    assert_match "json list_sha256 present" '.+' (jq -r .list_sha256 $AUR_SUMMARY_FILE)
    set -l parsed (jq . $AUR_SUMMARY_FILE 2>/dev/null)
    assert_status "json parses cleanly" 0
else
    assert_match "fallback json exit_code" '"exit_code": 1' (cat $AUR_SUMMARY_FILE)
    assert_match "fallback list_sha256" '"list_sha256": "[a-f0-9]+"' (cat $AUR_SUMMARY_FILE)
end

rm -rf $AUR_REPORTS_DIR
set -g AUR_SUMMARY_FILE $_summary
set -g AUR_REPORTS_DIR $_reports
set -g AUR_LIST_FILE $_list

test_section "common args parsing"
aur_parse_common_args --local --report --quiet
assert_eq "opt local" true $AUR_OPT_local
assert_eq "opt report" true $AUR_OPT_report
assert_eq "opt quiet" true $AUR_OPT_quiet
aur_parse_common_args
assert_eq "opt reset local" false $AUR_OPT_local

test_finish "test-state-json.fish"
exit $status
