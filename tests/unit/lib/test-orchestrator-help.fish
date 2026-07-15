#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

function assert_text_has --argument-names label needle haystack
    if string match -q -- "*$needle*" -- $haystack
        echo "  ok  $label"
        set -g TEST_PASSED (math $TEST_PASSED + 1)
    else
        echo "  FAIL $label (missing '$needle')"
        set -g TEST_FAILED (math $TEST_FAILED + 1)
    end
end

test_reset_counters
test_section "orchestrator help covers shared + run-only flags"

set -l help_out (mktemp)
fish $AUR_RESPONSE_DIR/run.fish --help >$help_out
assert_status "run.fish --help exits 0" 0

set -l text (cat $help_out | string collect)

assert_text_has "documents --local" '--local' $text
assert_text_has "documents --audit" '--audit' $text
assert_text_has "documents --skip-pkg-check" '--skip-pkg-check' $text
assert_text_has "documents --recover" '--recover' $text
assert_text_has "documents --json" '--json' $text
assert_text_has "documents --prune-days" '--prune-days' $text
assert_text_has "documents --fail-on" '--fail-on' $text
assert_text_has "documents step 4b" '4b.' $text
assert_text_has "mentions packaged name" 'aur-response' $text

# Shared helper lines must appear verbatim in orchestrator help
set -l common_out (mktemp)
fish -c "source $AUR_RESPONSE_DIR/lib/bootstrap.fish; aur_common_flags_help_lines" >$common_out
assert_status "aur_common_flags_help_lines exits 0" 0
while read -l line
    test -n "$line"; or continue
    assert_contains "help contains shared line" $line $text
end <$common_out

rm -f $help_out $common_out

test_section "conventional commit checker"

begin
    fish $AUR_RESPONSE_DIR/scripts/check-conventional-commit.fish --message 'feat: add foo' >/dev/null
    assert_status "valid feat accepted" 0
end
begin
    fish $AUR_RESPONSE_DIR/scripts/check-conventional-commit.fish --message 'chore(deps): bump actions/checkout' >/dev/null
    assert_status "valid scoped chore accepted" 0
end
begin
    fish $AUR_RESPONSE_DIR/scripts/check-conventional-commit.fish --message 'Bump actions/checkout' >/dev/null 2>&1
    assert_status "legacy bump rejected" 1
end
begin
    fish $AUR_RESPONSE_DIR/scripts/check-conventional-commit.fish --message 'fixed stuff' >/dev/null 2>&1
    assert_status "nonconventional rejected" 1
end

test_finish "test-orchestrator-help.fish"
exit $status
