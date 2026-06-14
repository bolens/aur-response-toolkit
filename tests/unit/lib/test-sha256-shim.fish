#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "aur_sha256 hashes file content"

set -l fixture (test_fixture_path fetch/chaos-rat-community.txt)
set -l hash (aur_sha256 $fixture)
assert_status "aur_sha256 succeeds" 0
test -n "$hash"
assert_status "aur_sha256 returns non-empty digest" 0
assert_match "aur_sha256 lowercase hex" '^[a-f0-9]{64}$' "$hash"

test_section "aur_sha256_file returns uppercase digest"

set -l upper (aur_sha256_file $fixture)
assert_eq "aur_sha256_file uppercases" (string upper $hash) "$upper"

test_section "aur_sha256 matches sha256sum when available"

if command -q sha256sum
    set -l direct (command sha256sum $fixture | string split ' ' | head -1)
    assert_eq "aur_sha256 agrees with sha256sum" $direct $hash
end

test_finish "test-sha256-shim.fish"
exit $status
