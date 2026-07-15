# File/hook helpers, list loaders, preflight, and related package utilities.

function aur_file_in_compromise_window --argument-names path
    set -l mtime (aur_file_mtime $path)
    string match -qr $AUR_WINDOW_LOG_RE -- $mtime
end

function aur_file_has_hook_pattern --argument-names file
    while read -l line
        if string match -qir $AUR_HOOK_PATTERN -- $line
            return 0
        end
    end <$file
    return 1
end

# Expand configured AUR helper cache roots (paru/yay/pikaur/trizen/aura/aurman/pacaur + pamac + makepkg/ABS).
function aur_read_config_assignment --argument-names file key
    if not test -f "$file"
        return 1
    end
    while read -l line
        set line (string trim -- $line)
        test -n "$line"; or continue
        string match -qr '^#' -- $line; and continue
        if string match -qr "^$key\s*=" -- $line
            string replace -r "^$key\s*=" '' -- $line | string trim
            return 0
        end
    end <$file
    return 1
end

function aur_pamac_config_paths
    echo /etc/pamac.conf
    echo "$HOME/.config/pamac/config"
end

# Fish does not glob-expand wildcards held in variables; expand path patterns explicitly.
function aur_expand_path_glob --argument-names pattern
    set -l parent (dirname -- $pattern)
    set -l tail (basename -- $pattern)
    if not string match -q '*\*' -- $tail
        test -e $pattern; and echo $pattern
        return
    end
    set -l prefix (string replace -r '\*+$' '' -- $tail)
    for entry in $parent/$prefix*
        test -e $entry; and echo $entry
    end
end

# Pamac build-dir globs: AUR_PAMAC_BUILD_GLOBS override, else parse BuildDirectory + defaults.
function aur_pamac_build_glob_patterns
    if set -q AUR_PAMAC_BUILD_GLOBS
        echo $AUR_PAMAC_BUILD_GLOBS
        return
    end
    set -l patterns '/tmp/pamac/aur-*' '/var/tmp/pamac-build-*'
    for cfg in (aur_pamac_config_paths)
        set -l build_dir (aur_read_config_assignment $cfg BuildDirectory 2>/dev/null)
        test -n "$build_dir"; or continue
        set build_dir (string trim -- $build_dir)
        if not string match -qr '^/' -- $build_dir
            set build_dir "$HOME/$build_dir"
        end
        set -l glob "$build_dir/pamac-build-*"
        contains -- $glob $patterns; or set -a patterns $glob
    end
    for pattern in $patterns
        echo $pattern
    end
end

function aur_default_helper_cache_roots_list
    if set -q AUR_HELPER_CACHE_ROOTS
        for root in $AUR_HELPER_CACHE_ROOTS
            echo $root
        end
        return
    end
    set -l roots \
        "$HOME/.cache/paru/clone" \
        "$HOME/.cache/yay" \
        "$HOME/.cache/yay/clone" \
        "$HOME/.cache/pikaur" \
        "$HOME/.cache/trizen" \
        "$HOME/.cache/aura" \
        "$HOME/.cache/aurman" \
        "$HOME/.cache/pacaur"
    if set -q AUR_MAKEPKG_BUILD_DIRS
        set -a roots $AUR_MAKEPKG_BUILD_DIRS
    else
        set -a roots "$HOME/abs" "$HOME/builds" "$HOME/aur"
    end
    for root in $roots
        echo $root
    end
end

function aur_helper_hardening_config_paths
    echo "$HOME/.config/paru/paru.conf"
    echo "$HOME/.config/yay/config.json"
    echo /etc/pamac.conf
    echo "$HOME/.config/pamac/config"
    echo "$HOME/.config/trizen/trizen.conf"
    echo "$HOME/.config/aura/config.json"
    echo "$HOME/.config/aurman/aurman.conf"
end

function aur_gnu_date_available
    date -d 2026-01-01 +%s >/dev/null 2>&1
end

function aur_aur_helper_cache_roots
    for root in (aur_default_helper_cache_roots_list)
        test -d $root; and echo $root
    end
    for pattern in (aur_pamac_build_glob_patterns)
        for root in (aur_expand_path_glob $pattern)
            test -d $root; and echo $root
        end
    end
