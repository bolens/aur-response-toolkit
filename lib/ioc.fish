# Malware IOC detection and persistence surfaces.
# Targets the "deps" infostealer ELF, optional eBPF rootkit maps, and exfil domains.

# AUR maintainer-email obfuscation (printf … | base64 -d) — not campaign malware.
function aur_similar_heuristics_line_is_noise --argument-names line
    string match -qir $AUR_SIMILAR_HEURISTICS_NOISE_PATTERN -- $line
end

function aur_file_has_similar_heuristics --argument-names file
    while read -l line
        aur_similar_heuristics_line_is_noise $line; and continue
        if string match -qir $AUR_SIMILAR_HEURISTICS_PATTERN -- $line
            return 0
        end
    end <$file
    return 1
end

# Matching lines for reporting (noise lines excluded).
function aur_file_similar_heuristics_lines --argument-names file
    while read -l line
        aur_similar_heuristics_line_is_noise $line; and continue
        if string match -qir $AUR_SIMILAR_HEURISTICS_PATTERN -- $line
            echo $line
        end
    end <$file
end

# Installed foreign packages not present in a campaign list file.
function aur_foreign_installed_not_on_list --argument-names list_file
    if not test -f "$list_file"
        return 1
    end
    set -l installed_sorted (mktemp)
    set -l list_sorted (mktemp)
    set -l diff (mktemp)
    aur_installed_foreign_packages | sort >$installed_sorted
    sort -u $list_file | aur_filter_pkg_lines >$list_sorted
    comm -23 $installed_sorted $list_sorted >$diff
    cat $diff
    set -l n (wc -l < $diff | string trim)
    rm -f $installed_sorted $list_sorted $diff
    test $n -gt 0
end

