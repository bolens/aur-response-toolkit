#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "ALPM collect cache reuse"

set -gx AUR_TEST_PACMAN_LOG_DIR (dirname (test_fixture_path logs/pacman.log))
set -gx AUR_ALPM_CACHE_DIR (mktemp -d)
set -g AUR_OPT_all_time false

set -l first (mktemp)
set -l second (mktemp)
aur_collect_window_alpm_events_all $first
set -l n1 (wc -l <$first | string trim)
aur_collect_window_alpm_events_all $second
set -l n2 (wc -l <$second | string trim)
assert_eq "cached collect same line count" $n1 $n2
assert_eq "cache file populated" 1 (test -f $AUR_ALPM_CACHE_DIR/aur_log_line_in_compromise_window.window.events; and echo 1; or echo 0)
assert_eq "cached collect identical bytes" (aur_sha256 $first) (aur_sha256 $second)

test_section "ALPM warmup fills shared cache keys"
rm -rf $AUR_ALPM_CACHE_DIR
set -gx AUR_ALPM_CACHE_DIR (mktemp -d)
aur_warmup_alpm_event_caches
assert_eq "warmup window cache" 1 (test -f $AUR_ALPM_CACHE_DIR/aur_log_line_in_compromise_window.window.events; and echo 1; or echo 0)

rm -f $first $second
rm -rf $AUR_ALPM_CACHE_DIR
set -e AUR_ALPM_CACHE_DIR
set -e AUR_TEST_PACMAN_LOG_DIR

test_finish "test-alpm-cache.fish"
exit $status
