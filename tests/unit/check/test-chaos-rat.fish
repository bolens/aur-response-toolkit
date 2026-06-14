#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "chaos rat disabled by default"

set -l out (mktemp)
fish (aur_script_path check/chaos-rat-pkgs.fish) >$out 2>&1
assert_eq "disabled scan exits clean" $AUR_EXIT_CLEAN $status
assert_match "skipped message" 'Chaos RAT scan skipped' (cat $out)
rm -f $out

test_section "chaos rat merged fetch records per-source sha256"

set -l _reports $AUR_REPORTS_DIR
set -l _findings $AUR_FINDINGS_LIST_FILE
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_FINDINGS_LIST_FILE "$AUR_REPORTS_DIR/.scan-findings.list"
set -l out_list (mktemp)
set -l out_prev (mktemp)
set -gx AUR_TEST_CHAOS_RAT_LIST_FILE $out_list
set -gx AUR_CHAOS_RAT_LIST_PREVIOUS $out_prev
test_set_chaos_rat_arch_fixture fetch/chaos-rat-arch-advisory.html
test_set_chaos_rat_community_fixture fetch/chaos-rat-community.txt
set -g AUR_OPT_quiet true
set -l merged (aur_load_chaos_rat_list false | string collect)
assert_status "merged fetch succeeds" 0
assert_contains "official librewolf from arch ml" librewolf-fix-bin "$merged"
assert_contains "community minecraft-cracked" minecraft-cracked "$merged"
assert_contains "community vesktop" vesktop-bin-patched "$merged"
set -l sha_findings (aur_finding_list list_source_sha256 | string collect)
assert_match "arch ml sha recorded" 'chaos-arch-ml=[a-f0-9]{64}' "$sha_findings"
assert_match "community sha recorded" 'chaos-community=[a-f0-9]{64}' "$sha_findings"
assert_match "merged sha recorded" 'chaos-merged=[a-f0-9]{64}' "$sha_findings"
test -f $out_list
assert_status "merged list written to cache file" 0
rm -f $out_list $out_prev
set -g AUR_REPORTS_DIR $_reports
if set -q _findings[1]
    set -gx AUR_FINDINGS_LIST_FILE $_findings
else
    set -e AUR_FINDINGS_LIST_FILE
end
test_clear_chaos_rat_fetch_fixtures
test_clear_chaos_rat_list

test_section "chaos rat list load (local)"

test_set_chaos_rat_list lists/chaos-rat-pkgs.txt
set -g AUR_OPT_quiet true
set -g AUR_OPT_chaos_rat true
begin
    aur_load_chaos_rat_list true >/dev/null 2>&1
    assert_status "local chaos list loads" 0
end
set -l pkgs (aur_load_chaos_rat_list true | string collect)
assert_contains "fixture chaos pkg" chaos-pkg-a "$pkgs"
assert_contains "fixture librewolf" librewolf-fix-bin "$pkgs"

test_section "chaos rat window install date helpers"

set -l info_file (mktemp)
echo 'librewolf-fix-bin|Mon 17 Jul 2025 18:46:00|Explicitly installed' >$info_file
set -gx AUR_TEST_PKG_INFO $info_file
begin
    aur_install_in_chaos_rat_window librewolf-fix-bin
    assert_status "Jul 17 2025 in chaos window" 0
end
echo 'librewolf-fix-bin|Mon 02 Feb 2026 12:53:53|Explicitly installed' >$info_file
begin
    aur_install_in_chaos_rat_window librewolf-fix-bin
    assert_status "Feb 2026 outside chaos window" 1
end
set -e AUR_TEST_PKG_INFO
rm -f $info_file

test_section "chaos rat scan HIGH/LOW by install window"

set -l log_dir (mktemp -d)
echo 'chaos-pkg-a|Mon 17 Jul 2025 20:00:00|Explicitly installed' >$log_dir/pkg-info.txt
echo 'librewolf-fix-bin|Mon 02 Feb 2026 12:53:53|Explicitly installed' >>$log_dir/pkg-info.txt
set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' clean-aur chaos-pkg-a librewolf-fix-bin >$AUR_TEST_INSTALLED_LIST
set -gx AUR_TEST_PKG_INFO $log_dir/pkg-info.txt

set -l scan_out (mktemp)
fish (aur_script_path check/chaos-rat-pkgs.fish) --chaos-rat --local >$scan_out 2>&1
assert_eq "chaos rat hits exit warn" $AUR_EXIT_WARN $status
set -l scan_text (cat $scan_out | string collect)
assert_match "in-window HIGH" '\[HIGH\].*chaos-pkg-a' "$scan_text"
assert_match "outside window LOW" '\[LOW\].*librewolf-fix-bin' "$scan_text"
assert_match "window label in LOW line" 'outside Jul 16–18, 2025' "$scan_text"
rm -f $scan_out $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_PKG_INFO
rm -rf $log_dir

test_section "chaos rat --all-time upgrades LOW to HIGH"

