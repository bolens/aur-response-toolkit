# Shared optional-campaign check/timeline runners (chaos-rat / shai-hulud / xeactor).

function aur_run_optional_campaign_pkg_check --argument-names campaign
    set -l title
    set -l report_prefix
    set -l load_fn
    set -l installed_fn
    set -l classify_fn
    set -l window_label
    set -l summary_installed
    set -l summary_high
    set -l in_window_global
    set -l outside_global
    set -l remove_list
    set -l empty_msg
    set -l warn_label
    set -l clean_msg
    set -l post_notes

    switch $campaign
        case chaos-rat
            set title "Chaos RAT"
            set report_prefix chaos-rat-pkg-scan-
            set load_fn aur_load_and_read_chaos_rat_list
            set installed_fn aur_installed_chaos_rat_pkgs
            set classify_fn aur_classify_chaos_rat_pkg
            set window_label $AUR_CHAOS_RAT_WINDOW_LABEL
            set summary_installed chaos_rat_installed
            set summary_high chaos_rat_high_risk
            set in_window_global AUR_CHAOS_RAT_FOUND_IN_WINDOW
            set outside_global AUR_CHAOS_RAT_FOUND_OUTSIDE_WINDOW
            set remove_list chaos-rat
            set empty_msg "Chaos RAT list empty (parsed 0 packages)"
            set warn_label "Chaos RAT"
            set clean_msg "Clean: none of the known Chaos RAT packages are installed."
            set post_notes "Suggested removal (review HIGH first; separate threat from Atomic Arch):"
        case shai-hulud
            set title Shai-Hulud
            set report_prefix shai-hulud-pkg-scan-
            set load_fn aur_load_and_read_shai_hulud_list
            set installed_fn aur_installed_shai_hulud_pkgs
            set classify_fn aur_classify_shai_hulud_pkg
            set window_label $AUR_SHAI_HULUD_WINDOW_LABEL
            set summary_installed shai_hulud_installed
            set summary_high shai_hulud_high_risk
            set in_window_global AUR_SHAI_HULUD_FOUND_IN_WINDOW
            set outside_global AUR_SHAI_HULUD_FOUND_OUTSIDE_WINDOW
            set remove_list shai-hulud
            set empty_msg "Shai-Hulud list empty (parsed 0 packages)"
            set warn_label Shai-Hulud
            set clean_msg "Clean: none of the known Shai-Hulud packages are installed."
            set post_notes "Suggested removal (review HIGH first; separate threat from Atomic Arch):"
        case xeactor
            set title "2018 xeactor"
            set report_prefix xeactor-pkg-scan-
            set load_fn aur_load_and_read_xeactor_list
            set installed_fn aur_installed_xeactor_pkgs
            set classify_fn aur_classify_xeactor_pkg
            set window_label $AUR_XEACTOR_WINDOW_LABEL
            set summary_installed xeactor_installed
            set summary_high xeactor_high_risk
            set in_window_global AUR_XEACTOR_FOUND_IN_WINDOW
            set outside_global AUR_XEACTOR_FOUND_OUTSIDE_WINDOW
            set remove_list xeactor
            set empty_msg "xeactor list empty (parsed 0 packages)"
            set warn_label xeactor
            set clean_msg "Clean: none of the known 2018 xeactor packages are installed."
            set post_notes "Suggested removal (review HIGH first; separate 2018 xeactor incident):"
        case '*'
            echo "error: unknown optional campaign: $campaign" >&2
            return $AUR_EXIT_INVALID
    end

    aur_begin_report_if_requested $report_prefix

    set -l exit_code $AUR_EXIT_CLEAN
    set -l pkgs ($load_fn $AUR_OPT_local)
    if test $status -ne 0
        aur_insufficient_data "$title list unavailable"
        return $AUR_EXIT_INSUFFICIENT
    end

    set -l pkg_count (count $pkgs)
    if test $pkg_count -eq 0
        aur_insufficient_data $empty_msg
        return $AUR_EXIT_INSUFFICIENT
    end

    if test $AUR_OPT_all_time = true
        aur_log "Checking $pkg_count known $title packages (--all-time; ignoring $window_label)"
    else
        aur_log "Checking $pkg_count known $title packages ($window_label window)..."
    end
    aur_log ""

    set -l found ($installed_fn)
    set -g $in_window_global
    set -g $outside_global

    if test (count $found) -gt 0
        set exit_code $AUR_EXIT_WARN
        aur_summary_set $summary_installed (count $found)
        aur_log "WARNING: "(count $found)" $warn_label package(s) installed:"
        aur_log ""

        for pkg in $found
            $classify_fn $pkg
        end
        switch $campaign
            case chaos-rat
                aur_summary_set $summary_high (count $AUR_CHAOS_RAT_FOUND_IN_WINDOW)
            case shai-hulud
                aur_summary_set $summary_high (count $AUR_SHAI_HULUD_FOUND_IN_WINDOW)
            case xeactor
                aur_summary_set $summary_high (count $AUR_XEACTOR_FOUND_IN_WINDOW)
        end

        aur_log ""
        aur_log $post_notes
        aur_log "  fish (aur_script_path recovery/remove-packages.fish) --list $remove_list"
        aur_log "  # or: sudo pacman -Rns "(string join ' ' $found)
        if test $campaign = shai-hulud
            aur_log ""
            aur_log "Before rotating GitHub tokens: stop gh-token-monitor if present (see scan/malware-artifacts.fish)."
        end
    else
        aur_log $clean_msg
    end

    return $exit_code