end

# Per-package build dirs under all configured AUR helper caches.
function aur_aur_helper_pkg_cache_dirs --argument-names pkg
    for root in (aur_default_helper_cache_roots_list)
        set -l dir "$root/$pkg"
        test -d $dir; and echo $dir
    end
    for pattern in (aur_pamac_build_glob_patterns)
        for root in (aur_expand_path_glob $pattern)
            set -l dir "$root/$pkg"
            test -d $dir; and echo $dir
        end
    end
end

# Startup notes for cross-distro / permission issues (run.fish calls before scan steps).
function aur_preflight_environment
    if not command -q pacman
        aur_log "[WARN] pacman not found — installed-package checks unavailable (Arch/pacman host required)"
        aur_log "       Timeline/log scans still work when pacman.log paths are readable"
    end

    set -l log_dir (aur_pacman_log_dir)
    if not aur_pacman_logs_accessible
        aur_log "[WARN] pacman logs under $log_dir/pacman.log* are not readable — timeline/window scans may exit 3"
        aur_log "       Try: sudo fish $AUR_RESPONSE_DIR/run.fish"
        aur_log "       Chroot/container: set AUR_PACMAN_LOG_DIR in ~/.config/aur-response/config.fish"
    end

    set -l local_dir (aur_pacman_local_dir)
    if not test -r $local_dir
        aur_log "[WARN] pacman local db ($local_dir) not readable — install-date checks may be incomplete"
        aur_log "       Override: set AUR_PACMAN_LOCAL_DIR in ~/.config/aur-response/config.fish"
    end

    set -l cache_roots (aur_aur_helper_cache_roots)
    if test (count $cache_roots) -eq 0
        aur_log "[INFO] No AUR helper build caches found on disk"
        if command -q pamac
            aur_log "       pamac GUI installs are still checked via pacman; history/cache hook scans may be limited"
        else
            aur_log "       Package, timeline, and pacman.log checks still apply"
        end
    end

    if not aur_gnu_date_available
        aur_log "[WARN] GNU date -d unavailable — install-date windows fall back to English pacman -Qi text"
    end
end

# Read one field from pacman local db desc (locale-independent; %INSTALLDATE% is Unix epoch).
function aur_pkg_local_field --argument-names pkg field
    set -l desc_roots (aur_pacman_local_dir)
    for desc in $desc_roots/$pkg-*/desc
        test -f $desc; or continue
        set -l in_field false
        while read -l line
            if test "$line" = "%$field%"
                set in_field true
                continue
            end
            if test "$in_field" = true
                if string match -qr '^%' -- $line
                    break
                end
                echo (string trim -- $line)
                return 0
            end
        end <$desc
    end
    return 1
end

# Inclusive day bounds for YYYY-MM-DD windows using local timezone (matches pacman INSTALLDATE).
function aur_epoch_day_bounds --argument-names start_ymd end_ymd
    set -l start (date -d "$start_ymd 00:00:00" +%s 2>/dev/null)
    set -l end (date -d "$end_ymd 23:59:59" +%s 2>/dev/null)
    if test -z "$start"; or test -z "$end"
        return 1
    end
    echo $start
    echo $end
end

function aur_epoch_in_ymd_window --argument-names epoch start_ymd end_ymd
    if test -z "$epoch"
        return 1
    end
    set -l bounds (aur_epoch_day_bounds $start_ymd $end_ymd)
    if test (count $bounds) -lt 2
        return 1
    end
    test $epoch -ge $bounds[1] -a $epoch -le $bounds[2]
end

function aur_epoch_in_atomic_arch_window --argument-names epoch
    aur_epoch_in_ymd_window $epoch 2026-06-09 2026-06-14
end

function aur_epoch_in_chaos_rat_window --argument-names epoch
    aur_epoch_in_ymd_window $epoch 2025-07-16 2025-07-18
end

function aur_epoch_in_shai_hulud_window --argument-names epoch
    aur_epoch_in_ymd_window $epoch 2026-05-16 2026-05-17
