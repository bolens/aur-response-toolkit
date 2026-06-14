# atomic-arch-response-toolkit

Fish shell toolkit to detect, triage, and recover from the **June 2026 Arch User Repository (AUR) supply-chain attack** — the [Atomic Arch](https://www.sonatype.com/blog/atomic-arch-npm-campaign-adds-malicious-dependency) campaign that injected `atomic-lockfile`, `js-digest`, and `lockfile-js` into orphaned AUR packages, deploying the [`deps`](https://ioctl.fail/preliminary-analysis-of-aur-malware/) credential stealer and optional eBPF rootkit.

**Official Arch repositories (`[core]`, `[extra]`, `[multilib]`) were not affected.** This targets AUR packages only.

## What it does

| Step | Script | Checks |
|------|--------|--------|
| 1 | `check-infected-pkgs.fish` | Installed packages vs known infected list; HIGH/LOW risk by install date |
| 2 | `scan-aur-window.fish` | All AUR activity during Jun 9–14, 2026 (catches unknowns) |
| 3 | `scan-pacman-timeline.fish` | Known infected packages in `pacman.log` during the window |
| 4 | `scan-malware-artifacts.fish` | `deps` ELF, malicious npm packages, AUR cache hooks, eBPF maps |
| 5 | `scan-hardening.fish` | `npm ignore-scripts`, paru/yay review settings, IOC references |
| 6 | `audit-stolen-credentials.fish` | SSH, git, docker, browsers, chat apps, env files, shell history |
| 7 | `rotate-hints.fish` | Concrete logout and rotation commands |

Package lists are merged from two sources on fetch:

- [Arch markdown list](https://md.archlinux.org/s/SxbqukK6IA)
- [cscs paste](https://cscs.pastes.sh/raw/aurvulntest20260611.sh)

## Requirements

- [Fish shell](https://fishshell.com/)
- Arch Linux (or derivative) with `pacman`, `curl`, `find`, `comm`
- Optional: `paru` or `yay` (AUR helper cache scanning)

## Install

```fish
git clone https://github.com/bolens/atomic-arch-response-toolkit.git
cd atomic-arch-response-toolkit
chmod +x *.fish
```

## Usage

```fish
# Full scan (fetch fresh package lists)
fish run.fish

# Offline with bundled list
fish run.fish --local

# Always run credential audit, even if clean
fish run.fish --audit

# Save unified report + JSON summary
fish run.fish --report --json

# Individual scripts
fish check-infected-pkgs.fish --local
fish scan-malware-artifacts.fish
fish audit-stolen-credentials.fish
```

### If infected

```fish
fish remove-infected.fish --dry-run    # preview
fish remove-infected.fish              # interactive removal
fish run.fish --audit --report         # full post-removal triage
fish rotate-hints.fish                 # concrete rotation commands
fish scrub-history.fish --dry-run      # redact fish history after rotating creds
```

### Exit codes

- `0` — no issues detected
- `1` — infected packages, timeline hits, artifacts, or hardening warnings

Use in automation:

```fish
fish run.fish --local --json || notify-send "AUR incident: issues found"
```

## Weekly timer (optional)

```fish
mkdir -p ~/.config/systemd/user
ln -sf ~/atomic-arch-response-toolkit/systemd/aur-malware-check.service ~/.config/systemd/user/
ln -sf ~/atomic-arch-response-toolkit/systemd/aur-malware-check.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now aur-malware-check.timer
```

Reports are written to `reports/` (gitignored).

## Layout

```
atomic-arch-response-toolkit/
├── run.fish                      # Main entry point
├── check-infected-pkgs.fish
├── scan-aur-window.fish
├── scan-pacman-timeline.fish
├── scan-malware-artifacts.fish
├── scan-hardening.fish
├── audit-stolen-credentials.fish
├── rotate-hints.fish
├── remove-infected.fish
├── scrub-history.fish
├── infected-pkgs.txt             # Cached merged package list
├── lib/common.fish
├── reports/                      # Generated logs (gitignored)
└── systemd/
```

## What the malware steals

The `deps` infostealer targets developer credentials: SSH keys, browser cookies, GitHub/npm tokens, Docker registry auth, Discord/Slack/Teams sessions, Vault tokens, shell histories, `.env` files, and more. See the [ioctl.fail analysis](https://ioctl.fail/preliminary-analysis-of-aur-malware/) for full IOCs.

If any infected package was installed during the compromise window, **rotate all credentials** the machine had access to.

## References

- [ioctl.fail — preliminary analysis of AUR malware](https://ioctl.fail/preliminary-analysis-of-aur-malware/)
- [Sonatype — Atomic Arch npm campaign](https://www.sonatype.com/blog/atomic-arch-npm-campaign-adds-malicious-dependency)
- [lenucksi/aur-malware-check](https://github.com/lenucksi/aur-malware-check)
- [Phoronix — 1500+ AUR packages compromised](https://www.phoronix.com/news/Arch-Linux-AUR-400-Compromised)

## License

[MIT](LICENSE)
