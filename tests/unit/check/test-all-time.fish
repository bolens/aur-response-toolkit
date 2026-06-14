#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters

test_section "timeline --all-time includes pre-window infected pkg"
set -l log_dir (mktemp -d)
echo '[2026-02-01T08:00:00-0600] [ALPM] installed known-bad (1-1)' >$log_dir/pacman.log

set -gx AUR_TEST_PACMAN_LOG_DIR $log_dir
set -gx AUR_TEST_LIST_FILE (test_fixture_path lists/atomic-arch-pkgs.txt)

set -l out_window (mktemp)
fish (aur_script_path scan/atomic-arch-timeline.fish) --local >$out_window 2>&1
set -l code_window $status
set -l text_window (cat $out_window)

set -l out_all (mktemp)
fish (aur_script_path scan/atomic-arch-timeline.fish) --local --all-time >$out_all 2>&1
set -l code_all $status
set -l text_all (cat $out_all)

assert_eq "window mode clean for Feb install" $AUR_EXIT_CLEAN $code_window
assert_eq "all-time mode compromise for Feb install" $AUR_EXIT_COMPROMISE $code_all
assert_match "all-time output mentions known-bad" known-bad "$text_all"
assert_not_match "window mode omits known-bad" known-bad "$text_window"

rm -f $out_window $out_all
set -e AUR_TEST_PACMAN_LOG_DIR
set -e AUR_TEST_LIST_FILE
rm -rf $log_dir

test_section "check/atomic-arch-pkgs --all-time upgrades LOW to HIGH"
set -l log_dir (mktemp -d)
echo known-bad >$log_dir/installed.txt
echo 'known-bad|Mon 02 Feb 2026 12:53:53|Explicitly installed' >$log_dir/pkg-info.txt

set -gx AUR_TEST_INSTALLED_LIST $log_dir/installed.txt
set -gx AUR_TEST_PKG_INFO $log_dir/pkg-info.txt
set -gx AUR_TEST_LIST_FILE (test_fixture_path lists/atomic-arch-pkgs.txt)

set -l out_low (mktemp)
fish (aur_script_path check/atomic-arch-pkgs.fish) --local --no-chain >$out_low 2>&1
set -l text_low (cat $out_low)

set -l out_high (mktemp)
fish (aur_script_path check/atomic-arch-pkgs.fish) --local --all-time --no-chain >$out_high 2>&1
set -l text_high (cat $out_high)

assert_match "outside window marked LOW without --all-time" '\[LOW\].*known-bad' "$text_low"
assert_not_match "no HIGH without --all-time" '\[HIGH\].*known-bad' "$text_low"
assert_match "all-time marks HIGH" '\[HIGH\].*known-bad' "$text_high"
assert_match "all-time labels flag" all-time "$text_high"

rm -f $out_low $out_high
set -e AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_PKG_INFO
set -e AUR_TEST_LIST_FILE
rm -rf $log_dir

test_section aur_install_in_window_or_all_time
set -g AUR_OPT_all_time false
begin
    aur_install_in_window_or_all_time definitely-not-installed-pkg-xyz
    assert_status "all-time false uses real window for missing pkg" 1
end
set -g AUR_OPT_all_time true
begin
    aur_install_in_window_or_all_time definitely-not-installed-pkg-xyz
    assert_status "all-time true bypasses window check" 0
end
set -g AUR_OPT_all_time false

test_section "aur_install_in_compromise_window respects test pkg info"
set -l info_file (mktemp)
echo 'known-bad|Mon 02 Feb 2026 12:53:53|Explicitly installed' >$info_file
set -gx AUR_TEST_PKG_INFO $info_file
begin
    aur_install_in_compromise_window known-bad
    assert_status "mock Feb date outside window" 1
end
echo 'known-bad|Mon 09 Jun 2026 10:00:00|Explicitly installed' >$info_file
begin
    aur_install_in_compromise_window known-bad
    assert_status "mock Jun 9 inside window" 0
end
set -e AUR_TEST_PKG_INFO
rm -f $info_file

test_finish "test-all-time.fish"
exit $status
