#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "aur_pgrep_af finds current fish process"

set -l hits (aur_pgrep_af fish | string collect)
assert_match "aur_pgrep_af matches fish" fish "$hits"

test_section "aur_ss_tun_lines returns connection data when available"

if command -q ss; or command -q netstat; or command -q lsof
    aur_ss_tun_lines >/dev/null
    # Check function status directly — pipeline status can reflect ss probe errors in Fish 4.7+ containers.
    assert_status "aur_ss_tun_lines exits cleanly" 0
end

test_finish "test-ioc-shims.fish"
exit $status
