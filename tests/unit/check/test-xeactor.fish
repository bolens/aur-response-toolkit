#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "xeactor disabled by default"

set -l out (mktemp)
fish (aur_script_path check/xeactor-pkgs.fish) >$out 2>&1
assert_eq "disabled scan exits clean" $AUR_EXIT_CLEAN $status
assert_match "skipped message" 'xeactor scan skipped' (cat $out)
rm -f $out

test_section "xeactor list load (local)"

test_set_xeactor_list lists/xeactor-pkgs.txt
set -g AUR_OPT_quiet true
set -g AUR_OPT_xeactor true
begin
    aur_load_xeactor_list true >/dev/null 2>&1
    assert_status "local legacy list loads" 0
end
set -l pkgs (aur_load_xeactor_list true | string collect)
assert_contains "fixture legacy pkg" legacy-pkg-a "$pkgs"
assert_contains "fixture acroread" acroread "$pkgs"

test_section "xeactor window install date helpers"

set -l info_file (mktemp)
echo 'acroread|Thu 07 Jun 2018 10:00:00|Explicitly installed' >$info_file
set -gx AUR_TEST_PKG_INFO $info_file
begin
    aur_install_in_xeactor_window acroread
    assert_status "Jun 7 2018 in legacy window" 0
end
echo 'acroread|Mon 02 Feb 2020 12:53:53|Explicitly installed' >$info_file
begin
    aur_install_in_xeactor_window acroread
    assert_status "Feb 2020 outside legacy window" 1
end
set -e AUR_TEST_PKG_INFO
rm -f $info_file

test_section "xeactor scan HIGH/LOW by install window"

set -l log_dir (mktemp -d)
echo 'legacy-pkg-a|Thu 07 Jun 2018 20:00:00|Explicitly installed' >$log_dir/pkg-info.txt
echo 'balz|Mon 02 Feb 2020 12:53:53|Explicitly installed' >>$log_dir/pkg-info.txt
set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' clean-aur legacy-pkg-a balz >$AUR_TEST_INSTALLED_LIST
set -gx AUR_TEST_PKG_INFO $log_dir/pkg-info.txt

set -l scan_out (mktemp)
fish (aur_script_path check/xeactor-pkgs.fish) --xeactor --local >$scan_out 2>&1
assert_eq "xeactor hits exit warn" $AUR_EXIT_WARN $status
set -l scan_text (cat $scan_out | string collect)
assert_match "in-window HIGH" '\[HIGH\].*legacy-pkg-a' "$scan_text"
assert_match "outside window LOW" '\[LOW\].*balz' "$scan_text"
assert_match "window label in LOW line" 'outside Jun 7–Jul 10, 2018' "$scan_text"
rm -f $scan_out $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_PKG_INFO
rm -rf $log_dir

test_section "xeactor timeline window vs all-time"

set -l log_dir (mktemp -d)
echo '[2018-06-07T10:00:00+0000] [ALPM] installed acroread (9.5.5-8)' >$log_dir/pacman.log
echo '[2020-02-01T08:00:00-0600] [ALPM] installed legacy-pkg-a (1-1)' >>$log_dir/pacman.log
set -gx AUR_TEST_PACMAN_LOG_DIR $log_dir
test_set_xeactor_list lists/xeactor-pkgs.txt

set -l window_out (mktemp)
fish (aur_script_path scan/xeactor-timeline.fish) --xeactor --local >$window_out 2>&1
set -l window_code $status
set -l window_text (cat $window_out | string collect)

set -l alltime_out (mktemp)
fish (aur_script_path scan/xeactor-timeline.fish) --xeactor --local --all-time >$alltime_out 2>&1
set -l alltime_code $status
set -l alltime_text (cat $alltime_out | string collect)

assert_eq "window mode finds Jun install only" $AUR_EXIT_WARN $window_code
assert_match "acroread in window timeline" 'acroread' "$window_text"
assert_not_match "Feb legacy pkg excluded from window timeline" 'legacy-pkg-a' "$window_text"
assert_eq "all-time timeline finds both" $AUR_EXIT_WARN $alltime_code
assert_match "all-time acroread hit" 'acroread' "$alltime_text"
assert_match "all-time legacy-pkg-a hit" 'legacy-pkg-a' "$alltime_text"

rm -f $window_out $alltime_out
set -e AUR_TEST_PACMAN_LOG_DIR
rm -rf $log_dir

test_section "fail-on xeactor mode"

set -g AUR_OPT_fail_on xeactor
assert_eq "xeactor triggers exit 2" $AUR_EXIT_WARN (aur_finalize_exit false false false false false true | tail -1)
assert_eq "generic warn suppressed" $AUR_EXIT_CLEAN (aur_finalize_exit false true false false false false | tail -1)
set -g AUR_OPT_fail_on all

test_section "remove-packages --list xeactor dry-run"

