# Shared helpers for AUR malware response scripts.
# Scripts set AUR_RESPONSE_DIR before sourcing; lib/ can also derive it from its own path.

if not set -q AUR_RESPONSE_DIR
    set -g AUR_RESPONSE_DIR (dirname (dirname (status filename)))
end

# --- Version ---
set -g AUR_VERSION_FILE "$AUR_RESPONSE_DIR/VERSION"
if test -f $AUR_VERSION_FILE
    set -g AUR_VERSION (string trim (cat $AUR_VERSION_FILE))
else
    set -g AUR_VERSION dev
end

# --- Exit codes (stable contract for CI/automation; see README) ---
set -g AUR_EXIT_CLEAN 0
set -g AUR_EXIT_COMPROMISE 1
set -g AUR_EXIT_WARN 2
set -g AUR_EXIT_INSUFFICIENT 3
set -g AUR_EXIT_INVALID 4

# --- Paths (defaults; override in ~/.config/aur-response/config.fish) ---
set -g AUR_SCRIPTS_DIR "$AUR_RESPONSE_DIR/scripts"
function aur_script_path --argument-names relpath
    echo "$AUR_SCRIPTS_DIR/$relpath"
end
set -g AUR_DATA_DIR "$AUR_RESPONSE_DIR/data"
set -g AUR_DATA_LISTS_DIR "$AUR_DATA_DIR/lists"
set -g AUR_DATA_DOCS_DIR "$AUR_DATA_DIR/docs"
function aur_data_path --argument-names relpath
    echo "$AUR_DATA_DIR/$relpath"
end
set -g AUR_ATOMIC_ARCH_LIST_FILE "$AUR_DATA_LISTS_DIR/atomic-arch-pkgs.txt"
set -g AUR_ATOMIC_ARCH_LIST_PREVIOUS "$AUR_DATA_LISTS_DIR/atomic-arch-pkgs.previous.txt"
set -g AUR_CHAOS_RAT_LIST_FILE "$AUR_DATA_LISTS_DIR/chaos-rat-pkgs.txt"
set -g AUR_CHAOS_RAT_LIST_PREVIOUS "$AUR_DATA_LISTS_DIR/chaos-rat-pkgs.previous.txt"
# Official Arch advisory (aur-general) + community extended list (merged on fetch).
# Provenance: data/docs/chaos-rat.md
set -g AUR_CHAOS_RAT_URL_ARCH "https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/message/7EZTJXLIAQLARQNTMEW2HBWZYE626IFJ/"
set -g AUR_CHAOS_RAT_URL_COMMUNITY "https://raw.githubusercontent.com/lenucksi/aur-malware-check/master/chaos_rat_packages.txt"
if not set -q AUR_CHAOS_RAT_URL_EXTRA
    set -g AUR_CHAOS_RAT_URL_EXTRA ""
end
if not set -q AUR_ENABLE_CHAOS_RAT
    set -g AUR_ENABLE_CHAOS_RAT 0
end
set -g AUR_SHAI_HULUD_LIST_FILE "$AUR_DATA_LISTS_DIR/shai-hulud-pkgs.txt"
if not set -q AUR_SHAI_HULUD_URL
    set -g AUR_SHAI_HULUD_URL ""
end
if not set -q AUR_ENABLE_SHAI_HULUD
    set -g AUR_ENABLE_SHAI_HULUD 0
end
set -g AUR_XEACTOR_LIST_FILE "$AUR_DATA_LISTS_DIR/xeactor-pkgs.txt"
if not set -q AUR_XEACTOR_URL
    set -g AUR_XEACTOR_URL ""
end
if not set -q AUR_ENABLE_XEACTOR
    set -g AUR_ENABLE_XEACTOR 0
end
set -g AUR_REPORTS_DIR "$AUR_RESPONSE_DIR/reports"
set -g AUR_SUMMARY_FILE "$AUR_RESPONSE_DIR/reports/latest-summary.json"
set -g AUR_FINDINGS_FILE "$AUR_RESPONSE_DIR/reports/.scan-findings.json"
set -g AUR_FINDINGS_LIST_FILE "$AUR_REPORTS_DIR/.scan-findings.list"

# Remote infected-list sources merged on each online fetch (see data/docs/atomic-arch.md).
set -g AUR_LIST_URL_ARCH "https://md.archlinux.org/s/SxbqukK6IA"
set -g AUR_LIST_URL_CSCS "https://cscs.pastes.sh/raw/aurvulntest20260611.sh"

# Arch package naming rules — filters HTML noise and invalid tokens from scraped lists.
set -g AUR_PKG_PATTERN '^[a-z0-9][a-z0-9_.+\-]*[a-z0-9]$'
set -g AUR_COMPROMISE_YEAR 2026
# Compromise window: Jun 9–14 2026 (Atomic Arch campaign active period).
# WINDOW_LOG_RE matches pacman.log timestamps; INSTALL_* matches pacman -Qi "Install Date".
set -g AUR_WINDOW_LOG_RE '2026-06-(09|10|11|12|13|14)'
set -g AUR_WINDOW_INSTALL_DAYS_RE '(0?[9]|1[0-4])'
set -g AUR_WINDOW_INSTALL_MONTH Jun
set -g AUR_WINDOW_LABEL "Jun 9–14, $AUR_COMPROMISE_YEAR"
# Chaos RAT campaign: Jul 16–18 2025 (danikpapas AUR packages; separate from Atomic Arch).
set -g AUR_CHAOS_RAT_YEAR 2025
set -g AUR_CHAOS_RAT_WINDOW_LOG_RE '2025-07-(16|17|18)'
set -g AUR_CHAOS_RAT_WINDOW_INSTALL_DAYS_RE '(1[678])'
set -g AUR_CHAOS_RAT_WINDOW_INSTALL_MONTH Jul
set -g AUR_CHAOS_RAT_WINDOW_LABEL "Jul 16–18, $AUR_CHAOS_RAT_YEAR"
# Mini Shai-Hulud AUR campaign: May 16–17 2026 (crypto-javascript in adopted packages).
set -g AUR_SHAI_HULUD_YEAR 2026
set -g AUR_SHAI_HULUD_WINDOW_LOG_RE '2026-05-(16|17)'
set -g AUR_SHAI_HULUD_WINDOW_INSTALL_DAYS_RE '(1[67])'
set -g AUR_SHAI_HULUD_WINDOW_INSTALL_MONTH May
set -g AUR_SHAI_HULUD_WINDOW_LABEL "May 16–17, $AUR_SHAI_HULUD_YEAR"
# xeactor AUR incident (2018): Jun 7 first malicious acroread commit through Jul 10 staff cleanup.
set -g AUR_XEACTOR_YEAR 2018
set -g AUR_XEACTOR_WINDOW_LOG_RE '2018-(06-(0[7-9]|[12][0-9]|30)|07-(0[1-9]|10))'
set -g AUR_XEACTOR_WINDOW_LABEL "Jun 7–Jul 10, $AUR_XEACTOR_YEAR"
# Malicious npm/bun hooks injected into PKGBUILDs, .install scripts, and shell rc files.
set -g AUR_HOOK_PATTERN 'atomic-lockfile|js-digest|lockfile-js|nextfile-js|crypto-javascript|bun install js-digest|npm install atomic-lockfile|npm install lockfile-js|npm install nextfile-js|npm install crypto-javascript'
# Broader supply-chain heuristics for installed foreign packages not on campaign lists.
set -g AUR_SIMILAR_HEURISTICS_PATTERN 'atomic-lockfile|js-digest|lockfile-js|nextfile-js|crypto-javascript|/var/lib/deps|bun (pm )?install|npm (ci|install).*(--ignore-scripts=false|--foreground-scripts)|node -e |eval \(|base64 -d|openssl enc|curl .*\| (bash|sh)|wget .*\| (bash|sh)|atob\(|Buffer\.from\(.*base64'
set -g AUR_SIMILAR_HEURISTICS_NOISE_PATTERN '^# (Maintainer|Contributor|Packager):.*base64 -d'
# Persistence IOC grep / Exec= patterns (cron, systemd, autostart, ld.so.preload).
set -g AUR_PERSISTENCE_PATTERN 'deps|/var/lib/|atomic-lockfile|js-digest'
set -g AUR_PERSISTENCE_EXEC_RE '.*(/var/lib/|deps|atomic-lockfile|js-digest)'

