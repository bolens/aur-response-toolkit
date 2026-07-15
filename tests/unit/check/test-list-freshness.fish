#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "list-freshness CLI"

set -l script $AUR_SCRIPTS_DIR/check/list-freshness.fish
begin
    fish $script --help >/dev/null
    assert_status "list-freshness --help exits 0" 0
end

test_section "list-freshness missing bundled list exits 3"

set -l missing (mktemp -u)/no-such-atomic-arch-pkgs.txt
set -l _had false
set -l _saved
if set -q AUR_TEST_LIST_FILE
    set _saved $AUR_TEST_LIST_FILE
    set _had true
end
set -gx AUR_TEST_LIST_FILE $missing
begin
    fish $script --local --quiet
    assert_status "missing bundled exits insufficient" $AUR_EXIT_INSUFFICIENT
end
if test $_had = true
    set -gx AUR_TEST_LIST_FILE $_saved
else
    set -e AUR_TEST_LIST_FILE
end

test_finish "test-list-freshness.fish"
exit $status
