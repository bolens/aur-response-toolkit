#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "timeline matching (no substring false positives)"

set -gx AUR_TEST_PACMAN_LOG_DIR (dirname (test_fixture_path logs/pacman.log))
set -l events (mktemp)
aur_collect_window_alpm_events_all $events

set -l raw (aur_timeline_hits_from_events $events (test_fixture_path lists/atomic-arch-pkgs.txt) | string collect)
assert_count "two beef hits" 2 "$raw"
assert_match "beef upgrade included" 'upgraded beef' "$raw"
assert_not_match "bee not infected" '(^|\n)installed bee' "$raw"
assert_not_match "clean-aur not infected" 'clean-aur' "$raw"
assert_not_match "removed action not counted" 'evil-pkg' "$raw"

test_section "repeat updates during attack window"
set -l repeat_raw (aur_timeline_repeat_updates_from_events $events (test_fixture_path lists/atomic-arch-pkgs.txt) | string collect)
assert_count "beef has repeat record" 1 "$repeat_raw"
assert_match "beef repeat count" '^beef\|2\|' "$repeat_raw"
assert_match "beef first upgrade in repeat" '1-1 -> 2-1' "$repeat_raw"
assert_match "beef second upgrade in repeat" '2-1 -> 3-1' "$repeat_raw"
assert_not_match "bee single install not repeat" '(^|\n)bee\|' "$repeat_raw"
assert_eq "beef event count" 2 (aur_pkg_event_count_in_events $events beef)
assert_eq "bee event count" 1 (aur_pkg_event_count_in_events $events bee)

test_section "event line extraction from pkg|line hits"
set -l hit 'beef|[2026-06-10T11:00:00-0600] [ALPM] upgraded beef (1-1 -> 2-1)'
assert_match "aur_event_line_from_hit" 'upgraded beef' (aur_event_line_from_hit "$hit")

test_section "aur_grep -F avoids bee/beef substring trap"
assert_count "aur_grep -F beef| does not match bee" 0 (echo 'bee|[2026-06-09T10:00:00-0600] [ALPM] installed bee (1-1)' | aur_grep -F 'beef|' | string split \n)
assert_count "aur_grep -F beef| matches beef" 1 (echo 'beef|[2026-06-10T11:00:00-0600] [ALPM] upgraded beef (1-1 -> 2-1)' | aur_grep -F 'beef|' | string split \n)

test_section "foreign package window matching"
set -l foreign_list (mktemp)
printf '%s\n' bee beef clean-aur archived-pkg >$foreign_list
set -l foreign_raw (aur_foreign_packages_in_window $events $foreign_list | string collect)
assert_contains "foreign beef" beef "$foreign_raw"
assert_contains "foreign bee" bee "$foreign_raw"
assert_contains "foreign from rotated log" archived-pkg "$foreign_raw"
assert_not_match "foo not foreign" '(^|\n)foo(\n|$)' "$foreign_raw"

rm -f $events $foreign_list
set -e AUR_TEST_PACMAN_LOG_DIR

test_finish "test-timeline-matching.fish"
exit $status
