#!/usr/bin/env fish

# Install atomic-arch-response-toolkit into ~/.local/bin.
# Wrappers embed AUR_RESPONSE_DIR so scripts work after the clone is moved or removed.

set -l src (cd (dirname (status filename)); and pwd)
set -l bindir "$HOME/.local/bin"
set -l configdir "$HOME/.config/atomic-arch-response"
set -l legacy_configdir "$HOME/.config/aur-response"

mkdir -p $bindir $configdir

function aur_install_wrapper --argument-names dest relpath
    # Tiny fish stub: pin toolkit root, delegate to the real script under the clone.
    printf '#!/usr/bin/env fish\nset -g AUR_RESPONSE_DIR %s\nexec fish %%s/%s %%argv\n' $src $src $relpath >$dest
    chmod +x $dest
end

aur_install_wrapper $bindir/run.fish run.fish
aur_install_wrapper $bindir/lint.fish lint.fish
aur_install_wrapper $bindir/atomic-run.fish bin/atomic-run.fish

for script in $src/scripts/*.fish
    set -l name (basename $script)
    ln -sf $script $bindir/atomic-$name
end

if not test -f $configdir/config.fish
    if test -f $legacy_configdir/config.fish
        cp $legacy_configdir/config.fish $configdir/config.fish
        echo "Migrated $legacy_configdir/config.fish → $configdir/config.fish"
    else
        cp $src/config.fish.example $configdir/config.fish
        echo "Created $configdir/config.fish (edit to customize paths)"
    end
end

echo "Installed to $bindir"
echo "  run.fish / atomic-run.fish (portable wrappers)"
echo "  atomic-*.fish (symlinks to individual scripts)"
echo ""
echo "Ensure $bindir is in PATH:"
echo "  fish_add_path $bindir"
