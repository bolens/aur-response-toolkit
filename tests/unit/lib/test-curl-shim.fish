#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "aur_curl fetches via file:// URL"

set -l fixture (test_fixture_path fetch/chaos-rat-community.txt)
set -l out (mktemp)
begin
    aur_curl -fsSL --max-time 5 "file://$fixture" -o $out
    assert_status "file url fetch succeeds" 0
end
set -l body (cat $out | string collect)
assert_match "community fixture content" 'minecraft-cracked' "$body"
rm -f $out

test_section "aur_fetch_source_with_sha uses aur_curl"

set -l fetch (aur_fetch_source_with_sha "file://$fixture")
assert_status "fetch source with sha succeeds" 0
set -l parts (string split '|' -- $fetch)
set -l tmp $parts[1]
test -f $tmp
assert_status "fetch temp file exists" 0
rm -f $tmp

if command -q curlie
    test_section "aur_curl curlie uses empty stdin (non-TTY workaround)"
    set -l curlie_out (mktemp)
    begin
        aur_curl -fsSL --max-time 10 -o $curlie_out https://example.com
        assert_status "curlie -o fetch completes without stdin hang" 0
    end
    assert_match "curlie fetch body" 'Example Domain' (cat $curlie_out | string collect)
    rm -f $curlie_out
end

test_finish "test-curl-shim.fish"
exit $status
