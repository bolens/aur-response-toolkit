#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "aur_realpath resolves relative paths"

set -l fixture (test_fixture_path fetch/chaos-rat-community.txt)
set -l expected (aur_realpath $fixture)
set -l dir (dirname $fixture)
set -l base (basename $fixture)
begin
    cd $dir
    set -l resolved (aur_realpath $base)
    assert_status "aur_realpath succeeds" 0
    assert_eq "aur_realpath absolute path" $expected $resolved
end

test_finish "test-realpath-shim.fish"
exit $status