# PKGBUILD / install / hook paths under pacman local + AUR helper caches for one package.
function aur_pkg_similar_heuristics_files --argument-names pkg
    set -l hits
    for f in (aur_pacman_local_dir)/$pkg-*/install
        test -f $f; or continue
        if aur_file_has_similar_heuristics $f
            set -a hits $f
        end
    end
    for cache in (aur_aur_helper_pkg_cache_dirs $pkg)
        for f in $cache/PKGBUILD $cache/*.install $cache/*.hook
            test -f $f; or continue
            if aur_file_has_similar_heuristics $f
                contains -- $f $hits; or set -a hits $f
            end
        end
    end
    for hit in $hits
        echo $hit
    end
    test (count $hits) -gt 0
end

# Find campaign ELF payloads by SHA256 (deps name and embedded bun/npm artifacts).
# --quick narrows search paths and skips the 30-day mtime filter for speed.
function aur_find_deps_elf
    set -l quick false
    test $AUR_OPT_quick = true; and set quick true

    set -l search_paths
    if test $quick = true
        set search_paths (aur_aur_helper_cache_roots)
        set -a search_paths $HOME/.cache $HOME/.local /var/lib/pacman /var/tmp /var/lib
        set -a search_paths $AUR_BUN_CACHE_DIRS
    else
        set search_paths $AUR_DEPS_SEARCH_PATHS
        set -a search_paths $AUR_BUN_CACHE_DIRS
    end

    set -l seen

    for base in $search_paths
        test -e $base; or continue
        if test $quick = false
            for candidate in (aur_find $base -mtime -30 -name deps -perm -111 -size +1M 2>/dev/null)
                contains -- $candidate $seen; and continue
                if aur_malware_sha256_matches $candidate
                    echo $candidate
                    set -a seen $candidate
                end
            end
        else
            for candidate in (aur_find $base -name deps -perm -111 -size +1M 2>/dev/null)
                contains -- $candidate $seen; and continue
                if aur_malware_sha256_matches $candidate
                    echo $candidate
                    set -a seen $candidate
                end
            end
        end
    end

    # js-digest wave may embed ELF under package dirs with other names — hash-match inside caches.
    set -l pkg_cache_roots $AUR_BUN_CACHE_DIRS $HOME/.cache/npm $HOME/.npm/_cacache
    for cache_root in $pkg_cache_roots
        test -d $cache_root; or continue
        set -l depth 8
        test $quick = true; and set depth 6
        for pkg_dir in (aur_find $cache_root -maxdepth $depth -type d \( -name js-digest -o -name atomic-lockfile -o -name lockfile-js \) 2>/dev/null)
            for candidate in (aur_find $pkg_dir -type f -size +100k 2>/dev/null)
                contains -- $candidate $seen; and continue
                if aur_malware_sha256_matches $candidate
                    echo $candidate
                    set -a seen $candidate
                end
            end
        end
    end
end

# npm cache ls / global node_modules / cache directory (lenucksi aur_check-v2 pattern; see data/docs/atomic-arch.md).
function aur_scan_npm_cache_hits
    set -l hits
    for pkg in $AUR_MALICIOUS_NPM $AUR_SHAI_HULUD_MALICIOUS_NPM
        if command -q npm
            for line in (npm cache ls 2>/dev/null | aur_grep -F $pkg)
                test -n "$line"; or continue
                set -a hits "npm_cache_ls:$line"
            end

            set -l global_mod (npm root -g 2>/dev/null)/$pkg
            if test -d $global_mod
                set -a hits $global_mod
            end
        end

        set -l npm_cache_dir
        if set -q AUR_TEST_NPM_CACHE_DIR
            set npm_cache_dir $AUR_TEST_NPM_CACHE_DIR
        else if command -q npm
            set npm_cache_dir (npm config get cache 2>/dev/null | string trim)
        end
        if test -n "$npm_cache_dir"; and test -d "$npm_cache_dir"
            for hit in (aur_find "$npm_cache_dir" -maxdepth 6 -type d -name $pkg 2>/dev/null)
                set -a hits $hit
            end
        end
    end

    for hit in $hits
        echo $hit
    end
    return 0
end

# bun pm cache ls and ~/.bun/install/cache directory scan.
function aur_scan_bun_cache_hits
    set -l hits
    set -l cache_dirs $AUR_BUN_CACHE_DIRS

    if command -q bun
        set -l bun_pm (bun pm cache 2>/dev/null | string trim)
        test -n "$bun_pm"; and set -a cache_dirs $bun_pm

        for pkg in $AUR_MALICIOUS_NPM $AUR_SHAI_HULUD_MALICIOUS_NPM
            for line in (bun pm cache ls 2>/dev/null | aur_grep -F $pkg)
                test -n "$line"; or continue
                set -a hits "bun_cache_ls:$line"
            end
        end
    end

    for pkg in $AUR_MALICIOUS_NPM $AUR_SHAI_HULUD_MALICIOUS_NPM
        for cache_dir in $cache_dirs
            test -d $cache_dir; or continue
            set -l depth 6
            test $AUR_OPT_quick = true; and set depth 4
            for hit in (aur_find $cache_dir -maxdepth $depth -type d -name $pkg 2>/dev/null)
                set -a hits $hit
            end
            for pkg_dir in (aur_find $cache_dir -maxdepth $depth -type d -name $pkg 2>/dev/null)
                for candidate in (aur_find $pkg_dir -type f -size +100k 2>/dev/null)
                    if aur_malware_sha256_matches $candidate
                        set -a hits $candidate
                    end
                end
            end
        end
    end

    for hit in $hits
        echo $hit
    end
    return 0
end

# Optional eBPF rootkit from the campaign hides processes/files via these BPF map names.
function aur_ebpf_rootkit_maps
    for map in hidden_pids hidden_names hidden_inodes
        test -e /sys/fs/bpf/$map; and echo /sys/fs/bpf/$map
    end
end

# Exclude this toolkit's own pgrep/grep/rg/ps invocations from runtime process hits.
function aur_runtime_proc_is_toolkit_noise --argument-names line
    string match -qir 'pgrep|/grep |/rg |(^|[\s/])rg\s|ripgrep|ps -eo |aur_check_runtime|scan-malware|aur-response|atomic-arch-response' -- $line
end

# pgrep compatibility shim: prefer pgrep -af; fall back to ps -eo + aur_grep.
function aur_pgrep_af --argument-names pattern
    if command -q pgrep
        command pgrep -af $pattern 2>/dev/null
        return $status
    end
    command ps -eo pid=,args= 2>/dev/null | aur_grep -i -- $pattern
end

# ss compatibility shim: prefer ss -H -tun; fall back to netstat or lsof.
function aur_ss_tun_lines
    if command -q ss
        command ss -H -tun 2>/dev/null
        return $status
    end
    if command -q netstat
        command netstat -tun 2>/dev/null
        return $status
    end
    if command -q lsof
        command lsof -i -n -P 2>/dev/null
        return $status
    end
    return 1
end

# Live indicators: malicious npm process names, deps binary, C2 domains, cron persistence.
function aur_check_runtime_iocs
    set -l hits

    for pattern in atomic-lockfile js-digest lockfile-js
        for proc in (aur_pgrep_af $pattern)
            aur_runtime_proc_is_toolkit_noise $proc; and continue
            set -a hits "process:$proc"
        end
    end
    for proc in (aur_pgrep_af '/deps')
        aur_runtime_proc_is_toolkit_noise $proc; and continue
        if string match -qir '/deps$|/deps ' -- $proc
            set -a hits "process:$proc"
        end
    end

    for domain in $AUR_IOC_DOMAINS
        # Active connections only — passive DNS/cache hits are out of scope here.
        for conn in (aur_ss_tun_lines | aur_grep -i $domain)
            set -a hits "network:$conn"
        end
    end

    for cron_path in /etc/crontab /var/spool/cron (aur_find /etc/cron.d /etc/cron.daily /etc/cron.hourly -type f 2>/dev/null)
        test -f $cron_path; or continue
        if aur_grep -qir $AUR_PERSISTENCE_PATTERN $cron_path 2>/dev/null
            set -a hits "cron:$cron_path"
        end
    end
    if test -f $HOME/.config/crontab
        if aur_grep -qir $AUR_PERSISTENCE_PATTERN $HOME/.config/crontab 2>/dev/null
            set -a hits "cron:$HOME/.config/crontab"
        end
    end

    for hit in $hits
        echo $hit
    end
    test (count $hits) -gt 0
end

# Dormant persistence: ld.so.preload hijack, systemd units, shell rc hooks, autostart entries.
function aur_check_extra_persistence
    set -l hits

    if test -f /etc/ld.so.preload; and test -s /etc/ld.so.preload
        if aur_grep -qir $AUR_PERSISTENCE_PATTERN /etc/ld.so.preload 2>/dev/null
            set -a hits "ld_preload:/etc/ld.so.preload"
        end
    end

    for svc in /etc/systemd/system/*.service $HOME/.config/systemd/user/*.service
        test -f $svc; or continue
        while read -l line
            if string match -qir "ExecStart=$AUR_PERSISTENCE_EXEC_RE" -- $line
                set -a hits "systemd:$svc"
                break
            end
        end <$svc
    end

    for rc in $HOME/.bashrc $HOME/.bash_profile $HOME/.profile $HOME/.zshrc $HOME/.config/fish/config.fish
        test -f $rc; or continue
        if aur_file_has_hook_pattern $rc
            set -a hits "shell_rc:$rc"
        end
    end

    for desktop in $HOME/.config/autostart/*.desktop
        test -f $desktop; or continue
        while read -l line
            if string match -qir "^Exec=$AUR_PERSISTENCE_EXEC_RE" -- $line
                set -a hits "autostart:$desktop"
                break
            end
        end <$desktop
    end

    for hit in $hits
        echo $hit
    end
    test (count $hits) -gt 0
end

# Mini Shai-Hulud gh-token-monitor persistence (see data/docs/shai-hulud.md).
function aur_check_shai_hulud_persistence
    set -l hits

    for path in \
            "$HOME/.config/systemd/user/gh-token-monitor.service" \
            "$HOME/.local/bin/gh-token-monitor.sh" \
            "$HOME/.config/gh-token-monitor"
        test -e $path; and set -a hits "shai_hulud:$path"
    end

    if command -q systemctl
        if systemctl --user is-active gh-token-monitor.service 2>/dev/null | string match -q active
            set -a hits "shai_hulud:systemd:gh-token-monitor.service active"
        end
    end

    for hit in $hits
        echo $hit
    end
    test (count $hits) -gt 0
end

# Scan AUR helper caches (paru/yay/pikaur/pamac) for malicious hooks. --pkg NAME: per-package triage; else full cache walk.
function aur_scan_aur_cache_hooks
    set -l pkg ""
    set -l maxdepth 3
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --pkg
                test $i -lt (count $argv); and set pkg $argv[(math $i + 1)]
                set i (math $i + 2)
                continue
            case --maxdepth
                test $i -lt (count $argv); and set maxdepth $argv[(math $i + 1)]
                set i (math $i + 2)
                continue
        end
        set i (math $i + 1)
    end

    set -l hits
    if test -n "$pkg"
        for cache in (aur_aur_helper_pkg_cache_dirs $pkg)
            for f in $cache/PKGBUILD $cache/*.install $cache/*.hook
                test -f $f; or continue
                if aur_file_has_hook_pattern $f
                    contains -- $f $hits; or set -a hits $f
                end
            end
        end
    else
        for cache in (aur_aur_helper_cache_roots)
            for f in (aur_find $cache -maxdepth $maxdepth \( -name PKGBUILD -o -name '*.install' -o -name '*.hook' \) 2>/dev/null)
                if aur_file_has_hook_pattern $f
                    contains -- $f $hits; or set -a hits $f
                end
            end
        end
    end

    for hit in $hits
        echo $hit
    end
    test (count $hits) -gt 0
end

# Classify an unknown window package: installed state, install date, cache/install hooks.
# Returns issue lines on stdout; exit 0 when any finding is critical (malicious hooks or window install).
function aur_triage_unknown_pkg --argument-names pkg
    set -l issues
    set -l critical false

    if pacman -Qi $pkg >/dev/null 2>&1
        set -a issues "still installed"
        if aur_install_in_window_or_all_time $pkg
            set -a issues "installed during window"
            set critical true
        end
        set -l install_script (aur_pacman_local_dir)/$pkg-*/install
        for f in $install_script
            test -f $f; or continue
            if aur_file_has_hook_pattern $f
                set -a issues "malicious install script: $f"
                set critical true
            end
        end
    else
        set -a issues "not currently installed"
    end

    for f in (aur_scan_aur_cache_hooks --pkg $pkg)
        set -a issues "malicious hook in cache: $f"
        set critical true
    end

    for issue in $issues
        echo $issue
    end
    test $critical = true
end

# Consolidated persistence check used by audit-stolen-credentials (subset of scan-malware-artifacts).
function aur_log_persistence_findings --argument-names heading
    set -l heading_text "$heading"
    test -n "$heading_text"; and aur_log $heading_text
    set -l deps (aur_find_deps_elf)
    set -l maps (aur_ebpf_rootkit_maps)
    set -l runtime (aur_check_runtime_iocs)
    set -l extra (aur_check_extra_persistence)
    set -l critical false
    for path in $maps
        aur_record_finding critical artifacts $path
        set critical true
    end
    for path in $deps
        aur_record_finding critical artifacts $path "campaign ELF at $path"
        set critical true
    end
    for hit in $runtime
        aur_record_finding critical runtime_iocs $hit "runtime IOC: $hit" runtime_iocs
        set critical true
    end
    for hit in $extra
        aur_record_finding critical artifacts $hit "persistence: $hit"
        set critical true
    end
    if test $critical = false
        aur_log "  [OK]       No eBPF maps, campaign ELF, runtime IOCs, or extra persistence"
    end
    if test $critical = true
        aur_mark_compromised
        return 1
    end
    return 0
end
