# Pacman log ALPM event collection, timeline helpers, installed-pkg queries.

# Stream pacman log lines; transparently decompress .gz/.xz/.zst/.bz2 rotated logs.
function aur_zstdcat --argument-names path
    if command -q zstdcat
        command zstdcat -- $path 2>/dev/null
    else if command -q zstd
        command zstd -dc -- $path 2>/dev/null
    end
end

function aur_read_pacman_log --argument-names log_path
    switch $log_path
        case '*.gz'
            command gzip -cd -- $log_path 2>/dev/null
        case '*.xz'
            command xz -cd -- $log_path 2>/dev/null
        case '*.zst'
            aur_zstdcat $log_path
        case '*.bz2'
            command bzip2 -cd -- $log_path 2>/dev/null
        case '*'
            cat -- $log_path 2>/dev/null
    end
end

# Only installed|upgraded|reinstalled count; "removed" during the window is not a new install.
function aur_is_alpm_install_line --argument-names line
    string match -qr '\[ALPM\] (installed|upgraded|reinstalled)' -- $line
end

function aur_extract_alpm_pkg_from_line --argument-names line
    set -l parts (string match -r '\[ALPM\] (?:installed|upgraded|reinstalled) (\S+) \(' $line)
    echo $parts[2]
end

# Collect install/upgrade/reinstall events. Output: "pkgname|full pacman log line".
# window_fn: name of a line predicate (empty = all-time / no date filter).
# Read via a tempfile — fish `| while` can race and return before the reader finishes.
function aur_collect_alpm_events --argument-names log_path out_file window_fn
    set -l raw (mktemp)
    aur_read_pacman_log $log_path >$raw
    while read -l line
        aur_is_alpm_install_line $line; or continue
        if test -n "$window_fn"
            $window_fn $line; or continue
        end
        set -l pkg (aur_extract_alpm_pkg_from_line $line)
        test -n "$pkg"; or continue
        echo "$pkg|$line" >>$out_file
    end <$raw
    rm -f $raw
end

function aur_alpm_events_cache_path --argument-names window_fn
    if not set -q AUR_ALPM_CACHE_DIR
        return 1
    end
    set -l tag all
    test -n "$window_fn"; and set tag $window_fn
    set -l mode window
    test $AUR_OPT_all_time = true; and set mode alltime
    echo "$AUR_ALPM_CACHE_DIR/$tag.$mode.events"
end

function aur_collect_alpm_events_all --argument-names out_file window_fn
    if set -q AUR_ALPM_CACHE_DIR; and test -d "$AUR_ALPM_CACHE_DIR"
        set -l cache (aur_alpm_events_cache_path $window_fn)
        if test -f $cache
            cat $cache >$out_file
            return
        end
        for log_path in (aur_pacman_log_paths)
            aur_collect_alpm_events $log_path $out_file $window_fn
        end
        cp $out_file $cache
        return
    end
    for log_path in (aur_pacman_log_paths)
        aur_collect_alpm_events $log_path $out_file $window_fn
    end
end

function aur_collect_all_time_alpm_events_all --argument-names out_file
    aur_collect_alpm_events_all $out_file ""
end

# Collect install/upgrade/reinstall events in the compromise window.
function aur_collect_window_alpm_events --argument-names log_path out_file
    aur_collect_alpm_events $log_path $out_file aur_log_line_in_compromise_window
end

function aur_collect_window_alpm_events_all --argument-names out_file
    aur_collect_alpm_events_all $out_file aur_log_line_in_compromise_window
end

# Attack-window events only — ignores --all-time (repeat updates are window-scoped).
function aur_collect_attack_window_alpm_events_all --argument-names out_file
    set -l saved_all_time $AUR_OPT_all_time
    set -g AUR_OPT_all_time false
    aur_collect_window_alpm_events_all $out_file
    set -g AUR_OPT_all_time $saved_all_time
end

