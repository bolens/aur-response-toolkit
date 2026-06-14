#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "aur_grep quiet and line-regexp"

begin
    printf '%s\n' beef bee | aur_grep -q beef
    assert_status "grep -q finds match" 0
end
begin
    printf '%s\n' bee | aur_grep -q beef
    assert_status "grep -q misses non-match" 1
end
begin
    printf '%s\n' beef beef | aur_grep -Fxq beef
    assert_status "grep -Fxq exact line" 0
end
begin
    printf '%s\n' beefy | aur_grep -Fxq beef
    assert_status "grep -Fxq rejects substring" 1
end

test_section "aur_grep match limits"

set -l limited (printf '%s\n' beef beef bee | aur_grep -m1 beef | string collect)
assert_count "grep -m1 returns one line" 1 "$limited"
assert_eq "grep -m1 first hit" beef (string split \n -- "$limited" | head -1)

set -l capped (printf '%s\n' a b c | aur_grep -m2 . | string collect)
assert_count "grep -m2 caps output" 2 "$capped"

test_section "aur_grep extended regexp passthrough"

set -l regex_hits (printf '%s\n' 'pkg-1.0' 'pkg-2.0' 'other' | aur_grep -E '^pkg-[0-9]' | string collect)
assert_count "grep -E matches numbered pkgs" 2 "$regex_hits"
assert_contains "regex first pkg" pkg-1.0 "$regex_hits"

test_finish "test-grep-shim.fish"
exit $status