set -l log_dir (mktemp -d)
echo 'librewolf-fix-bin|Mon 02 Feb 2026 12:53:53|Explicitly installed' >$log_dir/pkg-info.txt
set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' librewolf-fix-bin >$AUR_TEST_INSTALLED_LIST
set -gx AUR_TEST_PKG_INFO $log_dir/pkg-info.txt

set -l alltime_out (mktemp)
fish (aur_script_path check/chaos-rat-pkgs.fish) --chaos-rat --local --all-time >$alltime_out 2>&1
set -l alltime_text (cat $alltime_out | string collect)
assert_match "all-time marks HIGH" '\[HIGH\].*librewolf-fix-bin' "$alltime_text"
assert_match "all-time flag in output" 'all-time' "$alltime_text"
rm -f $alltime_out $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_PKG_INFO
rm -rf $log_dir

test_section "chaos rat clean install set"

set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' clean-aur only-good >$AUR_TEST_INSTALLED_LIST
fish (aur_script_path check/chaos-rat-pkgs.fish) --chaos-rat --local >/dev/null 2>&1
assert_eq "no chaos hits exits clean" $AUR_EXIT_CLEAN $status
rm -f $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST

test_section "chaos rat timeline window vs all-time"

set -l log_dir (mktemp -d)
echo '[2025-07-17T18:46:00+0000] [ALPM] installed librewolf-fix-bin (1-1)' >$log_dir/pacman.log
echo '[2026-02-01T08:00:00-0600] [ALPM] installed chaos-pkg-a (1-1)' >>$log_dir/pacman.log
set -gx AUR_TEST_PACMAN_LOG_DIR $log_dir
test_set_chaos_rat_list lists/chaos-rat-pkgs.txt

set -l window_out (mktemp)
fish (aur_script_path scan/chaos-rat-timeline.fish) --chaos-rat --local >$window_out 2>&1
set -l window_code $status
set -l window_text (cat $window_out | string collect)

set -l alltime_out (mktemp)
fish (aur_script_path scan/chaos-rat-timeline.fish) --chaos-rat --local --all-time >$alltime_out 2>&1
set -l alltime_code $status
set -l alltime_text (cat $alltime_out | string collect)

assert_eq "window mode finds Jul install only" $AUR_EXIT_WARN $window_code
assert_match "librewolf in window timeline" 'librewolf-fix-bin' "$window_text"
assert_not_match "Feb chaos pkg excluded from window timeline" 'chaos-pkg-a' "$window_text"
assert_eq "all-time timeline finds both" $AUR_EXIT_WARN $alltime_code
assert_match "all-time librewolf hit" 'librewolf-fix-bin' "$alltime_text"
assert_match "all-time chaos-pkg-a hit" 'chaos-pkg-a' "$alltime_text"

rm -f $window_out $alltime_out
set -e AUR_TEST_PACMAN_LOG_DIR
rm -rf $log_dir

test_section "fail-on chaos-rat mode"

set -g AUR_OPT_fail_on chaos-rat
assert_eq "chaos rat triggers exit 2" $AUR_EXIT_WARN (aur_finalize_exit false false false true | tail -1)
assert_eq "generic warn suppressed" $AUR_EXIT_CLEAN (aur_finalize_exit false true false false | tail -1)
assert_eq "compromise still exits 1" $AUR_EXIT_COMPROMISE (aur_finalize_exit true false false true | tail -1)
set -g AUR_OPT_fail_on all

test_section "config enables chaos rat without cli flag"
set -l _enable $AUR_ENABLE_CHAOS_RAT
set -g AUR_ENABLE_CHAOS_RAT 1
set -g AUR_OPT_chaos_rat false
begin
    aur_chaos_rat_enabled
    assert_status "AUR_ENABLE_CHAOS_RAT=1 enables scan" 0
end
set -g AUR_ENABLE_CHAOS_RAT $_enable
set -g AUR_OPT_chaos_rat false

test_section "unknown chaos rat flags rejected"

set -l bad_out (mktemp)
fish (aur_script_path check/chaos-rat-pkgs.fish) --chaos-rat --not-a-flag >$bad_out 2>&1
assert_eq "unknown flag exits 4" $AUR_EXIT_INVALID $status
assert_match "unknown flag message" 'Unknown option: --not-a-flag' (cat $bad_out)
rm -f $bad_out

test_section "remove-packages --list chaos-rat dry-run"

set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' chaos-pkg-a >$AUR_TEST_INSTALLED_LIST
set -l remove_out (mktemp)
fish (aur_script_path recovery/remove-packages.fish) --list chaos-rat --dry-run >$remove_out 2>&1
assert_eq "chaos rat dry-run clean" $AUR_EXIT_CLEAN $status
assert_match "chaos pkg in removal list" 'chaos-pkg-a' (cat $remove_out | string collect)
rm -f $remove_out $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST

test_clear_chaos_rat_list
set -g AUR_OPT_chaos_rat false
set -g AUR_OPT_quiet false

test_finish "test-chaos-rat.fish"
exit $status
