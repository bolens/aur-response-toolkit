#!/usr/bin/env fish

# Test runner: each suite is a separate fish process; any failure yields exit 1.

set -l test_dir (dirname (status filename))
set -l failed_suites 0
set -l passed_suites 0

echo "AUR response toolkit — test suite"
echo "================================="

for suite in \
    unit/test-pacman-log.fish \
    unit/test-timeline-matching.fish \
    unit/test-multiline-handling.fish \
    unit/test-package-lists.fish \
    unit/test-hooks-secrets.fish \
    unit/test-state-json.fish \
    unit/test-exit-findings.fish \
    unit/test-findings-tab.fish \
    unit/test-compromise-detected.fish \
    unit/test-prune.fish \
    unit/test-apply-hardening.fish \
    unit/test-rotate-hints.fish \
    integration/test-cli.fish \
    integration/test-scrub-history.fish \
    integration/test-integration.fish

    fish $test_dir/$suite
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
