# Campaign date-window predicates and package classifiers.

# pacman -Qi uses "DD Mon YYYY" — different format from pacman.log ISO timestamps.
function aur_install_date_in_text_window --argument-names date_line year days_re month
    if test -z "$date_line"
        return 1
    end
    if not string match -qr ".*$year.*" -- $date_line
        return 1
    end
    if string match -qr ".*\\s$days_re\\s+$month\\s+" -- $date_line
        return 0
    end
    return 1
end

function aur_install_in_pkg_window --argument-names pkg epoch_fn date_fn
    set -l epoch (aur_pkg_install_epoch $pkg 2>/dev/null)
    if test -n "$epoch"
        $epoch_fn $epoch
        return $status
    end
    set -l date_text (aur_pkg_install_date $pkg)
    if test "$date_text" = unknown
        return 1
    end
    $date_fn "Install Date    : $date_text"
end

function aur_log_line_matches_window_re --argument-names line log_re
    test $AUR_OPT_all_time = true; and return 0
    string match -qr $log_re -- $line
end

function aur_install_date_in_window --argument-names date_line
    aur_install_date_in_text_window $date_line $AUR_COMPROMISE_YEAR $AUR_WINDOW_INSTALL_DAYS_RE $AUR_WINDOW_INSTALL_MONTH
end

function aur_install_in_compromise_window --argument-names pkg
    aur_install_in_pkg_window $pkg aur_epoch_in_atomic_arch_window aur_install_date_in_window
end

function aur_log_line_in_compromise_window --argument-names line
    aur_log_line_matches_window_re $line $AUR_WINDOW_LOG_RE
end

function aur_install_in_window_or_all_time --argument-names pkg
    test $AUR_OPT_all_time = true; and return 0
    aur_install_in_compromise_window $pkg
end

# Classify one Atomic Arch list match: HIGH (window or --all-time) vs LOW. Updates AUR_FOUND_* globals.
# Shared HIGH/LOW classifier. window_fn / *_global are function/var names (Fish call-by-name).
function aur_classify_campaign_pkg --argument-names pkg installed_cat high_cat window_fn window_label in_window_global outside_global
    aur_finding_add $installed_cat $pkg
    set -l install_date (aur_pkg_install_date $pkg)
    set -l install_reason (aur_pkg_install_reason $pkg)
    if $window_fn $pkg
        set -ga $in_window_global $pkg
        aur_finding_add $high_cat $pkg
        aur_log "  [HIGH]   $pkg"
        aur_log "           installed: $install_date | reason: $install_reason"
    else if test $AUR_OPT_all_time = true
        set -ga $in_window_global $pkg
        aur_finding_add $high_cat $pkg
        aur_log "  [HIGH]   $pkg"
        aur_log "           installed: $install_date | reason: $install_reason (--all-time)"
    else
        set -ga $outside_global $pkg
        aur_log "  [LOW]    $pkg"
        aur_log "           installed: $install_date | reason: $install_reason (outside $window_label)"
    end
end

function aur_classify_atomic_arch_installed_pkg --argument-names pkg
    aur_classify_campaign_pkg $pkg atomic_arch_installed atomic_arch_high_risk \
        aur_install_in_compromise_window $AUR_WINDOW_LABEL \
        AUR_FOUND_IN_WINDOW AUR_FOUND_OUTSIDE_WINDOW
end

function aur_classify_chaos_rat_pkg --argument-names pkg
    aur_classify_campaign_pkg $pkg chaos_rat_installed chaos_rat_high_risk \
        aur_install_in_chaos_rat_window $AUR_CHAOS_RAT_WINDOW_LABEL \
        AUR_CHAOS_RAT_FOUND_IN_WINDOW AUR_CHAOS_RAT_FOUND_OUTSIDE_WINDOW
end

function aur_classify_shai_hulud_pkg --argument-names pkg
    aur_classify_campaign_pkg $pkg shai_hulud_installed shai_hulud_high_risk \
        aur_install_in_shai_hulud_window $AUR_SHAI_HULUD_WINDOW_LABEL \
        AUR_SHAI_HULUD_FOUND_IN_WINDOW AUR_SHAI_HULUD_FOUND_OUTSIDE_WINDOW
end

function aur_classify_xeactor_pkg --argument-names pkg
    aur_classify_campaign_pkg $pkg xeactor_installed xeactor_high_risk \
        aur_install_in_xeactor_window $AUR_XEACTOR_WINDOW_LABEL \
        AUR_XEACTOR_FOUND_IN_WINDOW AUR_XEACTOR_FOUND_OUTSIDE_WINDOW
end

function aur_install_date_in_shai_hulud_window --argument-names date_line
    aur_install_date_in_text_window $date_line $AUR_SHAI_HULUD_YEAR $AUR_SHAI_HULUD_WINDOW_INSTALL_DAYS_RE $AUR_SHAI_HULUD_WINDOW_INSTALL_MONTH
end

function aur_install_in_shai_hulud_window --argument-names pkg
    aur_install_in_pkg_window $pkg aur_epoch_in_shai_hulud_window aur_install_date_in_shai_hulud_window
end

function aur_log_line_in_shai_hulud_window --argument-names line
    aur_log_line_matches_window_re $line $AUR_SHAI_HULUD_WINDOW_LOG_RE
end

function aur_install_in_shai_hulud_window_or_all_time --argument-names pkg
    test $AUR_OPT_all_time = true; and return 0
    aur_install_in_shai_hulud_window $pkg
end

function aur_install_date_in_xeactor_window --argument-names date_line
    if test -z "$date_line"
        return 1
    end
    if not string match -qr ".*$AUR_XEACTOR_YEAR.*" -- $date_line
        return 1
    end
    if string match -qr ".*\\s(0?[7-9]|[12][0-9]|30)\\s+Jun\\s+" -- $date_line
        return 0
    end
    if string match -qr ".*\\s(0?[1-9]|10)\\s+Jul\\s+" -- $date_line
        return 0
    end
    return 1
end

function aur_install_in_xeactor_window --argument-names pkg
    aur_install_in_pkg_window $pkg aur_epoch_in_xeactor_window aur_install_date_in_xeactor_window
end

function aur_log_line_in_xeactor_window --argument-names line
    aur_log_line_matches_window_re $line $AUR_XEACTOR_WINDOW_LOG_RE
end

function aur_install_in_xeactor_window_or_all_time --argument-names pkg
    test $AUR_OPT_all_time = true; and return 0
    aur_install_in_xeactor_window $pkg
end

function aur_install_date_in_chaos_rat_window --argument-names date_line
    aur_install_date_in_text_window $date_line $AUR_CHAOS_RAT_YEAR $AUR_CHAOS_RAT_WINDOW_INSTALL_DAYS_RE $AUR_CHAOS_RAT_WINDOW_INSTALL_MONTH
end

function aur_install_in_chaos_rat_window --argument-names pkg
    aur_install_in_pkg_window $pkg aur_epoch_in_chaos_rat_window aur_install_date_in_chaos_rat_window
end

function aur_log_line_in_chaos_rat_window --argument-names line
    aur_log_line_matches_window_re $line $AUR_CHAOS_RAT_WINDOW_LOG_RE
end

function aur_install_in_chaos_rat_window_or_all_time --argument-names pkg
    test $AUR_OPT_all_time = true; and return 0
    aur_install_in_chaos_rat_window $pkg
end
