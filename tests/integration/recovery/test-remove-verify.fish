#!/usr/bin/env fish

source (dirname (dirname (dirname (status filename))))/support/test-utils.fish

test_reset_counters

function test_remove_verify_case --argument-names label list_type pkg fail_code pass_label
    set -l installed (mktemp)
    printf '%s\n' $pkg >$installed
    set -gx AUR_TEST_INSTALLED_LIST $installed

    switch $list_type
        case atomic-arch
            set -gx AUR_TEST_LIST_FILE (test_fixture_path lists/atomic-arch-pkgs.txt)
        case chaos-rat
            set -gx AUR_TEST_CHAOS_RAT_LIST_FILE (test_fixture_path lists/chaos-rat-pkgs.txt)
        case shai-hulud
            set -gx AUR_TEST_SHAI_HULUD_LIST_FILE (test_fixture_path lists/shai-hulud-pkgs.txt)
        case xeactor
            set -gx AUR_TEST_XEACTOR_LIST_FILE (test_fixture_path lists/xeactor-pkgs.txt)
    end

    set -l fail_out (mktemp)
    fish (aur_script_path recovery/remove-packages.fish) --list $list_type --verify >$fail_out 2>&1
    assert_eq "$label verify fails when pkg installed" $fail_code $status
    assert_match "$label verify failure message" 'VERIFY FAILED' (cat $fail_out | string collect)
    assert_match "$label lists remaining pkg" $pkg (cat $fail_out | string collect)
    rm -f $fail_out

    echo clean-only >$installed
    set -l ok_out (mktemp)
    fish (aur_script_path recovery/remove-packages.fish) --list $list_type --verify >$ok_out 2>&1
    assert_eq "$pass_label verify ok when clean" $AUR_EXIT_CLEAN $status
    assert_match "$pass_label verify ok message" 'VERIFY OK' (cat $ok_out | string collect)
    rm -f $ok_out $installed

    switch $list_type
        case atomic-arch
            set -e AUR_TEST_LIST_FILE
        case chaos-rat
            set -e AUR_TEST_CHAOS_RAT_LIST_FILE
        case shai-hulud
            set -e AUR_TEST_SHAI_HULUD_LIST_FILE
        case xeactor
            set -e AUR_TEST_XEACTOR_LIST_FILE
    end
    set -e AUR_TEST_INSTALLED_LIST
end

test_section "remove-packages --verify atomic-arch"

test_remove_verify_case "atomic-arch" atomic-arch beef $AUR_EXIT_COMPROMISE "atomic-arch"

test_section "remove-packages --verify optional campaigns"

test_remove_verify_case "chaos-rat" chaos-rat chaos-pkg-a $AUR_EXIT_WARN "chaos-rat"
test_remove_verify_case "shai-hulud" shai-hulud shai-pkg-a $AUR_EXIT_WARN "shai-hulud"
test_remove_verify_case "xeactor" xeactor legacy-pkg-a $AUR_EXIT_WARN "xeactor"

test_finish "test-remove-verify.fish"
exit $status