# Pre-fill AUR_ALPM_CACHE_DIR for window/timeline steps that spawn as subprocesses.
# No-op when cache dir unset or pacman logs are unreadable.
function aur_warmup_alpm_event_caches
    set -q AUR_ALPM_CACHE_DIR; or return 0
    test -d "$AUR_ALPM_CACHE_DIR"; or return 0
    aur_pacman_logs_accessible; or return 0

    set -l tmp (mktemp)
    # Steps 2–3 (aur-window + atomic timeline) — respects --all-time.
    aur_collect_window_alpm_events_all $tmp
    # Repeat-update scans always use the dated attack window.
    aur_collect_attack_window_alpm_events_all $tmp
    if test $AUR_OPT_all_time = true
        aur_collect_all_time_alpm_events_all $tmp
    end

    set -l saved_all_time $AUR_OPT_all_time
    set -g AUR_OPT_all_time false
    if aur_chaos_rat_enabled
        aur_collect_chaos_rat_window_alpm_events_all $tmp
    end
    if aur_shai_hulud_enabled
        aur_collect_shai_hulud_window_alpm_events_all $tmp
    end
    if aur_xeactor_enabled
        aur_collect_xeactor_window_alpm_events_all $tmp
    end
    set -g AUR_OPT_all_time $saved_all_time
    rm -f $tmp
end

function aur_collect_chaos_rat_window_alpm_events --argument-names log_path out_file
    aur_collect_alpm_events $log_path $out_file aur_log_line_in_chaos_rat_window
end

function aur_collect_chaos_rat_window_alpm_events_all --argument-names out_file
    aur_collect_alpm_events_all $out_file aur_log_line_in_chaos_rat_window
end

function aur_collect_shai_hulud_window_alpm_events --argument-names log_path out_file
    aur_collect_alpm_events $log_path $out_file aur_log_line_in_shai_hulud_window
end

function aur_collect_shai_hulud_window_alpm_events_all --argument-names out_file
    aur_collect_alpm_events_all $out_file aur_log_line_in_shai_hulud_window
end

function aur_collect_xeactor_window_alpm_events --argument-names log_path out_file
    aur_collect_alpm_events $log_path $out_file aur_log_line_in_xeactor_window
end

function aur_collect_xeactor_window_alpm_events_all --argument-names out_file
    aur_collect_alpm_events_all $out_file aur_log_line_in_xeactor_window
end

function aur_pacman_logs_accessible
    set -l found false
    for log_path in (aur_pacman_log_paths)
        if test -r $log_path
            set found true
            break
        end
    end
    test $found = true
end

# pacman -Qmq = foreign (AUR) packages only; official repos are out of scope for this campaign.
function aur_installed_foreign_packages
    if set -q AUR_TEST_INSTALLED_LIST
        cat $AUR_TEST_INSTALLED_LIST
        return $status
    end
    if set -q AUR_TEST_FOREIGN_LIST
        cat $AUR_TEST_FOREIGN_LIST
        return $status
    end
    command -q pacman; or return 1
    pacman -Qmq 2>/dev/null
end

# True when the package is installed (respects test mocks; no fish error when pacman is absent).
function aur_pkg_is_installed --argument-names pkg
    if set -q AUR_TEST_PKG_INFO
        set -l row (aur_grep -m1 -F "$pkg|" $AUR_TEST_PKG_INFO 2>/dev/null)
        if test -n "$row"
            return 0
        end
    end
    if set -q AUR_TEST_INSTALLED_LIST
        aur_grep -q -x -F -- $pkg $AUR_TEST_INSTALLED_LIST
        return $status
    end
    if set -q AUR_TEST_FOREIGN_LIST
        aur_grep -q -x -F -- $pkg $AUR_TEST_FOREIGN_LIST
        return $status
    end
    command -q pacman; or return 1
    pacman -Qi $pkg >/dev/null 2>&1
end

function aur_foreign_package_names
    aur_installed_foreign_packages $argv
end