# Known SHA256 of campaign ELF payloads — see data/docs/atomic-arch.md (ioctl.fail / lenucksi iocs.txt lineage).
set -g AUR_MALWARE_SHA256_DEPS 6144D433F8A0316869877B5F834C801251BBB936E5F1577C5680878C7443C98B
set -g AUR_MALWARE_SHA256_JS_DIGEST 7883BDA1FF15425F2DBE622C45A3AE105DDFA6175009BBF0B0CAD9BF5C79B316
set -g AUR_MALWARE_SHA256_CRYPTO 47893D9BADC38C54B71321263CE8178C1ABB10396E0AADF9793E61EC8829E204
set -g AUR_MALWARE_SHA256S $AUR_MALWARE_SHA256_DEPS $AUR_MALWARE_SHA256_JS_DIGEST $AUR_MALWARE_SHA256_CRYPTO
set -g AUR_MALICIOUS_NPM atomic-lockfile js-digest lockfile-js nextfile-js
set -g AUR_SHAI_HULUD_MALICIOUS_NPM crypto-javascript
set -g AUR_BUN_CACHE_DIRS $HOME/.bun/install/cache
# Exfil endpoints referenced by the campaign (history scan + live ss checks).
set -g AUR_IOC_DOMAINS temp.sh olrh4mibs62l6kkuvvjyc5lrercqg5tz543r4lsw3o6mh5qb7g7sneid.onion
set -g AUR_HISTORY_SECRET_PATTERN 'password|token|ghp_|github_pat|api[_-]?key|secret|BEGIN (RSA|OPENSSH)|CLOUDFLARE|AWS_|docker login|npm login|hash-password|changepassword'
if not set -q AUR_DEV_ROOT
    set -g AUR_DEV_ROOT "$HOME/dev"
end
set -g AUR_DEPS_SEARCH_PATHS $HOME/.cache $HOME/.local $HOME/.npm $HOME/node_modules /var/lib/pacman /var/tmp /var/lib
# Cross-distro overrides (optional; see config.fish.example):
#   AUR_PACMAN_LOG_DIR      — default /var/log (chroot/container)
#   AUR_PACMAN_LOCAL_DIR    — default /var/lib/pacman/local
#   AUR_HELPER_CACHE_ROOTS  — replaces default helper + makepkg build dirs
#   AUR_MAKEPKG_BUILD_DIRS  — extra makepkg/ABS dirs (default: ~/abs ~/builds ~/aur)
#   AUR_PAMAC_BUILD_GLOBS   — replaces pamac BuildDirectory auto-detection
# Regex helper names for shell-history risky-install detection (override in config.fish).
if not set -q AUR_HISTORY_HELPERS
    set -g AUR_HISTORY_HELPERS 'paru|yay|pamac|pikaur|trizen|aura|aurman|pacaur|makepkg'
end
set -g AUR_LIST_MAX_AGE_DAYS 7
if not set -q AUR_LIST_URL_EXTRA
    set -g AUR_LIST_URL_EXTRA ""
end

if not set -q AUR_STATE_FILE
    set -g AUR_STATE_FILE "$AUR_RESPONSE_DIR/reports/.scan-state"
end

# User config (optional overrides in ~/.config/aur-response/config.fish)
set -l _aur_user_config "$HOME/.config/aur-response/config.fish"
if set -q XDG_CONFIG_HOME
    set _aur_user_config "$XDG_CONFIG_HOME/aur-response/config.fish"
end
test -f $_aur_user_config; and source $_aur_user_config

# Grep compatibility shim: scripts use common grep flags; translate to rg when available.
# Unknown flags fall through to grep so callers never need to branch on which tool exists.
# All project code must call aur_grep — never grep/rg directly (see README Requirements).
function aur_grep
    if not command -q rg
        command grep $argv
        return $status
    end

    set -l rg_flags
    set -l args $argv
    set -l skip_next false

    while test (count $args) -gt 0
        set -l arg $args[1]
        if test "$skip_next" = true
            set skip_next false
            set args $args[2..-1]
            continue
        end

        switch $arg
            case --
                set args $args[2..-1]
                break
            case -F --fixed-strings
                set -a rg_flags -F
                set args $args[2..-1]
            case -x --line-regexp
                set -a rg_flags -x
                set args $args[2..-1]
            case -q --quiet --silent
                set -a rg_flags -q
                set args $args[2..-1]
            case -o --only-matching
                set -a rg_flags -o
                set args $args[2..-1]
            case -E --extended-regexp
                set args $args[2..-1]
            case -m1
                set -a rg_flags -m 1
                set args $args[2..-1]
            case '-m*'
                set -a rg_flags -m (string sub -s 3 -- $arg)
                set args $args[2..-1]
            case -m
                set -a rg_flags -m $args[2]
                set skip_next true
                set args $args[2..-1]
            case '-*'
                # Flag we do not translate — delegate to grep unchanged.
                command grep $argv
                return $status
            case '*'
                break
        end
    end

    command rg $rg_flags -- $args
end