end

function aur_epoch_in_xeactor_window --argument-names epoch
    aur_epoch_in_ymd_window $epoch 2018-06-07 2018-07-10
end

function aur_pkg_install_epoch --argument-names pkg
    set -l mock_epoch (aur_test_pkg_info_field $pkg 4)
    if test $status -eq 0; and test -n "$mock_epoch"
        echo $mock_epoch
        return 0
    end
    # When test pkg info is mocked, do not read the live pacman local db for that package.
    if set -q AUR_TEST_PKG_INFO
        set -l row (aur_grep -m1 -F "$pkg|" $AUR_TEST_PKG_INFO 2>/dev/null)
        if test -n "$row"
            return 1
        end
    end
    aur_pkg_local_field $pkg INSTALLDATE
end

function aur_pkg_install_date --argument-names pkg
    set -l mock (aur_test_pkg_info_field $pkg 2)
    if test $status -eq 0
        echo $mock
        return 0
    end
    set -l epoch (aur_pkg_install_epoch $pkg 2>/dev/null)
    if test -n "$epoch"
        set -l formatted (date -d @$epoch '+%a %e %b %Y %H:%M:%S' 2>/dev/null)
        if test -n "$formatted"
            echo $formatted
            return 0
        end
    end
    if not command -q pacman
        echo unknown
        return 1
    end
    set -l info (env LC_ALL=C LC_TIME=C pacman -Qi $pkg 2>/dev/null)
    if test $status -ne 0
        echo unknown
        return 1
    end
    string match -r 'Install Date\s*:\s*(.*)' $info | tail -1
end

function aur_pkg_install_reason --argument-names pkg
    set -l mock (aur_test_pkg_info_field $pkg 3)
    if test $status -eq 0
        echo $mock
        return 0
    end
    if not command -q pacman
        echo unknown
        return 1
    end
    set -l info (env LC_ALL=C LC_TIME=C pacman -Qi $pkg 2>/dev/null)
    if test $status -ne 0
        echo unknown
        return 1
    end
    string match -r 'Install Reason\s*:\s*(.*)' $info | tail -1
end

function aur_filter_pkg_lines
    while read -l line
        set line (string trim -- $line)
        if test -n "$line"; and string match -qr $AUR_PKG_PATTERN -- $line
            echo $line
        end
    end
end

# Strip HTML tags from scraped list sources (fish-native; no sed dependency).
function aur_strip_html_tags
    while read -l line
        string replace -a -r '<[^>]*>' '' -- $line
    end
end

# Strip HTML tags from Arch Security paste before validating package names.
function aur_parse_pkg_names
    string join \n -- $argv \
        | aur_strip_html_tags \
        | aur_filter_pkg_lines \
        | sort -u
end

# Arch aur-general [SECURITY] posts list packages inline ("- pkg - pkg") on one line after HTML strip.
function aur_parse_chaos_rat_arch_advisory --argument-names file
    aur_strip_html_tags <$file \
        | string replace -a -r ',' '\n' \
        | string replace -a -r '\s-\s' '\n' \
        | string replace -a -r '\s+and\s+' '\n' \
        | aur_filter_pkg_lines \
        | sort -u
end

# CSCS advisory ships a bash array; extract package names between INFECTED_PKGS=( and ).
function aur_parse_cscs_script --argument-names file
    set -l in_block false
    while read -l line
        if string match -qr '^INFECTED_PKGS=\(' -- $line
            set in_block true
            continue
        end
        if test $in_block = false
            continue
        end
        if string match -qr '^\)' -- $line
            break
        end
        set line (string trim -- $line)
        if test -n "$line"; and string match -qr $AUR_PKG_PATTERN -- $line
            echo $line
        end
    end <$file | sort -u
end

function aur_fetch_source --argument-names url
    set -l tmp (mktemp)
    aur_curl -fsSL --max-time 30 "$url" -o $tmp
    if test $status -ne 0
        rm -f $tmp
        return 1
    end
    echo $tmp
end

