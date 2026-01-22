Read @GOAL.md and implement it.

## Claude Code Hooks

Hooks in `.claude/settings.json` automatically validate your work:

- **PostToolUse (Edit|Write)**: When editing `infra/*.tf` files, runs `tofu validate` and `tofu fmt`. Exit code 2 blocks the edit and shows errors - fix them before continuing.

If you see OpenTofu validation errors after editing .tf files, read the error message and fix the syntax issue immediately.

## DuckDB version compatibility

**IMPORTANT**: Always check `duckdb --version` against latest release before using community extensions. The duckdb-crawler extension requires matching versions. If devenv.nix has an older version, update it first or extensions won't load.

```bash
# Check current version
duckdb --version

# Compare with https://github.com/duckdb/duckdb/releases
```

## Validation commands (no credentials needed)

```bash
# Phoenix compilation check
cd apps/web/open2log && mix deps.get && mix compile

# Rust workers check
cd workers/image-upload && cargo check
cd workers/shopping-lists && cargo check

# NixOS flake check
nix flake check ./server/configuration
```

## Ways of working
* Create a task list for yourself so that you can keep track of what is already done and what needs still improving.
* Git commit and push between features.
* Ask user to help when something is difficult
* Use the included ADR skill to document your decision making
* Add missing tools to devenv.nix
* Use SOPS to encrypt secrets
* Use Swift for iOS app and use native integrations
* Use Kotlin for Android app
* Use monorepo inside this git repository. create DuckDB extensions and OpenTofu plugins outside of this repository.
* If certain credential for Cloudflare or Hetzner is not available you can ask for them from the user.
* Whenever user says 'terraform' they actually mean 'opentofu'