# Find compatibility shim: prefer fd when flags are translatable; otherwise GNU find.
# Callers use find-style flags; unknown options fall through to find unchanged.
function aur_find
    if not command -q fd
        command find $argv
        return $status
    end

    set -l args $argv
    set -l fd_flags -H -I
    set -l paths
    set -l use_find false
    set -l skip_next false

    while test (count $args) -gt 0
        set -l arg $args[1]

        if test "$skip_next" = true
            set skip_next false
            set args $args[2..-1]
            continue
        end

        switch $arg
            case '(' ')'
                set use_find true
            case -o
                set use_find true
            case -mtime -perm -size
                set use_find true
            case -maxdepth
                if test (count $args) -lt 2
                    set use_find true
                else
                    set -a fd_flags --max-depth $args[2]
                    set skip_next true
                end
            case -type
                if test (count $args) -lt 2
                    set use_find true
                else
                    switch $args[2]
                        case f
                            set -a fd_flags -t f
                        case d
                            set -a fd_flags -t d
                        case '*'
                            set use_find true
                    end
                    set skip_next true
                end
            case -name
                if test (count $args) -lt 2
                    set use_find true
                else
                    set -a fd_flags -g $args[2]
                    set skip_next true
                end
            case --
                set args $args[2..-1]
                break
            case '-*'
                set use_find true
            case '*'
                set -a paths $arg
        end

        set args $args[2..-1]
    end

    if test $use_find = true
        command find $argv
        return $status
    end

    if test (count $paths) -eq 0
        set paths .
    end

    set -l seen
    for p in $paths
        set -l hits
        if string match -q '.' -- $p
            set hits (command fd -H -I $fd_flags . 2>/dev/null)
        else if string match -qr '^/' -- $p
            set hits (command fd -H -I $fd_flags . -- $p 2>/dev/null)
        else
            set hits (command fd -H -I $fd_flags -- $p 2>/dev/null)
        end
        for line in $hits
            set line (string trim -r -c / -- $line)
            contains -- $line $seen; and continue
            set -a seen $line
            echo $line
        end
    end
end

# Curl compatibility shim: prefer curlie when available; fall back to curl.
# file:// URLs always use curl — curlie rejects them; relative paths are absolutized.
function aur_curl
    set -l args $argv
    for i in (seq (count $args))
        if string match -qr '^file://' -- $args[$i]
            set -l path (string replace -r '^file://' '' -- $args[$i])
            while string match -q '//'* -- $path
                set path (string sub -s 2 -- $path)
            end
            if test -n "$path" -a "$path" != /
                if not string match -qr '^/' -- $path
                    set path (aur_realpath $path)
                end
            end
            set args[$i] "file://$path"
            command curl $args
            return $status
        end
    end
    # curlie treats non-TTY stdin as POST body (-d@-); empty stdin avoids hangs.
    if command -q curlie
        set -l curlie_args $args
        if not contains -- -d $curlie_args; and not contains -- --data $curlie_args; and not contains -- --data-binary $curlie_args
            if not contains -- -X $curlie_args; and not contains -- --request $curlie_args
                set -a curlie_args -X GET
            end
        end
        command curlie $curlie_args </dev/null
        return $status
    end
    command curl $args
end

# realpath compatibility shim: prefer realpath; fall back to readlink -f.
function aur_realpath --argument-names path
    if command -q realpath
        command realpath -s -- $path
        return $status
    end
    if command -q readlink
        command readlink -f -- $path 2>/dev/null
        return $status
    end
    return 1
end

# SHA256 compatibility shim: prefer sha256sum; fall back to openssl dgst.
function aur_sha256 --argument-names path
    if command -q sha256sum
        command sha256sum $path 2>/dev/null | string split ' ' | head -1
        return $status
    end
    if command -q openssl
        command openssl dgst -sha256 $path 2>/dev/null | string replace -r '^.*= ' ''
        return $status
    end
    return 1
end

# Hostname shim: inetutils hostname optional; uname -n from coreutils is enough on minimal Arch.
function aur_hostname
    if command -q hostname
        hostname
        return 0
    end
    if command -q uname
        uname -n
        return 0
    end
    echo unknown
end

# Effective infected-list path for reads. Tests set AUR_TEST_LIST_FILE at any time
# (same-shell unit tests or exported before a child fish sources common.fish).
# Remote fetches still write merged output to $AUR_ATOMIC_ARCH_LIST_FILE under data/.
function aur_atomic_arch_list_file_path
    if set -q AUR_TEST_LIST_FILE
        echo $AUR_TEST_LIST_FILE
        return
    end
    echo $AUR_ATOMIC_ARCH_LIST_FILE
end

function aur_chaos_rat_list_file_path
    if set -q AUR_TEST_CHAOS_RAT_LIST_FILE
        echo $AUR_TEST_CHAOS_RAT_LIST_FILE
        return
    end
    echo $AUR_CHAOS_RAT_LIST_FILE
end

function aur_shai_hulud_list_file_path
    if set -q AUR_TEST_SHAI_HULUD_LIST_FILE
        echo $AUR_TEST_SHAI_HULUD_LIST_FILE
        return
    end
    echo $AUR_SHAI_HULUD_LIST_FILE
end

function aur_xeactor_list_file_path
    if set -q AUR_TEST_XEACTOR_LIST_FILE
        echo $AUR_TEST_XEACTOR_LIST_FILE
        return
    end
    echo $AUR_XEACTOR_LIST_FILE
end

function aur_chaos_rat_enabled
    if test $AUR_OPT_chaos_rat = true
        return 0
    end
    if test "$AUR_ENABLE_CHAOS_RAT" = 1
        return 0
    end
    return 1
end

function aur_shai_hulud_enabled
    if test $AUR_OPT_shai_hulud = true
        return 0
    end
    if test "$AUR_ENABLE_SHAI_HULUD" = 1
        return 0
    end
    return 1
end

function aur_xeactor_enabled
    if test $AUR_OPT_xeactor = true
        return 0
    end
    if test "$AUR_ENABLE_XEACTOR" = 1
        return 0
    end
    return 1
end

function aur_version
    echo $AUR_VERSION
end

# Summary counters — also persisted to $AUR_STATE_FILE so child scripts can update totals.
set -g AUR_SUMMARY_atomic_arch_installed 0
set -g AUR_SUMMARY_atomic_arch_high_risk 0
set -g AUR_SUMMARY_atomic_arch_timeline_hits 0
set -g AUR_SUMMARY_atomic_arch_timeline_repeat_updates 0
set -g AUR_SUMMARY_window_aur_pkgs 0
set -g AUR_SUMMARY_artifact_critical 0
set -g AUR_SUMMARY_credential_exposed 0
set -g AUR_SUMMARY_hardening_warn 0
set -g AUR_SUMMARY_list_added 0
set -g AUR_SUMMARY_list_removed 0
set -g AUR_SUMMARY_insufficient_data 0
set -g AUR_SUMMARY_runtime_iocs 0
set -g AUR_SUMMARY_chaos_rat_installed 0
set -g AUR_SUMMARY_chaos_rat_high_risk 0
set -g AUR_SUMMARY_chaos_rat_timeline_hits 0
set -g AUR_SUMMARY_shai_hulud_installed 0
set -g AUR_SUMMARY_shai_hulud_high_risk 0
set -g AUR_SUMMARY_shai_hulud_timeline_hits 0
set -g AUR_SUMMARY_xeactor_installed 0
set -g AUR_SUMMARY_xeactor_high_risk 0
set -g AUR_SUMMARY_xeactor_timeline_hits 0

