#!/usr/bin/env fish
#
# Point this clone at versioned hooks under .githooks/.
#
# Usage:
#   fish scripts/install-git-hooks.fish

set -l root (dirname (dirname (status filename)))
builtin cd $root
or exit 1

if not test -d $root/.githooks
    echo "error: missing $root/.githooks" >&2
    exit 1
end

chmod +x $root/.githooks/pre-commit $root/.githooks/commit-msg
git config core.hooksPath .githooks

echo "Git hooks installed (core.hooksPath=.githooks)"
echo "  pre-commit  — path-filtered (like CI):"
echo "                  fish_indent staged *.fish"
echo "                  lint.fish when Fish/lib/scripts/tests change"
echo "                  tests when Fish/lists change (not packaging/workflow-only)"
echo "  commit-msg  — Conventional Commits subject check"
echo ""
echo "Force / skip:"
echo "  AUR_HOOK_FULL=1      lint + tests always"
echo "  AUR_HOOK_LINT_ONLY=1 skip tests"
echo "  AUR_SKIP_HOOKS=1     skip all hooks"
