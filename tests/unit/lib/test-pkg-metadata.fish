#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "pkg info mock fields"

set -l info_file (mktemp)
echo 'evil-pkg|Mon 09 Jun 2026 10:00:00|Explicitly installed' >$info_file
set -gx AUR_TEST_PKG_INFO $info_file
assert_eq "mock install date" "Mon 09 Jun 2026 10:00:00" (aur_pkg_install_date evil-pkg)
assert_eq "mock install reason" "Explicitly installed" (aur_pkg_install_reason evil-pkg)
set -e AUR_TEST_PKG_INFO
rm -f $info_file

test_section "package name filter rejects invalid tokens"

set -l filtered (printf '%s\n' beef 'NOT-VALID' 'a' 'valid_pkg' 'bad pkg' | aur_filter_pkg_lines | string collect)
assert_contains "valid lowercase kept" beef "$filtered"
assert_contains "underscore name kept" valid_pkg "$filtered"
assert_not_match "uppercase rejected" 'NOT-VALID' "$filtered"
assert_not_match "single char rejected" '(^|\n)a(\n|$)' "$filtered"
assert_not_match "internal space rejected" 'bad pkg' "$filtered"

test_section "pacman log accessibility hook"

set -l _log_dir $AUR_TEST_PACMAN_LOG_DIR
set -gx AUR_TEST_PACMAN_LOG_DIR (dirname (test_fixture_path logs/pacman.log))
begin
    aur_pacman_logs_accessible
    assert_status "fixture logs readable" 0
end
set -gx AUR_TEST_PACMAN_LOG_DIR (mktemp -d)
begin
    aur_pacman_logs_accessible
    assert_status "empty log dir not accessible" 1
end
rm -rf $AUR_TEST_PACMAN_LOG_DIR
if set -q _log_dir
    set -gx AUR_TEST_PACMAN_LOG_DIR $_log_dir
else
    set -e AUR_TEST_PACMAN_LOG_DIR
end

test_section "foreign activity in compromise window"

set -l _log_dir $AUR_TEST_PACMAN_LOG_DIR
set -l _foreign $AUR_TEST_FOREIGN_LIST
set -gx AUR_TEST_PACMAN_LOG_DIR (dirname (test_fixture_path logs/pacman.log))
set -gx AUR_TEST_FOREIGN_LIST (test_fixture_path lists/foreign-pkgs.txt)
begin
    aur_foreign_activity_in_window
    assert_status "fixture foreign activity detected" 0
end
set -gx AUR_TEST_PACMAN_LOG_DIR (mktemp -d)
echo '[2026-06-01T08:00:00-0600] [ALPM] upgraded foo (1-1 -> 2-1)' >$AUR_TEST_PACMAN_LOG_DIR/pacman.log
begin
    aur_foreign_activity_in_window
    assert_status "no foreign pkgs in empty window" 1
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

test_finish "test-pkg-metadata.fish"
exit $status