set -g AUR_OPT_local false
set -g AUR_OPT_report false
set -g AUR_OPT_audit false
set -g AUR_OPT_quiet false
set -g AUR_OPT_quick false
set -g AUR_OPT_if_compromised false
set -g AUR_OPT_fail_on all
set -g AUR_OPT_prune_days 0
set -g AUR_OPT_all_time false
set -g AUR_OPT_chaos_rat false
set -g AUR_OPT_shai_hulud false
set -g AUR_OPT_xeactor false

# Parse shared CLI flags into globals. Resets all AUR_OPT_* on each call so scripts
# can invoke this after their own argv parsing without inheriting stale values.
function aur_parse_common_args
    set -g AUR_OPT_local false
    set -g AUR_OPT_report false
    set -g AUR_OPT_audit false
    set -g AUR_OPT_quiet false
    set -g AUR_OPT_quick false
    set -g AUR_OPT_if_compromised false
    set -g AUR_OPT_fail_on all
    set -g AUR_OPT_prune_days 0
    set -g AUR_OPT_all_time false
    set -g AUR_OPT_chaos_rat false
    set -g AUR_OPT_shai_hulud false
    set -g AUR_OPT_xeactor false
    for arg in $argv
        if string match -qr '^--fail-on=' -- $arg
            set -g AUR_OPT_fail_on (string replace -r '^--fail-on=' '' -- $arg)
            continue
        end
        if string match -qr '^--prune-days=' -- $arg
            set -g AUR_OPT_prune_days (string replace -r '^--prune-days=' '' -- $arg)
            continue
        end
        switch $arg
            case --local
                set -g AUR_OPT_local true
            case --report
                set -g AUR_OPT_report true
            case --audit
                set -g AUR_OPT_audit true
            case --quiet
                set -g AUR_OPT_quiet true
            case --quick
                set -g AUR_OPT_quick true
            case --all-time
                set -g AUR_OPT_all_time true
            case --chaos-rat
                set -g AUR_OPT_chaos_rat true
            case --shai-hulud
                set -g AUR_OPT_shai_hulud true
            case --xeactor
                set -g AUR_OPT_xeactor true
            case --if-compromised
                set -g AUR_OPT_if_compromised true
            case --fail-on
                # value must follow; handled below
            case --fail-on:compromise --fail-on:all --fail-on:none --fail-on:chaos-rat --fail-on:shai-hulud --fail-on:xeactor
                set -g AUR_OPT_fail_on (string replace -r '^--fail-on:' '' -- $arg)
            case --prune-days
                # value must follow; handled below
            case --version
                continue
        end
    end
    # --fail-on VALUE and --prune-days N as two argv tokens
    set -l i 1
    while test $i -le (count $argv)
        if test "$argv[$i]" = --fail-on; and test $i -lt (count $argv)
            set -g AUR_OPT_fail_on $argv[(math $i + 1)]
        end
        if test "$argv[$i]" = --prune-days; and test $i -lt (count $argv)
            set -g AUR_OPT_prune_days $argv[(math $i + 1)]
        end
        set i (math $i + 1)
    end
end

function aur_common_flags_help
    echo "Common flags:"
    echo "  --local            Use bundled atomic-arch-pkgs.txt (no network fetch)"
    echo "  --report           Append output to reports/"
    echo "  --quiet            Suppress stdout (reports/json still written)"
    echo "  --quick            Faster scans (narrower artifact search)"
    echo "  --all-time         Ignore compromise date window (any install / log hit)"
    echo "  --if-compromised   Only fail credential audit when compromise detected"
    echo "  --chaos-rat        Scan for Chaos RAT / cracked-software AUR packages (opt-in threat)"
    echo "  --shai-hulud       Scan for Mini Shai-Hulud AUR packages (opt-in threat)"
    echo "  --xeactor      Scan for 2018 xeactor AUR packages (opt-in threat)"
    echo "  --fail-on MODE     Exit policy: all (default), compromise, chaos-rat, shai-hulud, xeactor, none"
end

# Build argv list from parsed AUR_OPT_* globals plus optional extra flags (e.g. --no-chain).
function aur_build_step_args
    set -l args
    test $AUR_OPT_local = true; and set -a args --local
    test $AUR_OPT_report = true; and set -a args --report
    test $AUR_OPT_quiet = true; and set -a args --quiet
    test $AUR_OPT_quick = true; and set -a args --quick
    test $AUR_OPT_all_time = true; and set -a args --all-time
    test $AUR_OPT_chaos_rat = true; and set -a args --chaos-rat
    test $AUR_OPT_shai_hulud = true; and set -a args --shai-hulud
    test $AUR_OPT_xeactor = true; and set -a args --xeactor
    for flag in $argv
        set -a args $flag
    end
    printf '%s\n' $args
end

# Reject unknown dashed flags early (exit 4). Positional package names are ignored.
function aur_validate_known_flags
    set -l allowed \
        --help -h --version \
        --local --report --quiet --audit \
        --no-chain --json --skip-pkg-check \
        --dry-run --force --all-shells --verify \
        --quick --all-time --if-compromised --recover --chaos-rat --shai-hulud --xeactor \
        --fail-on all compromise chaos-rat shai-hulud xeactor none --prune-days
    for arg in $argv
        if contains -- $arg $allowed
            continue
        end
        if string match -qr '^--fail-on=' -- $arg
            continue
        end
        if string match -qr '^--prune-days=' -- $arg
            continue
        end
        if string match -qr '^-' -- $arg
            echo "Unknown option: $arg (see --help)" >&2
            exit $AUR_EXIT_INVALID
        end
    end
end

function aur_begin_report_if_requested --argument-names label
    if test $AUR_OPT_report = true
        aur_begin_report $label
    end
end

# Reset ephemeral scan state at the start of a full run (each step writes fresh findings).
function aur_state_init
    mkdir -p $AUR_REPORTS_DIR
    rm -f $AUR_STATE_FILE $AUR_FINDINGS_FILE $AUR_FINDINGS_LIST_FILE
end

# Simple key=value file shared across subprocesses (each scan step is a separate fish).
function aur_state_set --argument-names key value
    mkdir -p $AUR_REPORTS_DIR
    set -l tmp (mktemp)
    if test -f $AUR_STATE_FILE
        while read -l line
            set -l k (string split -m1 '=' -- $line)[1]
            if test "$k" != "$key"
                echo $line >>$tmp
            end
        end <$AUR_STATE_FILE
    end
    echo "$key=$value" >>$tmp
    mv $tmp $AUR_STATE_FILE