# Returns "tmpfile|sha256" so callers can log source integrity without re-reading.
function aur_fetch_source_with_sha --argument-names url
    set -l tmp (aur_fetch_source $url)
    if test $status -ne 0
        return 1
    end
    set -l sha (aur_sha256 $tmp)
    echo "$tmp|$sha"
end

function aur_list_staleness_days --argument-names path
    if not test -f $path
        echo -1
        return
    end
    set -l mtime (stat -c %Y $path 2>/dev/null)
    set -l now (date +%s)
    # Floor to whole days so warnings/tests stay stable across sub-second mtime skew.
    math "floor(($now - $mtime) / 86400)"
end

# Optional list_file: defaults to the Atomic Arch list path (back-compat for callers).
function aur_warn_local_list_stale --argument-names list_file
    if test -z "$list_file"
        set list_file (aur_atomic_arch_list_file_path)
    end
    set -l age (aur_list_staleness_days $list_file)
    if test $age -lt 0
        return
    end
    if test $age -gt $AUR_LIST_MAX_AGE_DAYS
        aur_log "WARN: bundled list is $age days old (>$AUR_LIST_MAX_AGE_DAYS) — run without --local for fresh data"
    end
end

# Compare freshly fetched list to the previous copy (comm -13 = only in new, -23 = only in old).
function aur_list_delta --argument-names old_file
    if not test -f $old_file
        return 0
    end
    set -l new_pkgs $argv[2..-1]
    set -l old_sorted (mktemp)
    set -l new_sorted (mktemp)
    sort -u $old_file >$old_sorted
    printf '%s\n' $new_pkgs | sort -u >$new_sorted
    set -l added (comm -13 $old_sorted $new_sorted)
    set -l removed (comm -23 $old_sorted $new_sorted)
    rm -f $old_sorted $new_sorted
    set -g AUR_SUMMARY_list_added (count $added)
    set -g AUR_SUMMARY_list_removed (count $removed)
    if test (count $added) -gt 0
        aur_log "List delta: "(count $added)" new package(s) since last fetch:"
        for p in $added
            aur_log "  + $p"
        end
    end
    if test (count $removed) -gt 0
        aur_log "List delta: "(count $removed)" removed from list:"
        for p in $removed
            aur_log "  - $p"
        end
    end
    if test (count $added) -eq 0; and test (count $removed) -eq 0
        aur_log "List delta: no changes since last fetch"
    end
end

