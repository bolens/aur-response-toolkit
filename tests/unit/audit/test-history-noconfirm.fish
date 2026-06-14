#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "noconfirm AUR helper detection"

assert_eq "paru flag after helper" true (aur_history_line_has_noconfirm_aur "paru -S foo --noconfirm"; and echo true; or echo false)
assert_eq "yay flag before helper" true (aur_history_line_has_noconfirm_aur "yay --noconfirm -S foo"; and echo true; or echo false)
assert_eq "paru spaced noconfirm" true (aur_history_line_has_noconfirm_aur "paru -S --noconfirm foo"; and echo true; or echo false)
assert_eq "pamac no-confirm" true (aur_history_line_has_noconfirm_aur "pamac build foo --no-confirm"; and echo true; or echo false)
assert_eq "pamac batch" true (aur_history_line_has_noconfirm_aur "pamac install --batch evil-pkg"; and echo true; or echo false)
assert_eq "trizen noedit" true (aur_history_line_has_noconfirm_aur "trizen -S foo --noedit"; and echo true; or echo false)
assert_eq "makepkg noconfirm" true (aur_history_line_has_noconfirm_aur "makepkg -si --noconfirm"; and echo true; or echo false)
assert_eq "plain pacman ignored" false (aur_history_line_has_noconfirm_aur "sudo pacman -S foo --noconfirm"; and echo true; or echo false)
assert_eq "reviewed paru passes" false (aur_history_line_has_noconfirm_aur "paru -S foo"; and echo true; or echo false)

begin
    aur_history_has_noconfirm_aur (test_fixture_path history/history-noconfirm.txt)
    assert_status "fixture history has noconfirm" 0
end
begin
    aur_history_has_noconfirm_aur (test_fixture_path history/history-clean-aur.txt)
    assert_status "clean history has no noconfirm" 1
end
begin
    aur_history_has_noconfirm_aur /nonexistent/history
    assert_status "missing history file" 1
end

test_section "noconfirm only flags during foreign window activity"

set -l _log_dir $AUR_TEST_PACMAN_LOG_DIR
set -l _foreign $AUR_TEST_FOREIGN_LIST
set -gx AUR_TEST_PACMAN_LOG_DIR (dirname (test_fixture_path logs/pacman.log))
set -gx AUR_TEST_FOREIGN_LIST (test_fixture_path lists/foreign-pkgs.txt)

begin
    aur_history_noconfirm_during_window (test_fixture_path history/history-noconfirm.txt)
    assert_status "noconfirm with window foreign activity" 0
end

set -gx AUR_TEST_PACMAN_LOG_DIR (mktemp -d)
echo '[2026-06-01T08:00:00-0600] [ALPM] upgraded foo (1-1 -> 2-1)' >$AUR_TEST_PACMAN_LOG_DIR/pacman.log
begin
    aur_history_noconfirm_during_window (test_fixture_path history/history-noconfirm.txt)
    assert_status "noconfirm without foreign window activity" 1
end
rm -rf $AUR_TEST_PACMAN_LOG_DIR

if set -q _log_dir
    set -gx AUR_TEST_PACMAN_LOG_DIR $_log_dir
else
    set -e AUR_TEST_PACMAN_LOG_DIR
end
if set -q _foreign
    set -gx AUR_TEST_FOREIGN_LIST $_foreign
else
    set -e AUR_TEST_FOREIGN_LIST
end

test_finish "test-history-noconfirm.fish"
exit $status
