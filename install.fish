#!/usr/bin/env fish

# Install aur-response-toolkit.
#   fish install.fish              User wrappers in ~/.local/bin (points at this clone)
#   fish install.fish --system     FHS copy under /usr/share + /usr/bin (needs root)
#   fish install.fish --prefix /usr/local
#   fish install.fish --prefix /usr --destdir /tmp/stage   Packaging staging root

set -l src (cd (dirname (status filename)); and pwd)
set -l prefix ""
set -l destdir ""
set -l system_mode false

function aur_install_usage
    echo "Usage: install.fish [--user]"
    echo "       install.fish --system [--destdir DIR]"
    echo "       install.fish --prefix PATH [--destdir DIR]"
    echo ""
    echo "  --user (default)  Wrappers in ~/.local/bin pointing at this clone"
    echo "  --system          Same as --prefix /usr (FHS copy + systemd units)"
    echo "  --prefix PATH     Copy toolkit to PATH/share/aur-response-toolkit,"
    echo "                    commands in PATH/bin (typical: /usr or /usr/local)"
    echo "  --destdir DIR     Prepend staging root (for packagers; default: empty)"
    echo ""
    echo "System installs write scan reports to ~/.local/share/aur-response/reports/"
    echo "Optional config: ~/.config/aur-response/config.fish"
end

for i in (seq (count $argv))
    set -l arg $argv[$i]
    switch $arg
        case -h --help
            aur_install_usage
            exit 0
        case --user
            set system_mode false
            set prefix ""
        case --system
            set system_mode true
            set prefix /usr
        case --prefix
            set -l next $argv[(math $i + 1)]
            if test -z "$next"; or string match -qr '^--' -- $next
                echo "install.fish: --prefix requires a path" >&2
                exit 4
            end
            set system_mode true
            set prefix $next
        case '--prefix=*'
            set system_mode true
            set prefix (string sub -s 10 -- $arg)
        case --destdir
            set -l next $argv[(math $i + 1)]
            if test -z "$next"; or string match -qr '^--' -- $next
                echo "install.fish: --destdir requires a path" >&2
                exit 4
            end
            set destdir $next
        case '--destdir=*'
            set destdir (string sub -s 10 -- $arg)
        case '--*'
            echo "install.fish: unknown option: $arg" >&2
            aur_install_usage >&2
            exit 4
    end
end

function aur_install_wrapper --argument-names dest toolkit_root relpath
    printf '#!/usr/bin/env fish\nset -g AUR_RESPONSE_DIR %s\nexec fish %s/%s $argv\n' \
        $toolkit_root $toolkit_root $relpath >$dest
    chmod +x $dest
end

function aur_install_bash_wrapper --argument-names dest toolkit_root
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'set -euo pipefail' \
        "exec fish $toolkit_root/run.fish \"\$@\"" >$dest
    chmod +x $dest
end