end

function aur_state_get --argument-names key
    if not test -f $AUR_STATE_FILE
        echo ""
        return
    end
    while read -l line
        set -l k (string split -m1 '=' -- $line)[1]
        if test "$k" = "$key"
            echo (string split -m1 '=' -- $line)[2]
            return
        end
    end <$AUR_STATE_FILE
    echo ""
end

# Mirror a counter in memory and on disk so run.fish can reload after child scripts exit.
function aur_summary_set --argument-names key value
    set -g AUR_SUMMARY_$key $value
    aur_state_set $key $value
end

function aur_state_load_summary
    for key in atomic_arch_installed atomic_arch_high_risk atomic_arch_timeline_hits atomic_arch_timeline_repeat_updates window_aur_pkgs artifact_critical credential_exposed hardening_warn list_added list_removed insufficient_data runtime_iocs chaos_rat_installed chaos_rat_high_risk chaos_rat_timeline_hits shai_hulud_installed shai_hulud_high_risk shai_hulud_timeline_hits xeactor_installed xeactor_high_risk xeactor_timeline_hits compromised
        set -l val (aur_state_get $key)
        test -z "$val"; and set val 0
        set -g AUR_SUMMARY_$key $val
    end
end

# Sticky flag: any step that sees compromise indicators sets this for audit/exit logic.
function aur_mark_compromised
    aur_state_set compromised 1
    set -g AUR_SUMMARY_compromised 1
end

function aur_compromise_detected
    test (aur_state_get compromised) = 1
end

function aur_insufficient_data --argument-names reason
    aur_summary_inc insufficient_data 1
    aur_finding_add insufficient_data "$reason"
    aur_log "[INSUFFICIENT] $reason"
end

# Echoes the exit code on stdout (for `tail -1` capture) and returns it as $status.
function aur_finalize_exit --argument-names compromise warn insufficient chaos_rat shai_hulud xeactor
    set -l c 0
    set -l w 0
    set -l i 0
    set -l cr 0
    set -l sh 0
    set -l lg 0
    test "$compromise" = true; and set c 1
    test "$warn" = true; and set w 1
    test "$insufficient" = true; and set i 1
    test "$chaos_rat" = true; and set cr 1
    test "$shai_hulud" = true; and set sh 1
    test "$xeactor" = true; and set lg 1

    # Priority: insufficient > compromise > optional-campaign warn > generic warn > clean. --fail-on can suppress lower severities.
    if test $i -eq 1; and contains -- $AUR_OPT_fail_on all compromise
        echo $AUR_EXIT_INSUFFICIENT
        return $AUR_EXIT_INSUFFICIENT
    end
    if test $c -eq 1; and contains -- $AUR_OPT_fail_on all compromise chaos-rat shai-hulud xeactor
        echo $AUR_EXIT_COMPROMISE
        return $AUR_EXIT_COMPROMISE
    end
    if test $cr -eq 1; and contains -- $AUR_OPT_fail_on all chaos-rat
        echo $AUR_EXIT_WARN
        return $AUR_EXIT_WARN
    end
    if test $sh -eq 1; and contains -- $AUR_OPT_fail_on all shai-hulud
        echo $AUR_EXIT_WARN
        return $AUR_EXIT_WARN
    end
    if test $lg -eq 1; and contains -- $AUR_OPT_fail_on all xeactor
        echo $AUR_EXIT_WARN
        return $AUR_EXIT_WARN
    end
    if test $w -eq 1; and test "$AUR_OPT_fail_on" = all
        echo $AUR_EXIT_WARN
        return $AUR_EXIT_WARN
    end
    echo $AUR_EXIT_CLEAN
    return $AUR_EXIT_CLEAN
end

# Writes to stdout unless --quiet; mirrors the same lines into the active report file.
function aur_log
    for line in $argv
        if test $AUR_OPT_quiet != true
            echo $line
        end
        if set -q AUR_REPORT_FILE[1]
            echo $line >>$AUR_REPORT_FILE
        end
    end
end

# One report per run; AUR_REPORT_FILE is global so aur_log appends throughout.
function aur_begin_report --argument-names label
    mkdir -p $AUR_REPORTS_DIR
    if set -q AUR_REPORT_FILE[1]
        return 0
    end
    set -gx AUR_REPORT_FILE "$AUR_REPORTS_DIR/$label"(date +%Y%m%d-%H%M%S)".log"
    aur_log "=== AUR malware response report ==="
    aur_log "Toolkit version: $AUR_VERSION"
    aur_log "Started: "(date '+%Y-%m-%d %H:%M:%S')
    aur_log "Host: "(aur_hostname)
    aur_log ""
end

function aur_summary_inc --argument-names key amount
    set -l current (aur_state_get $key)
    if test -z "$current"
        set current 0
    end
    aur_summary_set $key (math $current + $amount)
end

# pacman -Qi uses "DD Mon YYYY" — different format from pacman.log ISO timestamps.
function aur_install_date_in_window --argument-names date_line
    if test -z "$date_line"
        return 1
    end
    if not string match -qr ".*$AUR_COMPROMISE_YEAR.*" -- $date_line
        return 1
    end
    if string match -qr ".*\\s$AUR_WINDOW_INSTALL_DAYS_RE\\s+$AUR_WINDOW_INSTALL_MONTH\\s+" -- $date_line
        return 0
    end
    return 1
end

function aur_install_in_compromise_window --argument-names pkg
    set -l epoch (aur_pkg_install_epoch $pkg 2>/dev/null)
    if test -n "$epoch"
        aur_epoch_in_atomic_arch_window $epoch
        return $status
    end
    set -l date_text (aur_pkg_install_date $pkg)
    if test "$date_text" = unknown
        return 1
    end
    aur_install_date_in_window "Install Date    : $date_text"
end

function aur_log_line_in_compromise_window --argument-names line
    test $AUR_OPT_all_time = true; and return 0
    string match -qr $AUR_WINDOW_LOG_RE -- $line
end

function aur_install_in_window_or_all_time --argument-names pkg
    test $AUR_OPT_all_time = true; and return 0
    aur_install_in_compromise_window $pkg
end