# Load merged infected list: local file, or fetch Arch + CSCS (+ optional extra URL) and union.
# On fetch failure, falls back to the bundled data/lists/atomic-arch-pkgs.txt if present.
function aur_load_atomic_arch_list --argument-names use_local
    set -l list_file (aur_atomic_arch_list_file_path)
    if test "$use_local" = true
        if not test -f $list_file
            aur_log "ERROR: --local requires $list_file"
            return 1
        end
        aur_warn_local_list_stale $list_file
        aur_log "Using local list at $list_file"
        sort -u $list_file | aur_filter_pkg_lines
        return 0
    end

    set -l all_pkgs
    set -l sources_used
    set -l source_shas

    aur_log "Fetching infected package lists..."

    set -l write_file (aur_atomic_arch_list_write_path)
    # Only refresh .previous when writing the real on-disk cache (not freshness temps).
    if test "$write_file" = "$AUR_ATOMIC_ARCH_LIST_FILE"; and test -f $list_file
        cp $list_file $AUR_ATOMIC_ARCH_LIST_PREVIOUS
    end

    set -l arch_fetch (aur_fetch_source_with_sha $AUR_LIST_URL_ARCH)
    if test $status -eq 0
        set -l arch_parts (string split '|' -- $arch_fetch)
        set -l arch_tmp $arch_parts[1]
        set -l arch_sha $arch_parts[2]
        set -l arch_pkgs (aur_parse_pkg_names (cat $arch_tmp))
        set all_pkgs $all_pkgs $arch_pkgs
        set -a sources_used "Arch ($AUR_LIST_URL_ARCH)"
        set -a source_shas "arch=$arch_sha"
        rm -f $arch_tmp
    else
        aur_log "WARN: failed to fetch $AUR_LIST_URL_ARCH"
    end

    set -l cscs_fetch (aur_fetch_source_with_sha $AUR_LIST_URL_CSCS)
    if test $status -eq 0
        set -l cscs_parts (string split '|' -- $cscs_fetch)
        set -l cscs_tmp $cscs_parts[1]
        set -l cscs_sha $cscs_parts[2]
        set -l cscs_pkgs (aur_parse_cscs_script $cscs_tmp)
        set all_pkgs $all_pkgs $cscs_pkgs
        set -a sources_used "cscs ($AUR_LIST_URL_CSCS)"
        set -a source_shas "cscs=$cscs_sha"
        rm -f $cscs_tmp
    else
        aur_log "WARN: failed to fetch $AUR_LIST_URL_CSCS"
    end

    if test -n "$AUR_LIST_URL_EXTRA"
        set -l extra_fetch (aur_fetch_source_with_sha $AUR_LIST_URL_EXTRA)
        if test $status -eq 0
            set -l extra_parts (string split '|' -- $extra_fetch)
            set -l extra_tmp $extra_parts[1]
            set -l extra_sha $extra_parts[2]
            set -l extra_pkgs (aur_parse_pkg_names (cat $extra_tmp))
            set all_pkgs $all_pkgs $extra_pkgs
            set -a sources_used "extra ($AUR_LIST_URL_EXTRA)"
            set -a source_shas "extra=$extra_sha"
            rm -f $extra_tmp
        else
            aur_log "WARN: failed to fetch $AUR_LIST_URL_EXTRA"
        end
    end

    if test (count $all_pkgs) -eq 0
        if test -f $list_file
            aur_log "All fetches failed; using local list at $list_file"
            if test "$write_file" != "$list_file"
                sort -u $list_file | aur_filter_pkg_lines >$write_file
            end
            sort -u $list_file | aur_filter_pkg_lines
            return 0
        end
        aur_log "ERROR: all remote sources failed and no local list at $list_file"
        return 1
    end

    set all_pkgs (string join \n -- $all_pkgs | sort -u)
    if test "$write_file" = "$AUR_ATOMIC_ARCH_LIST_FILE"
        aur_list_delta $AUR_ATOMIC_ARCH_LIST_PREVIOUS $all_pkgs
    end
    string join \n -- $all_pkgs >$write_file
    aur_log "Merged list saved to $write_file ("(count $all_pkgs)" packages)"
    for src in $sources_used
        aur_log "  - $src"
    end
    for sha_line in $source_shas
        aur_log "  - source SHA256 $sha_line"
        aur_finding_add list_source_sha256 $sha_line
    end
    string join \n -- $all_pkgs
end

# Read validated package names from a list file (one per line).
function aur_read_pkg_list_file --argument-names list_file
    if not test -f "$list_file"
        return 1
    end
    cat $list_file | aur_filter_pkg_lines
end

# Load list via loader_fn; discard logs and return validated names from the list file.
# list_path_fn: zero-arg function that echoes the file to read after a successful load.
function aur_load_and_read_pkg_list --argument-names loader_fn use_local list_path_fn
    $loader_fn $use_local >/dev/null
    if test $status -ne 0
        return 1
    end
    aur_read_pkg_list_file ($list_path_fn)
end

# Load Atomic Arch list; discard loader logs and read names from the effective list file.
function aur_load_and_read_atomic_arch_list --argument-names use_local
    aur_load_atomic_arch_list $use_local >/dev/null
    if test $status -ne 0
        return 1
    end
    if test "$use_local" = true
        aur_read_pkg_list_file (aur_atomic_arch_list_file_path)
        return $status
    end
    set -l write_file (aur_atomic_arch_list_write_path)
    if test -s $write_file
        aur_read_pkg_list_file $write_file
        return $status
    end
    aur_read_pkg_list_file (aur_atomic_arch_list_file_path)
end

function aur_load_and_read_chaos_rat_list --argument-names use_local
    aur_load_and_read_pkg_list aur_load_chaos_rat_list $use_local aur_chaos_rat_list_file_path
end