if test "$system_mode" = false
    set -l bindir "$HOME/.local/bin"
    set -l configdir "$HOME/.config/aur-response"

    mkdir -p $bindir $configdir

    aur_install_wrapper $bindir/run.fish $src run.fish
    aur_install_wrapper $bindir/lint.fish $src lint.fish
    aur_install_wrapper $bindir/aur-run.fish $src bin/aur-run.fish

    for script in $src/scripts/*/*.fish
        set -l relpath (string replace "$src/" "" $script)
        set -l parts (string split / $relpath)
        set -l slug "$parts[2]-$parts[3]"
        ln -sf $script $bindir/aur-$slug
    end

    if not test -f $configdir/config.fish
        cp $src/config.fish.example $configdir/config.fish
        echo "Created $configdir/config.fish (edit to customize paths)"
    end

    echo "Installed to $bindir"
    echo "  run.fish / aur-run.fish (portable wrappers)"
    echo "  aur-{category}-{script}.fish (symlinks to individual scripts)"
    echo ""
    echo "Ensure $bindir is in PATH:"
    echo "  fish_add_path $bindir"
    exit 0
end

# --- FHS system install (copy tree + pinned wrappers) ---
set -l prefix_norm (string trim --right --chars=/ $prefix)
if test -z "$prefix_norm"
    echo "install.fish: --prefix cannot be empty" >&2
    exit 4
end

set -l stage (string trim --right --chars=/ $destdir)
set -l toolkit_root "$stage$prefix_norm/share/aur-response-toolkit"
set -l bindir "$stage$prefix_norm/bin"

if test -n "$stage"; and not test -d $stage
    mkdir -p $stage
end

if test -z "$stage"; and not test -w $prefix_norm
    echo "install.fish: $prefix_norm is not writable — try: sudo fish $src/install.fish --prefix $prefix_norm" >&2
    exit 1
end

mkdir -p $toolkit_root/{lib,scripts/{check,scan,audit,recovery},data/{lists,docs},bin} $bindir

for f in VERSION README.md config.fish.example
    cp $src/$f $toolkit_root/$f
end
for f in run.fish lint.fish run.sh
    cp $src/$f $toolkit_root/$f
    chmod +x $toolkit_root/$f
end
cp $src/bin/aur-run.fish $toolkit_root/bin/
chmod +x $toolkit_root/bin/aur-run.fish

cp $src/lib/*.fish $toolkit_root/lib/
cp $src/scripts/_init.fish $toolkit_root/scripts/
chmod +x $toolkit_root/scripts/_init.fish
for dir in check scan audit recovery
    cp $src/scripts/$dir/*.fish $toolkit_root/scripts/$dir/
    chmod +x $toolkit_root/scripts/$dir/*.fish
end
cp $src/data/lists/*.txt $toolkit_root/data/lists/
cp $src/data/docs/*.md $toolkit_root/data/docs/

aur_install_wrapper $bindir/aur-response $toolkit_root run.fish
aur_install_wrapper $bindir/aur-run $toolkit_root bin/aur-run.fish
aur_install_bash_wrapper $bindir/aur-response-bash $toolkit_root

for script in $src/scripts/*/*.fish
    set -l relpath (string replace "$src/" "" $script)
    set -l parts (string split / $relpath)
    set -l slug "aur-$parts[2]-$parts[3]"
    ln -sf "$toolkit_root/$relpath" $bindir/$slug
end

if test "$prefix_norm" = /usr
    set -l licdir "$stage/usr/share/licenses/aur-response-toolkit"
    set -l user_unit_dir "$stage/usr/lib/systemd/user"
    set -l system_unit_dir "$stage/usr/lib/systemd/system"
    mkdir -p $licdir $user_unit_dir $system_unit_dir
    cp $src/LICENSE $licdir/LICENSE

    cp $src/systemd/aur-response-scan.service $user_unit_dir/
    cp $src/systemd/aur-response-scan.timer $user_unit_dir/
    cp $src/systemd/aur-response-notify@.service $system_unit_dir/

    for unit in $user_unit_dir/aur-response-scan.service $system_unit_dir/aur-response-notify@.service
        sed -i \
            -e "s|Environment=AUR_RESPONSE_DIR=%h/aur-response-toolkit|Environment=AUR_RESPONSE_DIR=$toolkit_root|" \
            -e "s|WorkingDirectory=%h/aur-response-toolkit|WorkingDirectory=$toolkit_root|" \
            -e 's|ExecStart=/usr/bin/fish run.fish|ExecStart=/usr/bin/aur-response|' \
            -e "s|Environment=AUR_RESPONSE_DIR=/opt/aur-response-toolkit|Environment=AUR_RESPONSE_DIR=$toolkit_root|" \
            -e 's|ExecStart=/usr/bin/fish %AUR_RESPONSE_DIR%/run.fish|ExecStart=/usr/bin/aur-response|' \
            $unit
    end
end

echo "Installed FHS layout under $toolkit_root"
echo "  Commands: $bindir/aur-response, aur-run, aur-response-bash"
echo "  Per-script: $bindir/aur-{check,scan,recovery,audit}-*.fish"
if test "$prefix_norm" = /usr
    echo "  systemd user timer: $stage/usr/lib/systemd/user/aur-response-scan.{service,timer}"
    echo "    systemctl --user daemon-reload"
    echo "    systemctl --user enable --now aur-response-scan.timer"
end
echo ""
echo "Scan reports: ~/.local/share/aur-response/reports/"
echo "Optional config: cp $toolkit_root/config.fish.example ~/.config/aur-response/config.fish"