set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' legacy-pkg-a >$AUR_TEST_INSTALLED_LIST
set -l remove_out (mktemp)
fish (aur_script_path recovery/remove-packages.fish) --list xeactor --dry-run >$remove_out 2>&1
assert_eq "xeactor dry-run clean" $AUR_EXIT_CLEAN $status
assert_match "legacy pkg in removal list" 'legacy-pkg-a' (cat $remove_out | string collect)
rm -f $remove_out $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST

test_section "config enables xeactor without cli flag"

set -l _enable $AUR_ENABLE_XEACTOR
set -g AUR_ENABLE_XEACTOR 1
set -g AUR_OPT_xeactor false
begin
    aur_xeactor_enabled
    assert_status "AUR_ENABLE_XEACTOR=1 enables scan" 0
end
set -g AUR_ENABLE_XEACTOR $_enable
set -g AUR_OPT_xeactor false

test_section "xeactor remote fetch saves list and sha256"

set -l _reports $AUR_REPORTS_DIR
set -l _findings $AUR_FINDINGS_LIST_FILE
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_FINDINGS_LIST_FILE "$AUR_REPORTS_DIR/.scan-findings.list"
aur_state_init
set -l fetch_fixture (mktemp)
printf '%s\n' xeactor-extra acroread >$fetch_fixture
set -l out_list (mktemp)
set -gx AUR_TEST_XEACTOR_LIST_FILE $out_list
set -g AUR_XEACTOR_URL https://example.invalid/xeactor-pkgs.txt
test_set_xeactor_fetch_fixture $fetch_fixture
set -g AUR_OPT_quiet true
set -l fetched (aur_load_xeactor_list false | string collect)
assert_status "remote fetch succeeds via test fixture" 0
assert_match "fetched xeactor-extra" 'xeactor-extra' "$fetched"
assert_match "fetched acroread" 'acroread' "$fetched"
test -f $out_list
assert_status "fetched xeactor list written" 0
set -l sha_findings (aur_finding_list xeactor_list_sha256 | string collect)
assert_match "xeactor fetch sha256 recorded" 'xeactor=[a-f0-9]{64}' "$sha_findings"
rm -f $fetch_fixture $out_list
test_clear_xeactor_fetch
set -g AUR_XEACTOR_URL ""
set -g AUR_REPORTS_DIR $_reports
if set -q _findings[1]
    set -gx AUR_FINDINGS_LIST_FILE $_findings
else
    set -e AUR_FINDINGS_LIST_FILE
end

test_section "xeactor fetch failure falls back to bundled list"

set -l out_list (mktemp)
set -gx AUR_TEST_XEACTOR_LIST_FILE $out_list
cp (test_fixture_path lists/xeactor-pkgs.txt) $out_list
set -g AUR_XEACTOR_URL https://example.invalid/xeactor-pkgs.txt
test_set_xeactor_fetch_fail
set -g AUR_OPT_quiet true
set -l fallback (aur_load_xeactor_list false | string collect)
assert_status "xeactor fetch failure uses bundled" 0
assert_contains "fallback includes acroread" acroread "$fallback"
rm -f $out_list
test_clear_xeactor_fetch
set -g AUR_XEACTOR_URL ""

test_section "xeactor --all-time upgrades LOW to HIGH"

set -l log_dir (mktemp -d)
echo 'balz|Mon 02 Feb 2020 12:53:53|Explicitly installed' >$log_dir/pkg-info.txt
set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' balz >$AUR_TEST_INSTALLED_LIST
set -gx AUR_TEST_PKG_INFO $log_dir/pkg-info.txt
test_set_xeactor_list lists/xeactor-pkgs.txt

set -l window_out (mktemp)
fish (aur_script_path check/xeactor-pkgs.fish) --xeactor --local >$window_out 2>&1
set -l window_text (cat $window_out | string collect)
assert_match "outside window is LOW" '\[LOW\].*balz' "$window_text"

set -l alltime_out (mktemp)
fish (aur_script_path check/xeactor-pkgs.fish) --xeactor --local --all-time >$alltime_out 2>&1
set -l alltime_text (cat $alltime_out | string collect)
assert_match "all-time upgrades to HIGH" '\[HIGH\].*balz' "$alltime_text"

rm -f $window_out $alltime_out $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_PKG_INFO
rm -rf $log_dir

test_section "xeactor clean install set"

set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' clean-aur-only >$AUR_TEST_INSTALLED_LIST
test_set_xeactor_list lists/xeactor-pkgs.txt
fish (aur_script_path check/xeactor-pkgs.fish) --xeactor --local >/dev/null 2>&1
assert_eq "no xeactor hits exits clean" $AUR_EXIT_CLEAN $status
rm -f $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST

test_section "unknown xeactor flags rejected"

set -l bad_out (mktemp)
fish (aur_script_path check/xeactor-pkgs.fish) --xeactor --not-a-flag >$bad_out 2>&1
assert_eq "unknown xeactor flag exits invalid" $AUR_EXIT_INVALID $status
rm -f $bad_out

test_clear_xeactor_list
set -g AUR_OPT_xeactor false
set -g AUR_OPT_quiet false

test_finish "test-xeactor.fish"
exit $status