# Installed foreign packages ∩ lines from a list file (comm -12).
function aur_installed_pkgs_matching_list --argument-names list_file
    if not test -f "$list_file"
        return 1
    end
    set -l installed_sorted (mktemp)
    set -l list_sorted (mktemp)
    aur_installed_foreign_packages | sort >$installed_sorted
    sort -u $list_file >$list_sorted
    comm -12 $installed_sorted $list_sorted
    set -l exit_code $status
    rm -f $installed_sorted $list_sorted
    return $exit_code
end

# Installed foreign packages ∩ infected list (comm -12). Optional args: pre-parsed infected pkg names.
function aur_installed_atomic_arch_pkgs
    if test (count $argv) -gt 0
        set -l installed_sorted (mktemp)
        set -l infected_sorted (mktemp)
        aur_installed_foreign_packages | sort >$installed_sorted
        string join \n -- $argv | sort >$infected_sorted
        comm -12 $installed_sorted $infected_sorted
        set -l exit_code $status
        rm -f $installed_sorted $infected_sorted
        return $exit_code
    end
    aur_installed_pkgs_matching_list (aur_atomic_arch_list_file_path)
end

function aur_installed_chaos_rat_pkgs
    aur_installed_pkgs_matching_list (aur_chaos_rat_list_file_path)
end

function aur_installed_shai_hulud_pkgs
    aur_installed_pkgs_matching_list (aur_shai_hulud_list_file_path)
end

function aur_installed_xeactor_pkgs
    aur_installed_pkgs_matching_list (aur_xeactor_list_file_path)
end

# True when ignore-scripts is set in ~/.npmrc or via npm config.
function aur_npm_ignore_scripts_enabled
    if test -f $HOME/.npmrc
        if string match -qir 'ignore-scripts\s*=\s*true' (cat $HOME/.npmrc)
            return 0
        end
    end
    if command -q npm
        set -l npm_cfg (npm config get ignore-scripts 2>/dev/null | string trim)
        if test "$npm_cfg" = true
            return 0
        end
    end
    return 1
end

# Tests: AUR_TEST_PKG_INFO lines are "pkg|Install Date text|Install Reason text".
function aur_test_pkg_info_field --argument-names pkg field_index
    if not set -q AUR_TEST_PKG_INFO
        return 1
    end
    set -l row (aur_grep -m1 -F "$pkg|" $AUR_TEST_PKG_INFO)
    test -n "$row"; or return 1
    set -l parts (string split '|' -- $row)
    test (count $parts) -ge $field_index; or return 1
    echo $parts[$field_index]
end

# Includes rotated logs (pacman.log.*). Tests override via AUR_TEST_PACMAN_LOG_DIR.
function aur_pacman_log_dir
    if set -q AUR_TEST_PACMAN_LOG_DIR
        echo $AUR_TEST_PACMAN_LOG_DIR
        return
    end
    if set -q AUR_PACMAN_LOG_DIR
        echo $AUR_PACMAN_LOG_DIR
        return
    end
    echo /var/log
end

function aur_pacman_local_dir
    if set -q AUR_TEST_PACMAN_LOCAL_DIR
        echo $AUR_TEST_PACMAN_LOCAL_DIR
        return
    end
    if set -q AUR_PACMAN_LOCAL_DIR
        echo $AUR_PACMAN_LOCAL_DIR
        return
    end
    echo /var/lib/pacman/local
end

function aur_pacman_log_paths
    set -l log_dir (aur_pacman_log_dir)
    for log_path in $log_dir/pacman.log $log_dir/pacman.log.*
        test -f $log_path; and echo $log_path
    end
end

function aur_event_line_from_hit --argument-names hit
    echo (string split -m1 '|' -- "$hit")[2]
end

# Intersect window events with the known infected list; return matching log lines only.
function aur_timeline_hits_from_events --argument-names events_file list_file
    set -l infected_sorted (mktemp)
    set -l window_pkgs (mktemp)
    set -l matching (mktemp)
    set -l hits_raw (mktemp)

    sort -u $list_file >$infected_sorted
    cut -d'|' -f1 $events_file | sort -u >$window_pkgs
    comm -12 $window_pkgs $infected_sorted >$matching

    while read -l pkg
        aur_grep -F "$pkg|" $events_file >>$hits_raw
    end <$matching

    if test -s $hits_raw
        while read -l hit
            aur_event_line_from_hit "$hit"
        end <$hits_raw
    end

    rm -f $infected_sorted $window_pkgs $matching $hits_raw
