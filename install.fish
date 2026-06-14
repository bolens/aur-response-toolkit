#!/usr/bin/env fish

# Install aur-response-toolkit into ~/.local/bin.
# Wrappers embed AUR_RESPONSE_DIR so scripts work after the clone is moved or removed.

set -l src (cd (dirname (status filename)); and pwd)
set -l bindir "$HOME/.local/bin"
set -l configdir "$HOME/.config/aur-response"

mkdir -p $bindir $configdir

function aur_install_wrapper --argument-names dest relpath
    # Tiny fish stub: pin toolkit root, delegate to the real script under the clone.
    printf '#!/usr/bin/env fish\nset -g AUR_RESPONSE_DIR %s\nexec fish %%s/%s %%argv\n' $src $src $relpath >$dest
    chmod +x $dest
end

aur_install_wrapper $bindir/run.fish run.fish
aur_install_wrapper $bindir/lint.fish lint.fish
aur_install_wrapper $bindir/aur-run.fish bin/aur-run.fish

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
