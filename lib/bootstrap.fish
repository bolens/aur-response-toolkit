# Library entry point: paths, constants, FHS redirects, user config, then sibling modules.
# Scripts set AUR_RESPONSE_DIR before sourcing; otherwise derive it from this file's path.

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
# Bundled lists ship with the toolkit; *_LIST_FILE is the writable cache (may equal bundled).
set -g AUR_ATOMIC_ARCH_LIST_BUNDLED "$AUR_DATA_LISTS_DIR/atomic-arch-pkgs.txt"
set -g AUR_ATOMIC_ARCH_LIST_FILE $AUR_ATOMIC_ARCH_LIST_BUNDLED
set -g AUR_ATOMIC_ARCH_LIST_PREVIOUS "$AUR_DATA_LISTS_DIR/atomic-arch-pkgs.previous.txt"
set -g AUR_CHAOS_RAT_LIST_BUNDLED "$AUR_DATA_LISTS_DIR/chaos-rat-pkgs.txt"
set -g AUR_CHAOS_RAT_LIST_FILE $AUR_CHAOS_RAT_LIST_BUNDLED
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
set -g AUR_SHAI_HULUD_LIST_BUNDLED "$AUR_DATA_LISTS_DIR/shai-hulud-pkgs.txt"
set -g AUR_SHAI_HULUD_LIST_FILE $AUR_SHAI_HULUD_LIST_BUNDLED
if not set -q AUR_SHAI_HULUD_URL
    set -g AUR_SHAI_HULUD_URL ""
end
if not set -q AUR_ENABLE_SHAI_HULUD
    set -g AUR_ENABLE_SHAI_HULUD 0
end
set -g AUR_XEACTOR_LIST_BUNDLED "$AUR_DATA_LISTS_DIR/xeactor-pkgs.txt"
set -g AUR_XEACTOR_LIST_FILE $AUR_XEACTOR_LIST_BUNDLED
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

# FHS installs under /usr are read-only; keep reports + online list caches in XDG data home.
set -l _aur_xdg_state "$HOME/.local/share/aur-response"
if set -q XDG_DATA_HOME
    set _aur_xdg_state "$XDG_DATA_HOME/aur-response"
end
if not test -w "$AUR_REPORTS_DIR" 2>/dev/null
    set -g AUR_REPORTS_DIR "$_aur_xdg_state/reports"
    set -g AUR_SUMMARY_FILE "$AUR_REPORTS_DIR/latest-summary.json"
    set -g AUR_FINDINGS_FILE "$AUR_REPORTS_DIR/.scan-findings.json"
    set -g AUR_FINDINGS_LIST_FILE "$AUR_REPORTS_DIR/.scan-findings.list"
end
if not test -w "$AUR_DATA_LISTS_DIR" 2>/dev/null
    set -l _aur_xdg_lists "$_aur_xdg_state/lists"
    mkdir -p "$_aur_xdg_lists" 2>/dev/null
    set -g AUR_ATOMIC_ARCH_LIST_FILE "$_aur_xdg_lists/atomic-arch-pkgs.txt"
    set -g AUR_ATOMIC_ARCH_LIST_PREVIOUS "$_aur_xdg_lists/atomic-arch-pkgs.previous.txt"
    set -g AUR_CHAOS_RAT_LIST_FILE "$_aur_xdg_lists/chaos-rat-pkgs.txt"
    set -g AUR_CHAOS_RAT_LIST_PREVIOUS "$_aur_xdg_lists/chaos-rat-pkgs.previous.txt"
    set -g AUR_SHAI_HULUD_LIST_FILE "$_aur_xdg_lists/shai-hulud-pkgs.txt"
    set -g AUR_XEACTOR_LIST_FILE "$_aur_xdg_lists/xeactor-pkgs.txt"
end

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
set -g AUR_DEPS_SEARCH_PATHS $HOME/.cache $HOME/.local /var/lib/pacman /var/tmp /var/lib
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
    set -g AUR_STATE_FILE "$AUR_REPORTS_DIR/.scan-state"
end

# User config (optional overrides in ~/.config/aur-response/config.fish)
set -l _aur_user_config "$HOME/.config/aur-response/config.fish"
if set -q XDG_CONFIG_HOME
    set _aur_user_config "$XDG_CONFIG_HOME/aur-response/config.fish"
end
test -f $_aur_user_config; and source $_aur_user_config

# Load remaining library modules (entry point is this file — source lib/bootstrap.fish).
set -g _aur_lib (dirname (status filename))
source $_aur_lib/shims.fish
source $_aur_lib/lists.fish
source $_aur_lib/cli.fish
source $_aur_lib/windows.fish
source $_aur_lib/alpm.fish
source $_aur_lib/packages.fish
source $_aur_lib/campaign_runners.fish
source $_aur_lib/findings.fish
source $_aur_lib/history.fish
source $_aur_lib/ioc.fish
source $_aur_lib/reports.fish