function aur_load_and_read_shai_hulud_list --argument-names use_local
    aur_load_and_read_pkg_list aur_load_shai_hulud_list $use_local aur_shai_hulud_list_file_path
end

function aur_load_and_read_xeactor_list --argument-names use_local
    aur_load_and_read_pkg_list aur_load_xeactor_list $use_local aur_xeactor_list_file_path
end

# Fetch Chaos RAT source content; returns "path|sha256" (fixture path or temp download).
function aur_chaos_rat_fetch --argument-names url test_file
    if test -n "$test_file"; and test -f "$test_file"
        set -l sha (aur_sha256 $test_file)
        echo "$test_file|$sha"
        return 0
    end
    aur_fetch_source_with_sha $url
end

function aur_chaos_rat_parse --argument-names parse_mode file
    switch $parse_mode
        case html
            aur_parse_chaos_rat_arch_advisory $file
        case text
            cat $file | aur_filter_pkg_lines
        case '*'
            return 1
    end
end

function aur_chaos_rat_cleanup_fetch --argument-names test_file fetched_path
    if test -n "$test_file"; and test "$fetched_path" = "$test_file"
        return 0
    end
    rm -f $fetched_path
end

# Load Chaos RAT package list: local bundled file, or fetch Arch advisory + community list (+ optional extra) and union.
function aur_load_chaos_rat_list --argument-names use_local
    set -l list_file (aur_chaos_rat_list_file_path)
    set -l write_file (aur_chaos_rat_list_write_path)
    if test "$use_local" = true
        if not test -f $list_file
            aur_log "ERROR: --local requires $list_file"
            return 1
        end
        aur_warn_local_list_stale $list_file
        aur_log "Using local Chaos RAT list at $list_file"
        set -l bundled_sha (aur_sha256 $list_file)
        aur_log "  - bundled list SHA256 chaos-bundled=$bundled_sha"
        aur_finding_add list_source_sha256 "chaos-bundled=$bundled_sha"
        sort -u $list_file | aur_filter_pkg_lines
        return 0
    end

    set -l all_pkgs
    set -l sources_used
    set -l source_shas

    aur_log "Fetching Chaos RAT package lists..."

    if test -f $write_file
        cp $write_file $AUR_CHAOS_RAT_LIST_PREVIOUS
    else if test -f $list_file
        cp $list_file $AUR_CHAOS_RAT_LIST_PREVIOUS
    end

    set -l arch_test ""
    set -q AUR_TEST_CHAOS_RAT_ARCH_FILE; and set arch_test $AUR_TEST_CHAOS_RAT_ARCH_FILE
    set -l arch_fetch (aur_chaos_rat_fetch $AUR_CHAOS_RAT_URL_ARCH $arch_test)
    if test $status -eq 0
        set -l arch_parts (string split '|' -- $arch_fetch)
        set -l arch_tmp $arch_parts[1]
        set -l arch_sha $arch_parts[2]
        set -l arch_pkgs (aur_chaos_rat_parse html $arch_tmp)
        if test (count $arch_pkgs) -gt 0
            set all_pkgs $all_pkgs $arch_pkgs
            set -a sources_used "Arch aur-general advisory ($AUR_CHAOS_RAT_URL_ARCH)"
            set -a source_shas "chaos-arch-ml=$arch_sha"
        end
        aur_chaos_rat_cleanup_fetch $arch_test $arch_tmp
    else
        aur_log "WARN: failed to fetch $AUR_CHAOS_RAT_URL_ARCH"
    end

    set -l community_url $AUR_CHAOS_RAT_URL_COMMUNITY
    set -l community_test ""
    set -q AUR_TEST_CHAOS_RAT_COMMUNITY_FILE; and set community_test $AUR_TEST_CHAOS_RAT_COMMUNITY_FILE
    set -l community_fetch (aur_chaos_rat_fetch $community_url $community_test)
    if test $status -eq 0
        set -l community_parts (string split '|' -- $community_fetch)
        set -l community_tmp $community_parts[1]
        set -l community_sha $community_parts[2]
        set -l community_pkgs (aur_chaos_rat_parse text $community_tmp)
        if test (count $community_pkgs) -gt 0
            set all_pkgs $all_pkgs $community_pkgs
            set -a sources_used "community ($community_url)"
            set -a source_shas "chaos-community=$community_sha"
        end
        aur_chaos_rat_cleanup_fetch $community_test $community_tmp
    else
        aur_log "WARN: failed to fetch $community_url"
    end

    if test -n "$AUR_CHAOS_RAT_URL_EXTRA"
        set -l extra_test ""
        set -q AUR_TEST_CHAOS_RAT_EXTRA_FILE; and set extra_test $AUR_TEST_CHAOS_RAT_EXTRA_FILE
        set -l extra_fetch (aur_chaos_rat_fetch $AUR_CHAOS_RAT_URL_EXTRA $extra_test)
        if test $status -eq 0
            set -l extra_parts (string split '|' -- $extra_fetch)
            set -l extra_tmp $extra_parts[1]
            set -l extra_sha $extra_parts[2]
            set -l extra_pkgs (aur_chaos_rat_parse text $extra_tmp)
            if test (count $extra_pkgs) -gt 0
                set all_pkgs $all_pkgs $extra_pkgs
                set -a sources_used "extra ($AUR_CHAOS_RAT_URL_EXTRA)"
                set -a source_shas "chaos-extra=$extra_sha"
            end
            aur_chaos_rat_cleanup_fetch $extra_test $extra_tmp
        else
            aur_log "WARN: failed to fetch $AUR_CHAOS_RAT_URL_EXTRA"
        end
    end

    if test (count $all_pkgs) -eq 0
        if test -f $list_file
            aur_log "All fetches failed; using bundled list at $list_file"
            sort -u $list_file | aur_filter_pkg_lines
            return 0
        end
        aur_log "ERROR: all Chaos RAT sources failed and no local list at $list_file"
        return 1
    end

    set all_pkgs (string join \n -- $all_pkgs | sort -u)
    aur_list_delta $AUR_CHAOS_RAT_LIST_PREVIOUS $all_pkgs
    string join \n -- $all_pkgs >$write_file
    set -l merged_sha (aur_sha256 $write_file)
    aur_log "Merged Chaos RAT list saved to $write_file ("(count $all_pkgs)" packages)"
    aur_log "  - merged list SHA256 chaos-merged=$merged_sha"
    aur_finding_add list_source_sha256 "chaos-merged=$merged_sha"
    for src in $sources_used
        aur_log "  - $src"
    end
    for sha_line in $source_shas
        aur_log "  - source SHA256 $sha_line"
        aur_finding_add list_source_sha256 $sha_line
    end
    string join \n -- $all_pkgs
