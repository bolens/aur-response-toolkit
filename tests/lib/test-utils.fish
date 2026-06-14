# Shared test helpers — sources common.fish and sets AUR_RESPONSE_DIR

if not set -q AUR_RESPONSE_DIR
    set -g AUR_RESPONSE_DIR (dirname (dirname (dirname (status filename))))
end
source $AUR_RESPONSE_DIR/lib/common.fish

set -g TEST_FAILED 0
set -g TEST_PASSED 0

function test_reset_counters
    set -g TEST_FAILED 0
    set -g TEST_PASSED 0
end

function assert_eq --argument-names label expected actual
    if test "$expected" = "$actual"
        echo "  ok  $label"
        set -g TEST_PASSED (math $TEST_PASSED + 1)
    else
        echo "  FAIL $label (expected '$expected', got '$actual')"
        set -g TEST_FAILED (math $TEST_FAILED + 1)
    end
end

function assert_ne --argument-names label unexpected actual
    if test "$unexpected" != "$actual"
        echo "  ok  $label"
        set -g TEST_PASSED (math $TEST_PASSED + 1)
    else
        echo "  FAIL $label (did not expect '$unexpected')"
        set -g TEST_FAILED (math $TEST_FAILED + 1)
    end
end

function assert_match --argument-names label pattern value
    if string match -qr $pattern -- "$value"
        echo "  ok  $label"
        set -g TEST_PASSED (math $TEST_PASSED + 1)
    else
        echo "  FAIL $label ('$value' did not match /$pattern/)"
        set -g TEST_FAILED (math $TEST_FAILED + 1)
    end
end

function assert_not_match --argument-names label pattern value
    if string match -qr $pattern -- "$value"
        echo "  FAIL $label ('$value' unexpectedly matched /$pattern/)"
        set -g TEST_FAILED (math $TEST_FAILED + 1)
    else
        echo "  ok  $label"
        set -g TEST_PASSED (math $TEST_PASSED + 1)
    end
end

function assert_status --argument-names label expected
    if test $status -eq $expected
        echo "  ok  $label"
        set -g TEST_PASSED (math $TEST_PASSED + 1)
    else
        echo "  FAIL $label (expected exit $expected, got $status)"
        set -g TEST_FAILED (math $TEST_FAILED + 1)
    end
end

function assert_count --argument-names label expected multiline
    set -l actual (aur_safe_count "$multiline")
    if test $actual -eq $expected
        echo "  ok  $label"
        set -g TEST_PASSED (math $TEST_PASSED + 1)
    else
        echo "  FAIL $label (expected count $expected, got $actual)"
        set -g TEST_FAILED (math $TEST_FAILED + 1)
    end
end

function assert_contains --argument-names label needle haystack
    if string split \n -- "$haystack" | aur_grep -Fxq -- $needle
        echo "  ok  $label"
        set -g TEST_PASSED (math $TEST_PASSED + 1)
    else
        echo "  FAIL $label (expected '$needle' in '$haystack')"
        set -g TEST_FAILED (math $TEST_FAILED + 1)
    end
end

function assert_file_eq --argument-names label expected_file actual_file
    if diff -q $expected_file $actual_file >/dev/null 2>&1
        echo "  ok  $label"
        set -g TEST_PASSED (math $TEST_PASSED + 1)
    else
        echo "  FAIL $label (files differ: $expected_file vs $actual_file)"
        set -g TEST_FAILED (math $TEST_FAILED + 1)
    end
end

function test_section --argument-names name
    echo ""
    echo "## $name"
end

function test_finish --argument-names suite_name
    echo ""
    if test $TEST_FAILED -eq 0
        echo "$suite_name: $TEST_PASSED passed"
        return 0
    end
    echo "$suite_name: $TEST_FAILED failed, $TEST_PASSED passed"
    return 1
end

function test_fixture_path --argument-names relative
    echo (dirname (dirname (status filename)))/fixtures/$relative
end
