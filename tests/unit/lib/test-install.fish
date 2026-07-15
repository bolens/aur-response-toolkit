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
assert_eq "fish completions installed" 1 (test -f $stage/usr/local/share/fish/vendor_completions.d/aur-response.fish; and echo 1; or echo 0)
assert_match "wrapper pins AUR_RESPONSE_DIR" AUR_RESPONSE_DIR (head -n 3 $stage/usr/local/bin/aur-response | string collect)

rm -rf $stage

set -l home (mktemp -d)
begin
    env HOME=$home fish $install >/dev/null
    assert_status "user install exits 0" 0
end
assert_eq "user aur-response wrapper" 1 (test -x $home/.local/bin/aur-response; and echo 1; or echo 0)
assert_eq "user run.fish wrapper" 1 (test -x $home/.local/bin/run.fish; and echo 1; or echo 0)
assert_eq "user completions" 1 (test -f $home/.config/fish/completions/aur-response.fish; and echo 1; or echo 0)
rm -rf $home

test_finish "test-install.fish"
exit $status
