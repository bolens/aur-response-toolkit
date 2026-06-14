#!/usr/bin/env fish

# Test runner: each suite is a separate fish process; any failure yields exit 1.

set -l test_dir (dirname (status filename))
set -g AUR_RESPONSE_DIR (dirname $test_dir)
source $AUR_RESPONSE_DIR/lib/common.fish

set -l failed_suites 0
set -l passed_suites 0

function _aur_discover_test_suites --argument-names root
    aur_find $root/unit $root/integration -name 'test-*.fish' -type f 2>/dev/null | sort
end

echo "AUR response toolkit — test suite"
echo "================================="

for suite in (_aur_discover_test_suites $test_dir)
    fish $suite
    if test $status -eq 0
        set passed_suites (math $passed_suites + 1)
    else
        set failed_suites (math $failed_suites + 1)
    end
end

echo ""
echo "================================="
if test $failed_suites -eq 0
    echo "All $passed_suites suite(s) passed."
    exit 0
end
echo "$failed_suites suite(s) failed, $passed_suites passed."
exit 1
