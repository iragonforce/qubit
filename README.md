# Qubit

Public configuration snapshots for my macOS workstation.

The private `iragonforce/ops` repository remains the
authoritative source for infrastructure and deployment.

This repository contains reviewed configuration snapshots,
not automatically deployable configurations.

## Security

- Default-deny Git allowlist
- Gitleaks pre-commit and pre-push protection
- No credentials, private keys or authentication state
- No generated caches, logs or runtime databases
- No automatic changes to live configurations

## Coverage and exclusions

The public repository contains 63 verified live configuration
snapshots, of which 60 correspond to existing deployment targets
in the private `ops` inventory.

The remaining 49 live managed targets are intentionally excluded:

- 44 generated manual pages
- 5 private homelab or agent-context files

The private inventory also contains 284 deployment targets that
were absent during the consolidation audit. These were not recreated.

All published configuration snapshots match their live sources,
except for two intentional `-- gitleaks:allow` annotations in
`user/.config/nvim/lua/custom_dashboard.lua`. Those annotations
document false-positive detections on dashboard shortcut characters.

Known live-versus-`ops` differences have been preserved, including
the active Zsh configuration, Neovim lockfile, Tensor launcher,
and private Codex context.

## Repository protections

- Default-deny `.gitignore` with individual file allowlisting
- Local Gitleaks pre-commit and pre-push hooks
- GitHub Actions Gitleaks scanning on pushes and pull requests
- No automatic deployment from this repository

The private `iragonforce/ops` repository remains authoritative.
Public snapshots must not be used to overwrite live configurations
without a separate deployment review.