# Classify one Atomic Arch list match: HIGH (window or --all-time) vs LOW. Updates AUR_FOUND_* globals.
function aur_classify_atomic_arch_installed_pkg --argument-names pkg
    aur_finding_add atomic_arch_installed $pkg
    set -l install_date (aur_pkg_install_date $pkg)
    set -l install_reason (aur_pkg_install_reason $pkg)
    if aur_install_in_compromise_window $pkg
        set -a AUR_FOUND_IN_WINDOW $pkg
        aur_finding_add atomic_arch_high_risk $pkg
        aur_log "  [HIGH]   $pkg"
        aur_log "           installed: $install_date | reason: $install_reason"
    else if test $AUR_OPT_all_time = true
        set -a AUR_FOUND_IN_WINDOW $pkg
        aur_finding_add atomic_arch_high_risk $pkg
        aur_log "  [HIGH]   $pkg"
        aur_log "           installed: $install_date | reason: $install_reason (--all-time)"
    else
        set -a AUR_FOUND_OUTSIDE_WINDOW $pkg
        aur_log "  [LOW]    $pkg"
        aur_log "           installed: $install_date | reason: $install_reason (outside $AUR_WINDOW_LABEL)"
    end
end

# Classify one installed Chaos RAT package: HIGH (Jul 16–18 2025 or --all-time) vs LOW.
function aur_classify_chaos_rat_pkg --argument-names pkg
    aur_finding_add chaos_rat_installed $pkg
    set -l install_date (aur_pkg_install_date $pkg)
    set -l install_reason (aur_pkg_install_reason $pkg)
    if aur_install_in_chaos_rat_window $pkg
        set -a AUR_CHAOS_RAT_FOUND_IN_WINDOW $pkg
        aur_finding_add chaos_rat_high_risk $pkg
        aur_log "  [HIGH]   $pkg"
        aur_log "           installed: $install_date | reason: $install_reason"
    else if test $AUR_OPT_all_time = true
        set -a AUR_CHAOS_RAT_FOUND_IN_WINDOW $pkg
        aur_finding_add chaos_rat_high_risk $pkg
        aur_log "  [HIGH]   $pkg"
        aur_log "           installed: $install_date | reason: $install_reason (--all-time)"
    else
        set -a AUR_CHAOS_RAT_FOUND_OUTSIDE_WINDOW $pkg
        aur_log "  [LOW]    $pkg"
        aur_log "           installed: $install_date | reason: $install_reason (outside $AUR_CHAOS_RAT_WINDOW_LABEL)"
    end
end

# Classify one installed Mini Shai-Hulud package: HIGH (May 16–17 2026 or --all-time) vs LOW.
function aur_classify_shai_hulud_pkg --argument-names pkg
    aur_finding_add shai_hulud_installed $pkg
    set -l install_date (aur_pkg_install_date $pkg)
    set -l install_reason (aur_pkg_install_reason $pkg)
    if aur_install_in_shai_hulud_window $pkg
        set -a AUR_SHAI_HULUD_FOUND_IN_WINDOW $pkg
        aur_finding_add shai_hulud_high_risk $pkg
        aur_log "  [HIGH]   $pkg"
        aur_log "           installed: $install_date | reason: $install_reason"
    else if test $AUR_OPT_all_time = true
        set -a AUR_SHAI_HULUD_FOUND_IN_WINDOW $pkg
        aur_finding_add shai_hulud_high_risk $pkg
        aur_log "  [HIGH]   $pkg"
        aur_log "           installed: $install_date | reason: $install_reason (--all-time)"
    else
        set -a AUR_SHAI_HULUD_FOUND_OUTSIDE_WINDOW $pkg
        aur_log "  [LOW]    $pkg"
        aur_log "           installed: $install_date | reason: $install_reason (outside $AUR_SHAI_HULUD_WINDOW_LABEL)"
    end
end

function aur_install_date_in_shai_hulud_window --argument-names date_line
    if test -z "$date_line"
        return 1
    end
    if not string match -qr ".*$AUR_SHAI_HULUD_YEAR.*" -- $date_line
        return 1
    end
    if string match -qr ".*\\s$AUR_SHAI_HULUD_WINDOW_INSTALL_DAYS_RE\\s+$AUR_SHAI_HULUD_WINDOW_INSTALL_MONTH\\s+" -- $date_line
        return 0
    end
    return 1
end

function aur_install_in_shai_hulud_window --argument-names pkg
    set -l epoch (aur_pkg_install_epoch $pkg 2>/dev/null)
    if test -n "$epoch"
        aur_epoch_in_shai_hulud_window $epoch
        return $status
    end
    set -l date_text (aur_pkg_install_date $pkg)
    if test "$date_text" = unknown
        return 1
    end
    aur_install_date_in_shai_hulud_window "Install Date    : $date_text"
end

function aur_log_line_in_shai_hulud_window --argument-names line
    test $AUR_OPT_all_time = true; and return 0
    string match -qr $AUR_SHAI_HULUD_WINDOW_LOG_RE -- $line
end

function aur_install_in_shai_hulud_window_or_all_time --argument-names pkg
    test $AUR_OPT_all_time = true; and return 0
    aur_install_in_shai_hulud_window $pkg
end

# Classify one installed 2018 xeactor package: HIGH (Jun 7–Jul 10 2018 or --all-time) vs LOW.
function aur_classify_xeactor_pkg --argument-names pkg
    aur_finding_add xeactor_installed $pkg
    set -l install_date (aur_pkg_install_date $pkg)
    set -l install_reason (aur_pkg_install_reason $pkg)
    if aur_install_in_xeactor_window $pkg
        set -a AUR_XEACTOR_FOUND_IN_WINDOW $pkg
        aur_finding_add xeactor_high_risk $pkg
        aur_log "  [HIGH]   $pkg"
        aur_log "           installed: $install_date | reason: $install_reason"
    else if test $AUR_OPT_all_time = true
        set -a AUR_XEACTOR_FOUND_IN_WINDOW $pkg
        aur_finding_add xeactor_high_risk $pkg
        aur_log "  [HIGH]   $pkg"
        aur_log "           installed: $install_date | reason: $install_reason (--all-time)"
    else
        set -a AUR_XEACTOR_FOUND_OUTSIDE_WINDOW $pkg
        aur_log "  [LOW]    $pkg"
        aur_log "           installed: $install_date | reason: $install_reason (outside $AUR_XEACTOR_WINDOW_LABEL)"
    end
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
    set -l epoch (aur_pkg_install_epoch $pkg 2>/dev/null)
    if test -n "$epoch"
        aur_epoch_in_xeactor_window $epoch
        return $status
    end
    set -l date_text (aur_pkg_install_date $pkg)
    if test "$date_text" = unknown
        return 1
    end
    aur_install_date_in_xeactor_window "Install Date    : $date_text"
end

function aur_log_line_in_xeactor_window --argument-names line
    test $AUR_OPT_all_time = true; and return 0
    string match -qr $AUR_XEACTOR_WINDOW_LOG_RE -- $line
end

function aur_install_in_xeactor_window_or_all_time --argument-names pkg
    test $AUR_OPT_all_time = true; and return 0
    aur_install_in_xeactor_window $pkg
end