end

# Shared loader for single-URL campaign lists (Shai-Hulud, xeactor).
# fetch_spec: "" = live URL; "fail" = force failure; "file|/path" = fixture.
function aur_load_single_url_pkg_list --argument-names use_local list_file write_file url label sha_key finding_cat fetch_spec
    if test "$use_local" = true -o -z "$url"
        if not test -f $list_file
            aur_log "ERROR: --local requires $list_file"
            return 1
        end
        aur_warn_local_list_stale $list_file
        aur_log "Using local $label list at $list_file"
        sort -u $list_file | aur_filter_pkg_lines
        return 0
    end

    aur_log "Fetching $label package list..."
    set -l fetch
    set -l fetch_status 1
    switch $fetch_spec
        case fail
            set fetch_status 1
        case 'file|*'
            set -l fixture (string replace -r '^file\|' '' -- $fetch_spec)
            if test -f "$fixture"
                set -l sha (aur_sha256 $fixture)
                set fetch "$fixture|$sha"
                set fetch_status 0
            end
        case live ''
            set fetch (aur_fetch_source_with_sha $url)
            set fetch_status $status
        case '*'
            set fetch (aur_fetch_source_with_sha $url)
            set fetch_status $status
    end
    if test $fetch_status -ne 0
        if test -f $list_file
            aur_log "Fetch failed; using bundled list at $list_file"
            sort -u $list_file | aur_filter_pkg_lines
            return 0
        end
        aur_log "ERROR: failed to fetch $url and no local list at $list_file"
        return 1
    end

    set -l parts (string split '|' -- $fetch)
    set -l tmp $parts[1]
    set -l sha $parts[2]
    set -l pkgs (cat $tmp | aur_filter_pkg_lines | sort -u)
    # Only delete temp downloads, not fixture paths.
    if not string match -q 'file|*' -- $fetch_spec
        rm -f $tmp
    end
    if test (count $pkgs) -eq 0
        aur_log "ERROR: parsed 0 $label packages from $url"
        return 1
    end
    string join \n -- $pkgs >$write_file
    aur_log "$label list saved to $write_file ("(count $pkgs)" packages)"
    aur_log "  - source SHA256 $sha_key=$sha"
    aur_finding_add $finding_cat "$sha_key=$sha"
    echo $pkgs
