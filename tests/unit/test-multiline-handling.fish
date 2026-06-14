#!/usr/bin/env fish

# Regression tests for Fish multiline/bracket glob pitfalls (pacman log lines start with '[').

source (dirname (dirname (status filename)))/lib/test-utils.fish

test_reset_counters
test_section "aur_safe_count preserves bracket-prefixed lines"

set -l two_lines "[2026-06-09T10:00:00-0600] [ALPM] installed bee (1-1)
[2026-06-10T11:00:00-0600] [ALPM] upgraded beef (1-1 -> 2-1)"

assert_count "quoted multiline count" 2 "$two_lines"

set -l tmp (mktemp)
printf '%s\n' "[2026-06-09] line-one" "[2026-06-14] line-two" >$tmp
assert_eq "cat with string collect" 2 (aur_safe_count (cat $tmp | string collect))
assert_eq "cat without collect undercounts" 1 (aur_safe_count (cat $tmp))
rm -f $tmp

test_section "string split on pacman-style raw output"

set -l raw (printf '%s\n' \
    "[2026-06-09T10:00:00-0600] [ALPM] installed bee (1-1)" \
    "[2026-06-10T11:00:00-0600] [ALPM] upgraded beef (1-1 -> 2-1)" | string collect)
assert_eq "split quoted raw" 2 (count (string split \n -- "$raw"))

test_section "subprocess exit code capture"

set -l out_file (mktemp)
fish -c 'exit 1' >$out_file 2>&1
assert_eq "exit code via temp file capture" 1 $status
rm -f $out_file

test_finish "test-multiline-handling.fish"
exit $status