end

function aur_run_optional_campaign_timeline --argument-names campaign
    set -l title
    set -l report_prefix
    set -l list_path_fn
    set -l collect_fn
    set -l window_label
    set -l hits_summary
    set -l hits_finding
    set -l repeat_finding
    set -l repeat_summary
    set -l ok_msg

    switch $campaign
        case chaos-rat
            set title "Chaos RAT"
            set report_prefix chaos-rat-timeline-
            set list_path_fn aur_chaos_rat_list_file_path
            set collect_fn aur_collect_chaos_rat_window_alpm_events_all
            set window_label $AUR_CHAOS_RAT_WINDOW_LABEL
            set hits_summary chaos_rat_timeline_hits
            set hits_finding chaos_rat_timeline_hits
            set repeat_finding chaos_rat_timeline_repeat_updates
            set repeat_summary chaos_rat_timeline_repeat_updates
            set ok_msg "[OK] No Chaos RAT packages in pacman logs during $AUR_CHAOS_RAT_WINDOW_LABEL"
        case shai-hulud
            set title Shai-Hulud
            set report_prefix shai-hulud-timeline-
            set list_path_fn aur_shai_hulud_list_file_path
            set collect_fn aur_collect_shai_hulud_window_alpm_events_all
            set window_label $AUR_SHAI_HULUD_WINDOW_LABEL
            set hits_summary shai_hulud_timeline_hits
            set hits_finding shai_hulud_timeline_hits
            set repeat_finding shai_hulud_timeline_repeat_updates
            set repeat_summary shai_hulud_timeline_repeat_updates
            set ok_msg "[OK] No Shai-Hulud packages in pacman logs during $AUR_SHAI_HULUD_WINDOW_LABEL"
        case xeactor
            set title xeactor
            set report_prefix xeactor-timeline-
            set list_path_fn aur_xeactor_list_file_path
            set collect_fn aur_collect_xeactor_window_alpm_events_all
            set window_label $AUR_XEACTOR_WINDOW_LABEL
            set hits_summary xeactor_timeline_hits
            set hits_finding xeactor_timeline_hits
            set repeat_finding xeactor_timeline_repeat_updates
            set repeat_summary xeactor_timeline_repeat_updates
            set ok_msg "[OK] No xeactor packages in pacman logs during $AUR_XEACTOR_WINDOW_LABEL"
        case '*'
            echo "error: unknown optional campaign: $campaign" >&2
            return $AUR_EXIT_INVALID
    end

    aur_begin_report_if_requested $report_prefix

    aur_log "=== $title pacman install timeline ==="
    if test $AUR_OPT_all_time = true
        aur_log "Scanning pacman logs for $title packages (all dates; --all-time)"
    else
        aur_log "Scanning pacman logs for $title packages, $window_label"
    end
    aur_log ""

    aur_require_pacman_logs

    set -l list_file ($list_path_fn)
    if not test -f $list_file
        aur_insufficient_data "$list_file missing"
        return $AUR_EXIT_INSUFFICIENT
    end

    set -l events (mktemp)
    if test $AUR_OPT_all_time = true
        aur_collect_all_time_alpm_events_all $events
    else
        $collect_fn $events
    end

    set -l raw (aur_timeline_hits_from_events $events $list_file | string collect)
    set -l hit_count (aur_safe_count "$raw")
    rm -f $events

    if test $hit_count -eq 0
        aur_log $ok_msg
    else
        aur_summary_set $hits_summary $hit_count
        aur_log "[FOUND] $hit_count $title timeline hit(s):"
        for hit in (string split \n -- "$raw")
            test -n "$hit"; or continue
            aur_finding_add $hits_finding $hit
            aur_log "  $hit"
        end
        set -l repeat_events (mktemp)
        set -l saved_all_time $AUR_OPT_all_time
        set -g AUR_OPT_all_time false
        $collect_fn $repeat_events
        set -g AUR_OPT_all_time $saved_all_time
        aur_report_timeline_repeat_updates $repeat_events $list_file $repeat_finding $repeat_summary "during $window_label"
        rm -f $repeat_events
        aur_log ""
        aur_log "Removed packages still appear. Review each — only installs during the attack window are HIGH risk."
        return $AUR_EXIT_WARN
    end

    aur_log ""
    return $AUR_EXIT_CLEAN
end