end

# Load Mini Shai-Hulud package list: bundled file, or optional AUR_SHAI_HULUD_URL fetch.
function aur_load_shai_hulud_list --argument-names use_local
    # Empty URL means bundled-only; coerce before argv packing (Fish drops empty args).
    if test "$use_local" != true; and test -z "$AUR_SHAI_HULUD_URL"
        set use_local true
    end
    set -l fetch_spec live
    if set -q AUR_TEST_SHAI_HULUD_FETCH_FAIL; and test "$AUR_TEST_SHAI_HULUD_FETCH_FAIL" = 1
        set fetch_spec fail
    else if set -q AUR_TEST_SHAI_HULUD_FETCH_FILE; and test -f "$AUR_TEST_SHAI_HULUD_FETCH_FILE"
        set fetch_spec "file|$AUR_TEST_SHAI_HULUD_FETCH_FILE"
    end
    set -l url $AUR_SHAI_HULUD_URL
    test -n "$url"; or set url __local_only__
    aur_load_single_url_pkg_list $use_local \
        (aur_shai_hulud_list_file_path) (aur_shai_hulud_list_write_path) \
        $url Shai-Hulud shai-hulud shai_hulud_list_sha256 $fetch_spec
end

# Load 2018 xeactor package list: bundled file, or optional AUR_XEACTOR_URL fetch.
function aur_load_xeactor_list --argument-names use_local
    if test "$use_local" != true; and test -z "$AUR_XEACTOR_URL"
        set use_local true
    end
    set -l fetch_spec live
    if set -q AUR_TEST_XEACTOR_FETCH_FAIL; and test "$AUR_TEST_XEACTOR_FETCH_FAIL" = 1
        set fetch_spec fail
    else if set -q AUR_TEST_XEACTOR_FETCH_FILE; and test -f "$AUR_TEST_XEACTOR_FETCH_FILE"
        set fetch_spec "file|$AUR_TEST_XEACTOR_FETCH_FILE"
    end
    set -l url $AUR_XEACTOR_URL
    test -n "$url"; or set url __local_only__
    aur_load_single_url_pkg_list $use_local \
        (aur_xeactor_list_file_path) (aur_xeactor_list_write_path) \
        $url xeactor xeactor xeactor_list_sha256 $fetch_spec
end

function aur_file_mtime --argument-names path
    stat -c '%y' $path 2>/dev/null | string split ' ' | head -1
end

function aur_sha256_file --argument-names path
    string upper (aur_sha256 $path)
end

function aur_malware_sha256_matches --argument-names path
    set -l hash (aur_sha256_file $path)
    test -n "$hash"; or return 1
    for known in $AUR_MALWARE_SHA256S
        if test $hash = $known
            return 0
        end
    end
    return 1
end

# Key-name heuristic only — never reads or logs secret values from env files.
function aur_env_has_secrets --argument-names path
    if not test -f $path
        return 1
    end
    while read -l line
        if string match -qir '^(export\s+)?[A-Z0-9_]*(TOKEN|SECRET|PASSWORD|API_KEY|APIKEY|PRIVATE_KEY|CREDENTIAL)[A-Z0-9_]*\s*=' -- $line
            return 0
        end
    end <$path
    return 1
end
