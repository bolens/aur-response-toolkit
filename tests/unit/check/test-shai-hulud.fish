#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "shai hulud disabled by default"

set -l out (mktemp)
fish (aur_script_path check/shai-hulud-pkgs.fish) >$out 2>&1
assert_eq "disabled scan exits clean" $AUR_EXIT_CLEAN $status
assert_match "skipped message" 'Shai-Hulud scan skipped' (cat $out)
rm -f $out

test_section "shai hulud list load (local)"

test_set_shai_hulud_list lists/shai-hulud-pkgs.txt
set -g AUR_OPT_quiet true
set -g AUR_OPT_shai_hulud true
begin
    aur_load_shai_hulud_list true >/dev/null 2>&1
    assert_status "local shai list loads" 0
end
set -l pkgs (aur_load_shai_hulud_list true | string collect)
assert_contains "fixture shai pkg" shai-pkg-a "$pkgs"
assert_contains "fixture gnome-vfs" gnome-vfs "$pkgs"

test_section "shai hulud window install date helpers"

set -l info_file (mktemp)
echo 'gnome-vfs|Sat 17 May 2026 10:00:00|Explicitly installed' >$info_file
set -gx AUR_TEST_PKG_INFO $info_file
begin
    aur_install_in_shai_hulud_window gnome-vfs
    assert_status "May 17 2026 in shai window" 0
end
echo 'gnome-vfs|Mon 02 Feb 2026 12:53:53|Explicitly installed' >$info_file
begin
    aur_install_in_shai_hulud_window gnome-vfs
    assert_status "Feb 2026 outside shai window" 1
end
set -e AUR_TEST_PKG_INFO
rm -f $info_file

test_section "shai hulud scan HIGH/LOW by install window"

set -l log_dir (mktemp -d)
echo 'shai-pkg-a|Sat 17 May 2026 20:00:00|Explicitly installed' >$log_dir/pkg-info.txt
echo 'expressvpn|Mon 02 Feb 2026 12:53:53|Explicitly installed' >>$log_dir/pkg-info.txt
set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' clean-aur shai-pkg-a expressvpn >$AUR_TEST_INSTALLED_LIST
set -gx AUR_TEST_PKG_INFO $log_dir/pkg-info.txt

set -l scan_out (mktemp)
fish (aur_script_path check/shai-hulud-pkgs.fish) --shai-hulud --local >$scan_out 2>&1
assert_eq "shai hulud hits exit warn" $AUR_EXIT_WARN $status
set -l scan_text (cat $scan_out | string collect)
assert_match "in-window HIGH" '\[HIGH\].*shai-pkg-a' "$scan_text"
assert_match "outside window LOW" '\[LOW\].*expressvpn' "$scan_text"
assert_match "window label in LOW line" 'outside May 16–17, 2026' "$scan_text"
rm -f $scan_out $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_PKG_INFO
rm -rf $log_dir

test_section "shai hulud timeline window vs all-time"

set -l log_dir (mktemp -d)
echo '[2026-05-17T10:00:00+0000] [ALPM] installed gnome-vfs (1-1)' >$log_dir/pacman.log
echo '[2026-02-01T08:00:00-0600] [ALPM] installed shai-pkg-a (1-1)' >>$log_dir/pacman.log
set -gx AUR_TEST_PACMAN_LOG_DIR $log_dir
test_set_shai_hulud_list lists/shai-hulud-pkgs.txt

set -l window_out (mktemp)
fish (aur_script_path scan/shai-hulud-timeline.fish) --shai-hulud --local >$window_out 2>&1
set -l window_code $status
set -l window_text (cat $window_out | string collect)

set -l alltime_out (mktemp)
fish (aur_script_path scan/shai-hulud-timeline.fish) --shai-hulud --local --all-time >$alltime_out 2>&1
set -l alltime_code $status
set -l alltime_text (cat $alltime_out | string collect)

assert_eq "window mode finds May install only" $AUR_EXIT_WARN $window_code
assert_match "gnome-vfs in window timeline" gnome-vfs "$window_text"
assert_not_match "Feb shai pkg excluded from window timeline" shai-pkg-a "$window_text"
assert_eq "all-time timeline finds both" $AUR_EXIT_WARN $alltime_code
assert_match "all-time gnome-vfs hit" gnome-vfs "$alltime_text"
assert_match "all-time shai-pkg-a hit" shai-pkg-a "$alltime_text"

rm -f $window_out $alltime_out
set -e AUR_TEST_PACMAN_LOG_DIR
rm -rf $log_dir

test_section "fail-on shai-hulud mode"

set -g AUR_OPT_fail_on shai-hulud
assert_eq "shai hulud triggers exit 2" $AUR_EXIT_WARN (aur_finalize_exit false false false false true | tail -1)
assert_eq "generic warn suppressed" $AUR_EXIT_CLEAN (aur_finalize_exit false true false false false | tail -1)
set -g AUR_OPT_fail_on all

test_section "remove-packages --list shai-hulud dry-run"

set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' shai-pkg-a >$AUR_TEST_INSTALLED_LIST
set -l remove_out (mktemp)
fish (aur_script_path recovery/remove-packages.fish) --list shai-hulud --dry-run >$remove_out 2>&1
assert_eq "shai hulud dry-run clean" $AUR_EXIT_CLEAN $status
assert_match "shai pkg in removal list" shai-pkg-a (cat $remove_out | string collect)
rm -f $remove_out $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST

test_section "gh-token-monitor persistence detection"