function aur_install_date_in_chaos_rat_window --argument-names date_line
    if test -z "$date_line"
        return 1
    end
    if not string match -qr ".*$AUR_CHAOS_RAT_YEAR.*" -- $date_line
        return 1
    end
    if string match -qr ".*\\s$AUR_CHAOS_RAT_WINDOW_INSTALL_DAYS_RE\\s+$AUR_CHAOS_RAT_WINDOW_INSTALL_MONTH\\s+" -- $date_line
        return 0
    end
    return 1
end

function aur_install_in_chaos_rat_window --argument-names pkg
    set -l epoch (aur_pkg_install_epoch $pkg 2>/dev/null)
    if test -n "$epoch"
        aur_epoch_in_chaos_rat_window $epoch
        return $status
    end
    set -l date_text (aur_pkg_install_date $pkg)
    if test "$date_text" = unknown
        return 1
    end
    aur_install_date_in_chaos_rat_window "Install Date    : $date_text"
end

function aur_log_line_in_chaos_rat_window --argument-names line
    test $AUR_OPT_all_time = true; and return 0
    string match -qr $AUR_CHAOS_RAT_WINDOW_LOG_RE -- $line
end

function aur_install_in_chaos_rat_window_or_all_time --argument-names pkg
    test $AUR_OPT_all_time = true; and return 0
    aur_install_in_chaos_rat_window $pkg
end

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

# Collect install/upgrade/reinstall events in the compromise window.
# Output format: "pkgname|full pacman log line" (pipe delimiter survives commas in log lines).
function aur_collect_window_alpm_events --argument-names log_path out_file
    aur_read_pacman_log $log_path | while read -l line
        aur_is_alpm_install_line $line; or continue
        aur_log_line_in_compromise_window $line; or continue
        set -l pkg (aur_extract_alpm_pkg_from_line $line)
        test -n "$pkg"; or continue
        echo "$pkg|$line" >>$out_file
    end
end

function aur_collect_window_alpm_events_all --argument-names out_file
    for log_path in (aur_pacman_log_paths)
        aur_collect_window_alpm_events $log_path $out_file
    end
end

# Attack-window events only — ignores --all-time (repeat updates are window-scoped).
function aur_collect_attack_window_alpm_events_all --argument-names out_file
    set -l saved_all_time $AUR_OPT_all_time
    set -g AUR_OPT_all_time false
    aur_collect_window_alpm_events_all $out_file
    set -g AUR_OPT_all_time $saved_all_time
end

function aur_collect_chaos_rat_window_alpm_events --argument-names log_path out_file
    aur_read_pacman_log $log_path | while read -l line
        aur_is_alpm_install_line $line; or continue
        aur_log_line_in_chaos_rat_window $line; or continue
        set -l pkg (aur_extract_alpm_pkg_from_line $line)
        test -n "$pkg"; or continue
        echo "$pkg|$line" >>$out_file
    end
end

function aur_collect_chaos_rat_window_alpm_events_all --argument-names out_file
    for log_path in (aur_pacman_log_paths)
        aur_collect_chaos_rat_window_alpm_events $log_path $out_file
    end
end

function aur_collect_shai_hulud_window_alpm_events --argument-names log_path out_file
    aur_read_pacman_log $log_path | while read -l line
        aur_is_alpm_install_line $line; or continue
        aur_log_line_in_shai_hulud_window $line; or continue
        set -l pkg (aur_extract_alpm_pkg_from_line $line)
        test -n "$pkg"; or continue
        echo "$pkg|$line" >>$out_file
    end
end

function aur_collect_shai_hulud_window_alpm_events_all --argument-names out_file
    for log_path in (aur_pacman_log_paths)
        aur_collect_shai_hulud_window_alpm_events $log_path $out_file
    end
end

function aur_collect_xeactor_window_alpm_events --argument-names log_path out_file
    aur_read_pacman_log $log_path | while read -l line
        aur_is_alpm_install_line $line; or continue
        aur_log_line_in_xeactor_window $line; or continue
        set -l pkg (aur_extract_alpm_pkg_from_line $line)
        test -n "$pkg"; or continue
        echo "$pkg|$line" >>$out_file
    end
end

function aur_collect_xeactor_window_alpm_events_all --argument-names out_file
    for log_path in (aur_pacman_log_paths)
        aur_collect_xeactor_window_alpm_events $log_path $out_file
    end
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
    pacman -Qmq 2>/dev/null
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
    math "($now - $mtime) / 86400"
end

function aur_warn_local_list_stale
    set -l list_file (aur_atomic_arch_list_file_path)
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
        aur_warn_local_list_stale
        aur_log "Using local list at $list_file"
        sort -u $list_file | aur_filter_pkg_lines
        return 0
    end

    set -l all_pkgs
    set -l sources_used
    set -l source_shas

    aur_log "Fetching infected package lists..."

    if test -f $list_file
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
            sort -u $list_file
            return 0
        end
        aur_log "ERROR: all remote sources failed and no local list at $list_file"
        return 1
    end

    set all_pkgs (string join \n -- $all_pkgs | sort -u)
    aur_list_delta $AUR_ATOMIC_ARCH_LIST_PREVIOUS $all_pkgs
    string join \n -- $all_pkgs >$AUR_ATOMIC_ARCH_LIST_FILE
    aur_log "Merged list saved to $AUR_ATOMIC_ARCH_LIST_FILE ("(count $all_pkgs)" packages)"
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

# Load Atomic Arch list; online fetch logs go to stdout — use quiet form when capturing.
function aur_load_and_read_atomic_arch_list --argument-names use_local
    if test "$use_local" = true
        aur_load_atomic_arch_list true
        return $status
    end
    aur_load_atomic_arch_list false >/dev/null
    if test $status -ne 0
        return 1
    end
    aur_read_pkg_list_file (aur_atomic_arch_list_file_path)
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
    if test "$use_local" = true
        if not test -f $list_file
            aur_log "ERROR: --local requires $list_file"
            return 1
        end
        aur_warn_local_list_stale
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

    if test -f $list_file
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
    string join \n -- $all_pkgs >$list_file
    set -l merged_sha (aur_sha256 $list_file)
    aur_log "Merged Chaos RAT list saved to $list_file ("(count $all_pkgs)" packages)"
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

