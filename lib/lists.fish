# Campaign list path/enable helpers.

# Prefer writable cache when present; else shipped bundle (FHS --local).
# Tests set AUR_TEST_*_LIST_FILE to override both read and write.
function aur_atomic_arch_list_bundled_path
    echo $AUR_ATOMIC_ARCH_LIST_BUNDLED
end

# campaign: atomic-arch | chaos-rat | shai-hulud | xeactor
function aur_list_file_path --argument-names campaign
    switch $campaign
        case atomic-arch
            if set -q AUR_TEST_LIST_FILE
                echo $AUR_TEST_LIST_FILE
                return
            end
            if test -f $AUR_ATOMIC_ARCH_LIST_FILE
                echo $AUR_ATOMIC_ARCH_LIST_FILE
                return
            end
            echo $AUR_ATOMIC_ARCH_LIST_BUNDLED
        case chaos-rat
            if set -q AUR_TEST_CHAOS_RAT_LIST_FILE
                echo $AUR_TEST_CHAOS_RAT_LIST_FILE
                return
            end
            if test -f $AUR_CHAOS_RAT_LIST_FILE
                echo $AUR_CHAOS_RAT_LIST_FILE
                return
            end
            echo $AUR_CHAOS_RAT_LIST_BUNDLED
        case shai-hulud
            if set -q AUR_TEST_SHAI_HULUD_LIST_FILE
                echo $AUR_TEST_SHAI_HULUD_LIST_FILE
                return
            end
            if test -f $AUR_SHAI_HULUD_LIST_FILE
                echo $AUR_SHAI_HULUD_LIST_FILE
                return
            end
            echo $AUR_SHAI_HULUD_LIST_BUNDLED
        case xeactor
            if set -q AUR_TEST_XEACTOR_LIST_FILE
                echo $AUR_TEST_XEACTOR_LIST_FILE
                return
            end
            if test -f $AUR_XEACTOR_LIST_FILE
                echo $AUR_XEACTOR_LIST_FILE
                return
            end
            echo $AUR_XEACTOR_LIST_BUNDLED
        case '*'
            echo "error: unknown list campaign: $campaign" >&2
            return 1
    end
end

function aur_list_write_path --argument-names campaign
    switch $campaign
        case atomic-arch
            if set -q AUR_ATOMIC_ARCH_LIST_WRITE_FILE
                echo $AUR_ATOMIC_ARCH_LIST_WRITE_FILE
                return
            end
            if set -q AUR_TEST_LIST_FILE
                echo $AUR_TEST_LIST_FILE
                return
            end
            echo $AUR_ATOMIC_ARCH_LIST_FILE
        case chaos-rat
            if set -q AUR_TEST_CHAOS_RAT_LIST_FILE
                echo $AUR_TEST_CHAOS_RAT_LIST_FILE
                return
            end
            echo $AUR_CHAOS_RAT_LIST_FILE
        case shai-hulud
            if set -q AUR_TEST_SHAI_HULUD_LIST_FILE
                echo $AUR_TEST_SHAI_HULUD_LIST_FILE
                return
            end
            echo $AUR_SHAI_HULUD_LIST_FILE
        case xeactor
            if set -q AUR_TEST_XEACTOR_LIST_FILE
                echo $AUR_TEST_XEACTOR_LIST_FILE
                return
            end
            echo $AUR_XEACTOR_LIST_FILE
        case '*'
            echo "error: unknown list campaign: $campaign" >&2
            return 1
    end
end

function aur_atomic_arch_list_file_path
    aur_list_file_path atomic-arch
end

function aur_atomic_arch_list_write_path
    aur_list_write_path atomic-arch
end

function aur_chaos_rat_list_file_path
    aur_list_file_path chaos-rat
end

function aur_chaos_rat_list_write_path
    aur_list_write_path chaos-rat
end

function aur_shai_hulud_list_file_path
    aur_list_file_path shai-hulud
end

function aur_shai_hulud_list_write_path
    aur_list_write_path shai-hulud
end

function aur_xeactor_list_file_path
    aur_list_file_path xeactor
end

function aur_xeactor_list_write_path
    aur_list_write_path xeactor
end

function aur_optional_campaign_enabled --argument-names opt_flag enable_var
    if test $$opt_flag = true
        return 0
    end
    set -l enable_val $$enable_var
    if test "$enable_val" = 1
        return 0
    end
    return 1
end

function aur_chaos_rat_enabled
    aur_optional_campaign_enabled AUR_OPT_chaos_rat AUR_ENABLE_CHAOS_RAT
end

function aur_shai_hulud_enabled
    aur_optional_campaign_enabled AUR_OPT_shai_hulud AUR_ENABLE_SHAI_HULUD
end

function aur_xeactor_enabled
    aur_optional_campaign_enabled AUR_OPT_xeactor AUR_ENABLE_XEACTOR
end
