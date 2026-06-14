# Malware IOC detection and persistence surfaces.
# Targets the "deps" infostealer ELF, optional eBPF rootkit maps, and exfil domains.

# Find the deps credential-stealer binary by SHA256 (known campaign artifact).
# --quick narrows search paths and skips the 30-day mtime filter for speed.
function aur_find_deps_elf
    set -l quick false
    test $AUR_OPT_quick = true; and set quick true

    set -l search_paths
    if test $quick = true
        set search_paths $HOME/.cache/paru/clone $HOME/.cache/yay $HOME/.cache $HOME/.local /var/lib/pacman /var/tmp /var/lib
    else
        set search_paths $AUR_DEPS_SEARCH_PATHS
    end

    for base in $search_paths
        test -e $base; or continue
        if test $quick = false
            # -mtime -30 and -size +1M reduce noise from unrelated small executables named deps.
            for candidate in (find $base -mtime -30 -name deps -perm -111 -size +1M 2>/dev/null)
                if test (aur_sha256_file $candidate) = $AUR_MALWARE_SHA256_DEPS
                    echo $candidate
                end
            end
        else
            for candidate in (find $base -name deps -perm -111 -size +1M 2>/dev/null)
                if test (aur_sha256_file $candidate) = $AUR_MALWARE_SHA256_DEPS
                    echo $candidate
                end
            end
        end
    end
end

# Optional eBPF rootkit from the campaign hides processes/files via these BPF map names.
function aur_ebpf_rootkit_maps
    for map in hidden_pids hidden_names hidden_inodes
        test -e /sys/fs/bpf/$map; and echo /sys/fs/bpf/$map
    end
end

# Exclude this toolkit's own pgrep/grep invocations from runtime process hits.
function aur_runtime_proc_is_toolkit_noise --argument-names line
    string match -qir 'pgrep|/grep |aur_check_runtime|scan-malware|atomic-arch-response' -- $line
end

# Live indicators: malicious npm process names, deps binary, C2 domains, cron persistence.
function aur_check_runtime_iocs
    set -l hits

    if command -q pgrep
        for pattern in atomic-lockfile js-digest lockfile-js
            for proc in (pgrep -af $pattern 2>/dev/null)
                aur_runtime_proc_is_toolkit_noise $proc; and continue
                set -a hits "process:$proc"
            end
        end
        for proc in (pgrep -af '/deps' 2>/dev/null)
            aur_runtime_proc_is_toolkit_noise $proc; and continue
            if string match -qir '/deps$|/deps ' -- $proc
                set -a hits "process:$proc"
            end
        end
    end

    for domain in $AUR_IOC_DOMAINS
        if command -q ss
            # Active connections only — passive DNS/cache hits are out of scope here.
            for conn in (ss -H -tun 2>/dev/null | aur_grep -i $domain)
                set -a hits "network:$conn"
            end
        end
    end

    for cron_path in /etc/crontab /var/spool/cron (find /etc/cron.d /etc/cron.daily /etc/cron.hourly -type f 2>/dev/null)
        test -f $cron_path; or continue
        if aur_grep -qir 'deps|/var/lib/|atomic-lockfile|js-digest' $cron_path 2>/dev/null
            set -a hits "cron:$cron_path"
        end
    end
    if test -f $HOME/.config/crontab
        if aur_grep -qir 'deps|atomic-lockfile|js-digest' $HOME/.config/crontab 2>/dev/null
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
        if aur_grep -qir 'deps|/var/lib/' /etc/ld.so.preload 2>/dev/null
            set -a hits "ld_preload:/etc/ld.so.preload"
        end
    end

    for svc in /etc/systemd/system/*.service $HOME/.config/systemd/user/*.service
        test -f $svc; or continue
        while read -l line
            if string match -qir 'ExecStart=.*(/var/lib/|deps|atomic-lockfile|js-digest)' -- $line
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
            if string match -qir '^Exec=.*(/var/lib/|deps|atomic-lockfile|js-digest)' -- $line
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

# Classify an unknown window package: installed state, install date, cache/install hooks.
# Returns issue lines on stdout; exit 0 when any finding is critical (malicious hooks or window install).
function aur_triage_unknown_pkg --argument-names pkg
    set -l issues
    set -l critical false

    if pacman -Qi $pkg >/dev/null 2>&1
        set -a issues "still installed"
        if aur_install_in_compromise_window $pkg
            set -a issues "installed during window"
            set critical true
        end
        set -l install_script "/var/lib/pacman/local/$pkg-*/install"
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

    for cache in $HOME/.cache/paru/clone/$pkg $HOME/.cache/yay/$pkg
        test -d $cache; or continue
        for f in $cache/PKGBUILD $cache/*.install $cache/*.hook
            test -f $f; or continue
            if aur_file_has_hook_pattern $f
                set -a issues "malicious hook in cache: $f"
                set critical true
            end
        end
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
        aur_log "  [CRITICAL] $path"
        aur_finding_add artifacts $path
        set critical true
    end
    for path in $deps
        aur_log "  [CRITICAL] deps ELF at $path"
        aur_finding_add artifacts $path
        set critical true
    end
    for hit in $runtime
        aur_log "  [CRITICAL] runtime IOC: $hit"
        aur_finding_add runtime_iocs $hit
        aur_summary_inc runtime_iocs 1
        set critical true
    end
    for hit in $extra
        aur_log "  [CRITICAL] persistence: $hit"
        aur_finding_add artifacts $hit
        set critical true
    end
    if test $critical = false
        aur_log "  [OK]       No eBPF maps, deps ELF, runtime IOCs, or extra persistence"
    end
    if test $critical = true
        aur_mark_compromised
        return 1
    end
    return 0
end