# Load Mini Shai-Hulud package list: bundled file, or optional AUR_SHAI_HULUD_URL fetch.
function aur_load_shai_hulud_list --argument-names use_local
    set -l list_file (aur_shai_hulud_list_file_path)
    if test "$use_local" = true -o -z "$AUR_SHAI_HULUD_URL"
        if not test -f $list_file
            aur_log "ERROR: --local requires $list_file"
            return 1
        end
        aur_warn_local_list_stale
        aur_log "Using local Shai-Hulud list at $list_file"
        sort -u $list_file | aur_filter_pkg_lines
        return 0
    end

    aur_log "Fetching Shai-Hulud package list..."
    set -l fetch
    if set -q AUR_TEST_SHAI_HULUD_FETCH_FAIL; and test "$AUR_TEST_SHAI_HULUD_FETCH_FAIL" = 1
        set fetch_status 1
    else if set -q AUR_TEST_SHAI_HULUD_FETCH_FILE; and test -f "$AUR_TEST_SHAI_HULUD_FETCH_FILE"
        set -l sha (aur_sha256 $AUR_TEST_SHAI_HULUD_FETCH_FILE)
        set fetch "$AUR_TEST_SHAI_HULUD_FETCH_FILE|$sha"
        set fetch_status 0
    else
        set fetch (aur_fetch_source_with_sha $AUR_SHAI_HULUD_URL)
        set fetch_status $status
    end
    if test $fetch_status -ne 0
        if test -f $list_file
            aur_log "Fetch failed; using bundled list at $list_file"
            sort -u $list_file | aur_filter_pkg_lines
            return 0
        end
        aur_log "ERROR: failed to fetch $AUR_SHAI_HULUD_URL and no local list at $list_file"
        return 1
    end

    set -l parts (string split '|' -- $fetch)
    set -l tmp $parts[1]
    set -l sha $parts[2]
    set -l pkgs (cat $tmp | aur_filter_pkg_lines | sort -u)
    rm -f $tmp
    if test (count $pkgs) -eq 0
        aur_log "ERROR: parsed 0 Shai-Hulud packages from $AUR_SHAI_HULUD_URL"
        return 1
    end
    string join \n -- $pkgs >$list_file
    aur_log "Shai-Hulud list saved to $list_file ("(count $pkgs)" packages)"
    aur_log "  - source SHA256 shai-hulud=$sha"
    aur_finding_add shai_hulud_list_sha256 "shai-hulud=$sha"
    echo $pkgs
end

# Load 2018 xeactor package list: bundled file, or optional AUR_XEACTOR_URL fetch.
function aur_load_xeactor_list --argument-names use_local
    set -l list_file (aur_xeactor_list_file_path)
    if test "$use_local" = true -o -z "$AUR_XEACTOR_URL"
        if not test -f $list_file
            aur_log "ERROR: --local requires $list_file"
            return 1
        end
        aur_warn_local_list_stale
        aur_log "Using local xeactor list at $list_file"
        sort -u $list_file | aur_filter_pkg_lines
        return 0
    end

    aur_log "Fetching xeactor package list..."
    set -l fetch
    if set -q AUR_TEST_XEACTOR_FETCH_FAIL; and test "$AUR_TEST_XEACTOR_FETCH_FAIL" = 1
        set fetch_status 1
    else if set -q AUR_TEST_XEACTOR_FETCH_FILE; and test -f "$AUR_TEST_XEACTOR_FETCH_FILE"
        set -l sha (aur_sha256 $AUR_TEST_XEACTOR_FETCH_FILE)
        set fetch "$AUR_TEST_XEACTOR_FETCH_FILE|$sha"
        set fetch_status 0
    else
        set fetch (aur_fetch_source_with_sha $AUR_XEACTOR_URL)
        set fetch_status $status
    end
    if test $fetch_status -ne 0
        if test -f $list_file
            aur_log "Fetch failed; using bundled list at $list_file"
            sort -u $list_file | aur_filter_pkg_lines
            return 0
        end
        aur_log "ERROR: failed to fetch $AUR_XEACTOR_URL and no local list at $list_file"
        return 1
    end

    set -l parts (string split '|' -- $fetch)
    set -l tmp $parts[1]
    set -l sha $parts[2]
    set -l pkgs (cat $tmp | aur_filter_pkg_lines | sort -u)
    rm -f $tmp
    if test (count $pkgs) -eq 0
        aur_log "ERROR: parsed 0 xeactor packages from $AUR_XEACTOR_URL"
        return 1
    end
    string join \n -- $pkgs >$list_file
    aur_log "xeactor list saved to $list_file ("(count $pkgs)" packages)"
    aur_log "  - source SHA256 xeactor=$sha"
    aur_finding_add xeactor_list_sha256 "xeactor=$sha"
    echo $pkgs
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

# Pull in findings, history, IOC, and report helpers after all base paths/constants exist.
set -g _aur_lib (dirname (status filename))
source $_aur_lib/findings.fish
source $_aur_lib/history.fish
source $_aur_lib/ioc.fish
source $_aur_lib/reports.fish

function aur_print_summary_dashboard --argument-names exit_code
    aur_log ""
    aur_log "=== Scan summary ==="
    aur_log "  Toolkit version:          $AUR_VERSION"
    aur_log "  Atomic Arch installed:    $AUR_SUMMARY_atomic_arch_installed ($AUR_SUMMARY_atomic_arch_high_risk high-risk)"
    aur_log "  Atomic Arch timeline:     $AUR_SUMMARY_atomic_arch_timeline_hits"
    aur_log "  Atomic Arch repeats:      $AUR_SUMMARY_atomic_arch_timeline_repeat_updates"
    aur_log "  AUR pkgs in window:       $AUR_SUMMARY_window_aur_pkgs"
    aur_log "  Malware artifacts:        $AUR_SUMMARY_artifact_critical critical"
    aur_log "  Runtime IOCs:             $AUR_SUMMARY_runtime_iocs"
    aur_log "  Chaos RAT packages:       $AUR_SUMMARY_chaos_rat_installed ($AUR_SUMMARY_chaos_rat_high_risk high-risk)"
    aur_log "  Chaos RAT timeline hits:  $AUR_SUMMARY_chaos_rat_timeline_hits"
    aur_log "  Shai-Hulud packages:      $AUR_SUMMARY_shai_hulud_installed ($AUR_SUMMARY_shai_hulud_high_risk high-risk)"
    aur_log "  Shai-Hulud timeline hits: $AUR_SUMMARY_shai_hulud_timeline_hits"
    aur_log "  xeactor packages:     $AUR_SUMMARY_xeactor_installed ($AUR_SUMMARY_xeactor_high_risk high-risk)"
    aur_log "  xeactor timeline hits: $AUR_SUMMARY_xeactor_timeline_hits"
    aur_log "  Credential exposures:     $AUR_SUMMARY_credential_exposed"
    aur_log "  Hardening warnings:       $AUR_SUMMARY_hardening_warn"
    aur_log "  Insufficient data:        $AUR_SUMMARY_insufficient_data"
    if test $AUR_SUMMARY_list_added -gt 0 -o $AUR_SUMMARY_list_removed -gt 0
        aur_log "  List changes:             +$AUR_SUMMARY_list_added / -$AUR_SUMMARY_list_removed"
    end
    aur_log "  Severity:                 "(aur_compute_severity $exit_code)
    aur_log "  JSON summary:             $AUR_SUMMARY_FILE"
end
