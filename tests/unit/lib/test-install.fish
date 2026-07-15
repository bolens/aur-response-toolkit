#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters
test_section "install.fish help and staged prefix install"

set -l install $AUR_RESPONSE_DIR/install.fish
begin
    fish $install --help >/dev/null
    assert_status "install --help exits 0" 0
end

set -l stage (mktemp -d)
begin
    fish $install --prefix /usr/local --destdir $stage >/dev/null
    assert_status "staged prefix install exits 0" 0
end
assert_eq "toolkit root exists" 1 (test -d $stage/usr/local/share/aur-response-toolkit; and echo 1; or echo 0)
assert_eq "bootstrap entry installed" 1 (test -f $stage/usr/local/share/aur-response-toolkit/lib/bootstrap.fish; and echo 1; or echo 0)
assert_eq "alpm module installed" 1 (test -f $stage/usr/local/share/aur-response-toolkit/lib/alpm.fish; and echo 1; or echo 0)
assert_eq "aur-response wrapper installed" 1 (test -x $stage/usr/local/bin/aur-response; and echo 1; or echo 0)
assert_match "wrapper pins AUR_RESPONSE_DIR" AUR_RESPONSE_DIR (head -n 3 $stage/usr/local/bin/aur-response | string collect)

rm -rf $stage

test_finish "test-install.fish"
exit $status