set -l fake_home (mktemp -d)
set -l saved_home $HOME
set -gx HOME $fake_home
mkdir -p $fake_home/.config/systemd/user
echo '[Service]' >$fake_home/.config/systemd/user/gh-token-monitor.service
set -l hits (aur_check_shai_hulud_persistence | string collect)
assert_match "service file detected" 'gh-token-monitor.service' "$hits"
set -gx HOME $saved_home
rm -rf $fake_home

test_section "config enables shai hulud without cli flag"

set -l _enable $AUR_ENABLE_SHAI_HULUD
set -g AUR_ENABLE_SHAI_HULUD 1
set -g AUR_OPT_shai_hulud false
begin
    aur_shai_hulud_enabled
    assert_status "AUR_ENABLE_SHAI_HULUD=1 enables scan" 0
end
set -g AUR_ENABLE_SHAI_HULUD $_enable
set -g AUR_OPT_shai_hulud false

test_section "shai hulud remote fetch saves list and sha256"

set -l _reports $AUR_REPORTS_DIR
set -l _findings $AUR_FINDINGS_LIST_FILE
set -g AUR_REPORTS_DIR (mktemp -d)
set -gx AUR_FINDINGS_LIST_FILE "$AUR_REPORTS_DIR/.scan-findings.list"
aur_state_init
set -l fetch_fixture (mktemp)
printf '%s\n' crypto-pkg-extra gnome-vfs >$fetch_fixture
set -l out_list (mktemp)
set -gx AUR_TEST_SHAI_HULUD_LIST_FILE $out_list
set -g AUR_SHAI_HULUD_URL https://example.invalid/shai-hulud-pkgs.txt
test_set_shai_hulud_fetch_fixture $fetch_fixture
set -g AUR_OPT_quiet true
set -l fetched (aur_load_shai_hulud_list false | string collect)
assert_status "remote fetch succeeds via test fixture" 0
assert_match "fetched extra package" crypto-pkg-extra "$fetched"
assert_match "fetched gnome-vfs" gnome-vfs "$fetched"
test -f $out_list
assert_status "fetched list written to cache" 0
set -l sha_findings (aur_finding_list shai_hulud_list_sha256 | string collect)
assert_match "fetch sha256 recorded" 'shai-hulud=[a-f0-9]{64}' "$sha_findings"
rm -f $fetch_fixture $out_list
test_clear_shai_hulud_fetch
set -g AUR_SHAI_HULUD_URL ""
set -g AUR_REPORTS_DIR $_reports
if set -q _findings[1]
    set -gx AUR_FINDINGS_LIST_FILE $_findings
else
    set -e AUR_FINDINGS_LIST_FILE
end

test_section "shai hulud fetch failure falls back to bundled list"

set -l out_list (mktemp)
set -gx AUR_TEST_SHAI_HULUD_LIST_FILE $out_list
cp (test_fixture_path lists/shai-hulud-pkgs.txt) $out_list
set -g AUR_SHAI_HULUD_URL https://example.invalid/shai-hulud-pkgs.txt
test_set_shai_hulud_fetch_fail
set -g AUR_OPT_quiet true
set -l fallback (aur_load_shai_hulud_list false | string collect)
assert_status "fetch failure uses bundled list" 0
assert_contains "fallback includes gnome-vfs" gnome-vfs "$fallback"
rm -f $out_list
test_clear_shai_hulud_fetch
set -g AUR_SHAI_HULUD_URL ""

test_section "shai hulud --all-time upgrades LOW to HIGH"

set -l log_dir (mktemp -d)
echo 'expressvpn|Mon 02 Feb 2026 12:53:53|Explicitly installed' >$log_dir/pkg-info.txt
set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' expressvpn >$AUR_TEST_INSTALLED_LIST
set -gx AUR_TEST_PKG_INFO $log_dir/pkg-info.txt
test_set_shai_hulud_list lists/shai-hulud-pkgs.txt

set -l window_out (mktemp)
fish (aur_script_path check/shai-hulud-pkgs.fish) --shai-hulud --local >$window_out 2>&1
set -l window_text (cat $window_out | string collect)
assert_match "outside window is LOW" '\[LOW\].*expressvpn' "$window_text"

set -l alltime_out (mktemp)
fish (aur_script_path check/shai-hulud-pkgs.fish) --shai-hulud --local --all-time >$alltime_out 2>&1
set -l alltime_text (cat $alltime_out | string collect)
assert_match "all-time upgrades to HIGH" '\[HIGH\].*expressvpn' "$alltime_text"

rm -f $window_out $alltime_out $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_PKG_INFO
rm -rf $log_dir

test_section "shai hulud clean install set"

set -gx AUR_TEST_INSTALLED_LIST (mktemp)
printf '%s\n' clean-aur-only >$AUR_TEST_INSTALLED_LIST
test_set_shai_hulud_list lists/shai-hulud-pkgs.txt
fish (aur_script_path check/shai-hulud-pkgs.fish) --shai-hulud --local >/dev/null 2>&1
assert_eq "no shai hits exits clean" $AUR_EXIT_CLEAN $status
rm -f $AUR_TEST_INSTALLED_LIST
set -e AUR_TEST_INSTALLED_LIST

test_section "unknown shai hulud flags rejected"

set -l bad_out (mktemp)
fish (aur_script_path check/shai-hulud-pkgs.fish) --shai-hulud --not-a-flag >$bad_out 2>&1
assert_eq "unknown flag exits invalid" $AUR_EXIT_INVALID $status
rm -f $bad_out

test_clear_shai_hulud_list
set -g AUR_OPT_shai_hulud false
set -g AUR_OPT_quiet false

test_finish "test-shai-hulud.fish"
exit $status
