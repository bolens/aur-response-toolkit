#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "pacman log parsing"

set -l fixture (test_fixture_path logs/pacman.log)
set -l line_beef '[2026-06-10T11:00:00-0600] [ALPM] upgraded beef (1-1 -> 2-1)'
set -l line_bee '[2026-06-09T10:00:00-0600] [ALPM] installed bee (1-1)'
set -l line_removed '[2026-06-11T12:00:00-0600] [ALPM] removed evil-pkg (1-1)'
set -l line_outside '[2026-06-01T08:00:00-0600] [ALPM] upgraded foo (1-1 -> 2-1)'
set -l line_late '[2026-06-15T09:00:00-0600] [ALPM] installed late-pkg (1-1)'

assert_eq "extract beef" beef (aur_extract_alpm_pkg_from_line $line_beef)
assert_eq "extract bee" bee (aur_extract_alpm_pkg_from_line $line_bee)

begin
    aur_log_line_in_compromise_window $line_beef
    assert_status "beef line in window" 0
end
begin
    aur_log_line_in_compromise_window $line_outside
    assert_status "foo line outside window" 1
end
begin
    aur_log_line_in_compromise_window $line_late
    assert_status "Jun 15 outside window" 1
end

begin
    aur_is_alpm_install_line $line_removed
    assert_status "removed is not install line" 1
end
begin
    aur_is_alpm_install_line $line_beef
    assert_status "upgraded is install line" 0
end

set -l events (mktemp)
aur_collect_window_alpm_events $fixture $events
assert_match "bee in window events" '^bee\|' (aur_grep -F 'bee|' $events | head -1)
assert_match "beef in window events" '^beef\|' (aur_grep -F 'beef|' $events | head -1)
assert_count "removed pkg excluded" 0 (aur_grep -F 'evil-pkg|' $events)
assert_count "outside window excluded" 0 (aur_grep -F 'foo|' $events)
assert_count "late pkg excluded" 0 (aur_grep -F 'late-pkg|' $events)

set -l events_all (mktemp)
set -gx AUR_TEST_PACMAN_LOG_DIR (dirname (test_fixture_path logs/pacman.log))
aur_collect_window_alpm_events_all $events_all
assert_match "rotated log included" '^archived-pkg\|' (aur_grep -F 'archived-pkg|' $events_all | head -1)
assert_match "gzip rotated log included" '^gz-pkg\|' (aur_grep -F 'gz-pkg|' $events_all | head -1)
assert_count "edge-before excluded (Jun 8)" 0 (aur_grep -F 'edge-before|' $events_all)

rm -f $events $events_all
set -e AUR_TEST_PACMAN_LOG_DIR

test_section "install date matching"
begin
    aur_install_date_in_window "Install Date    : Mon 09 Jun 2026 10:00:00"
    assert_status "zero-padded Jun 9" 0
end
begin
    aur_install_date_in_window "Install Date    : Mon  9 Jun 2026 10:00:00"
    assert_status "single-digit Jun 9" 0
end
begin
    aur_install_date_in_window "Install Date    : Sat 14 Jun 2026 08:35:36 AM MDT"
    assert_status "Jun 14 in window" 0
end
begin
    aur_install_date_in_window "Install Date    : Mon 02 Feb 2026 12:53:53"
    assert_status "Feb outside window" 1
end
begin
    aur_install_date_in_window "Install Date    : Mon 09 Jun 2025 10:00:00"
    assert_status "wrong year" 1
end

test_section "--all-time bypasses log window"
set -l events_alltime (mktemp)
set -g AUR_OPT_all_time true
aur_collect_window_alpm_events (test_fixture_path logs/pacman.log) $events_alltime
assert_match "all-time includes Jun 1 foo" '^foo\|' (aur_grep -F 'foo|' $events_alltime | head -1)
set -g AUR_OPT_all_time false
rm -f $events_alltime

test_finish "test-pacman-log.fish"
exit $status