end

function aur_pkg_event_count_in_events --argument-names events_file pkg
    set -l hits (mktemp)
    aur_grep -F "$pkg|" $events_file >$hits
    set -l count (string match -r . <$hits | count)
    rm -f $hits
    echo $count
end

# Sorted pacman log lines for one package from pkg|line event records.
function aur_pkg_event_lines_from_events --argument-names events_file pkg
    set -l hits (mktemp)
    aur_grep -F "$pkg|" $events_file >$hits
    set -l lines
    while read -l hit
        set -a lines (aur_event_line_from_hit "$hit")
    end <$hits
    rm -f $hits
    if test (count $lines) -eq 0
        return 1
    end
    printf '%s\n' $lines | sort
end

# Known infected packages with 2+ install/upgrade/reinstall events in events_file.
# One output line per package: pkg|count|line1 ;; line2 (chronological).
function aur_timeline_repeat_updates_from_events --argument-names events_file list_file
    set -l infected_sorted (mktemp)
    set -l window_pkgs (mktemp)
    set -l matching (mktemp)

    sort -u $list_file >$infected_sorted
    cut -d'|' -f1 $events_file | sort -u >$window_pkgs
    comm -12 $window_pkgs $infected_sorted >$matching

    while read -l pkg
        set -l count (aur_pkg_event_count_in_events $events_file $pkg)
        if test $count -lt 2
            continue
        end
        set -l sorted (aur_pkg_event_lines_from_events $events_file $pkg)
        set -l joined (string join ' ;; ' $sorted)
        echo "$pkg|$count|$joined"
    end <$matching

    rm -f $infected_sorted $window_pkgs $matching
end

# Log repeat-window update findings (first touch may be malicious; later may be post-takedown).
function aur_report_timeline_repeat_updates --argument-names events_file list_file finding_category summary_key window_label
    set -l raw (aur_timeline_repeat_updates_from_events $events_file $list_file | string collect)
    if test -z "$raw"
        return 1
    end
    set -l repeat_pkg_count 0
    for record in (string split \n -- "$raw")
        test -n "$record"; or continue
        set -l parts (string split -m2 '|' -- "$record")
        test (count $parts) -lt 3; and continue
        set -l pkg $parts[1]
        set -l n $parts[2]
        set -l lines $parts[3]
        set repeat_pkg_count (math $repeat_pkg_count + 1)
        aur_finding_add $finding_category "$record"
        aur_log "  [REPEAT] $pkg — $n updates $window_label:"
        for l in (string split ' ;; ' -- "$lines")
            aur_log "           $l"
        end
        aur_log "           earliest update may have pulled malware; later update may be post-takedown"
    end
    if test $repeat_pkg_count -gt 0
        aur_summary_set $summary_key $repeat_pkg_count
        return 0
    end
    return 1
end

# Foreign (AUR) packages touched during the window — includes packages later removed.
function aur_foreign_packages_in_window --argument-names events_file foreign_list_file
    set -l foreign_sorted (mktemp)
    set -l window_pkgs (mktemp)
    set -l foreign_in_window (mktemp)

    sort -u $foreign_list_file >$foreign_sorted
    cut -d'|' -f1 $events_file | sort -u >$window_pkgs
    comm -12 $window_pkgs $foreign_sorted >$foreign_in_window
    cat $foreign_in_window

    rm -f $foreign_sorted $window_pkgs $foreign_in_window
end

# Count lines in a multiline string safely (fish empty-string pitfalls).
function aur_safe_count --argument-names multiline
    if test -z "$multiline"
        echo 0
        return
    end
    set -l tmp (mktemp)
    printf '%s\n' "$multiline" >$tmp
    set -l n (string match -r . <$tmp | count)
    rm -f $tmp
    echo $n
end
