#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters

function test_make_log_fixture --argument-names path line
    echo $line >$path
end

function test_compress_log --argument-names fmt plain compressed
    switch $fmt
        case gz
            gzip -cf -- $plain >$compressed
        case xz
            xz -cf -- $plain >$compressed
        case bz2
            bzip2 -cf -- $plain >$compressed
        case zst
            if command -q zstd
                zstd -q -f -o $compressed $plain
            else
                return 1
            end
    end
end

test_section "aur_read_pacman_log plain and compressed"
set -l plain (mktemp)
set -l line '[2026-06-10T12:00:00-0600] [ALPM] installed plain-pkg (1-1)'
test_make_log_fixture $plain $line
set -l plain_out (aur_read_pacman_log $plain | string collect)
assert_contains "plain log readable" $line $plain_out

set -l gz (mktemp).gz
test_compress_log gz $plain $gz
set -l gz_out (aur_read_pacman_log $gz | string collect)
assert_contains "gzip log decompressed" $line $gz_out

set -l xz (mktemp).xz
test_compress_log xz $plain $xz
set -l xz_out (aur_read_pacman_log $xz | string collect)
assert_contains "xz log decompressed" $line $xz_out

set -l bz2 (mktemp).bz2
test_compress_log bz2 $plain $bz2
set -l bz2_out (aur_read_pacman_log $bz2 | string collect)
assert_contains "bzip2 log decompressed" $line $bz2_out

if command -q zstd
    set -l zst_path (mktemp).zst
    test_compress_log zst $plain $zst_path
    set -l zst_out (aur_read_pacman_log $zst_path | string collect)
    assert_contains "zst log decompressed" $line $zst_out
    rm -f $zst_path
else
    echo "  ok  zst skipped (zstd not installed)"
    set -g TEST_PASSED (math $TEST_PASSED + 1)
end

rm -f $plain $gz $xz $bz2

test_section "window scan reads compressed-only rotated log"
set -l log_dir (mktemp -d)
set -l inner (mktemp)
set -l xz_line '[2026-06-13T10:00:00-0600] [ALPM] installed xz-only-pkg (1-1)'
test_make_log_fixture $inner $xz_line
test_compress_log xz $inner $log_dir/pacman.log.4.xz
rm -f $inner

set -l events (mktemp)
set -gx AUR_TEST_PACMAN_LOG_DIR $log_dir
aur_collect_window_alpm_events_all $events
assert_match "xz-only pkg in window events" '^xz-only-pkg\|' (aur_grep -F 'xz-only-pkg|' $events | head -1)

set -l outside_inner (mktemp)
echo '[2026-06-01T08:00:00-0600] [ALPM] installed old-pkg (1-1)' >$outside_inner
test_compress_log xz $outside_inner $log_dir/pacman.log.5.xz
rm -f $outside_inner
set -l events2 (mktemp)
aur_collect_window_alpm_events_all $events2
assert_count "old-pkg outside window excluded from xz log" 0 (aur_grep -F 'old-pkg|' $events2)

rm -f $events $events2
set -e AUR_TEST_PACMAN_LOG_DIR
rm -rf $log_dir

test_finish "test-compressed-logs.fish"
exit $status
