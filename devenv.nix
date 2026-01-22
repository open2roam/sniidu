{
  pkgs,
  inputs,
  config,
  ...
}:
let
  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };
in

rec {
  # Use VS Code as the default editor
  # To see all undocumented VS Code flags visit:
  # https://github.com/microsoft/vscode/blob/main/src/vs/platform/environment/node/argv.ts
  env.EDITOR = "code --wait --skip-welcome --skip-release-notes --disable-telemetry --skip-add-to-recently-opened";

  # I noticed that when typing $ sops secret.yaml, that copilot was enabled
  # This made me worry that the secrets were being sent to a remote server
  # Disable co-pilot and all other extensions when editing SOPS secrets
  env.SOPS_EDITOR = "${env.EDITOR} --new-window --disable-workspace-trust --disable-extensions";

  # Use age key which is securely generated with MacOS Secure Enclave
  # See docs/SECRETS.md for more
  # This can't be done with env because $HOME is not available for nix
  enterShell = ''
    export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/secure-enclave-key.txt"
  '';

  # https://devenv.sh/packages/
  packages = with pkgs; [
    # Secret management
    sops
    age
    age-plugin-se

    # Architecture Decision Records
    adr-tools

    # Version control
    git

    # Deployment
    nixos-rebuild
    nixos-anywhere

    # Data processing - use unstable for latest version (needed for community extensions)
    pkgs-unstable.duckdb

    # Cloudflare Workers
    #wrangler

    # SQLite replication
    litestream
  ];

  # https://devenv.sh/languages/
  languages.elixir.enable = true;
  languages.elixir.package = pkgs-unstable.elixir_1_19;
  languages.opentofu.enable = true;
  languages.rust.enable = true;

  # Shorthands for tofu:
  # $ infra init -upgrade
  # $ infra plan
  # $ infra apply
  scripts.infra.exec = ''
    case "$1" in
      validate)
        tofu -chdir=${config.git.root}/infra $@
        ;;
      *)
        sops exec-env ${config.git.root}/secrets/infra.yaml "tofu -chdir=${config.git.root}/infra $@"
        ;;
    esac
  '';

  # useful in scripting
  scripts.get_secret_env.exec = ''
    sops exec-env ${config.git.root}/secrets/infra.yaml "printenv $1"
  '';

  # Phoenix app shortcuts
  # $ web setup   - Install dependencies
  # $ web server  - Start development server
  # $ web test    - Run tests
  # $ web migrate - Run migrations
  scripts.web.exec = ''
    cd ${config.git.root}/apps/web/open2log
    case "$1" in
      setup)
        mix deps.get && mix setup
        ;;
      server|s)
        mix phx.server
        ;;
      test|t)
        mix test
        ;;
      migrate|m)
        mix ecto.migrate
        ;;
      iex)
        iex -S mix phx.server
        ;;
      *)
        mix "$@"
        ;;
    esac
  '';

  # DuckDB crawling pipelines
  # $ crawl s-kaupat  - Crawl S-kaupat.fi
  # $ crawl lidl      - Crawl Lidl.fi
  # $ crawl tokmanni  - Crawl Tokmanni.fi
  # $ crawl all       - Run all crawlers
  # $ crawl consolidate - Consolidate all data
  scripts.crawl.exec = ''
    PIPELINES_DIR="${config.git.root}/data/pipelines"
    OUTPUT_DIR="${config.git.root}/data/output"
    mkdir -p "$OUTPUT_DIR"
    cd "$OUTPUT_DIR"
    case "$1" in
      s-kaupat|skaupat)
        duckdb -f "$PIPELINES_DIR/crawl_s_kaupat.sql"
        ;;
      lidl)
        duckdb -f "$PIPELINES_DIR/crawl_lidl_fi.sql"
        ;;
      tokmanni)
        duckdb -f "$PIPELINES_DIR/crawl_tokmanni.sql"
        ;;
      all)
        duckdb -f "$PIPELINES_DIR/crawl_s_kaupat.sql"
        duckdb -f "$PIPELINES_DIR/crawl_lidl_fi.sql"
        duckdb -f "$PIPELINES_DIR/crawl_tokmanni.sql"
        duckdb -f "$PIPELINES_DIR/consolidate.sql"
        ;;
      consolidate)
        duckdb -f "$PIPELINES_DIR/consolidate.sql"
        ;;
      *)
        echo "Usage: crawl <s-kaupat|lidl|tokmanni|all|consolidate>"
        ;;
    esac
  '';

  # Deploy server with nixos-anywhere
  # $ deploy <ip> - Deploy NixOS to server
  scripts.deploy.exec = ''
    if [ -z "$1" ]; then
      echo "Usage: deploy <server-ip>"
      exit 1
    fi
    nixos-anywhere --flake ${config.git.root}/server/configuration#memento-mori root@$1
  '';

  # Worker deployment
  # $ worker deploy <name>  - Deploy a Cloudflare Worker
  # $ worker dev <name>     - Run worker locally
  scripts.worker.exec = ''
    if [ -z "$1" ] || [ -z "$2" ]; then
      echo "Usage: worker <deploy|dev> <worker-name>"
      echo "Available workers: image-upload, shopping-lists"
      exit 1
    fi
    WORKER_DIR="${config.git.root}/workers/$2"
    if [ ! -d "$WORKER_DIR" ]; then
      echo "Worker '$2' not found"
      exit 1
    fi
    cd "$WORKER_DIR"
    case "$1" in
      deploy)
        wrangler deploy
        ;;
      dev)
        wrangler dev
        ;;
      *)
        echo "Unknown command: $1"
        ;;
    esac
  '';

  # https://devenv.sh/git-hooks/
  git-hooks.excludes = [
    ".devenv"
    "GEMINI.md"
    "CLAUDE.md"
  ];

  git-hooks.hooks = {
    # Nix files
    nixfmt-rfc-style.enable = true;
    # Github Actions
    actionlint.enable = true;
    # Stop accidentally leaking secrets
    ripsecrets.enable = true;
  };

  # Prevents unencrypted sops files from being committed
  git-hooks.hooks.pre-commit-hook-ensure-sops = {
    enable = true;
    files = "secret.*\\.(env|ini|yaml|yml|json)$";
  };

  # Security hardening to prevent malicious takeover of Github Actions:
  # https://news.ycombinator.com/item?id=43367987
  # Replaces tags like "v4" in 3rd party Github Actions to the commit hashes
  git-hooks.hooks.lock-github-action-tags = {
    enable = true;
    files = "^.github/workflows/";
    types = [ "yaml" ];
    entry =
      let
        script_path = pkgs.writeShellScript "lock-github-action-tags" ''
          for workflow in "$@"; do
            grep -E "uses:[[:space:]]+[A-Za-z0-9._-]+/[A-Za-z0-9._-]+@v[0-9]+" "$workflow" | while read -r line; do
              repo=$(echo "$line" | sed -E 's/.*uses:[[:space:]]+([A-Za-z0-9._-]+\/[A-Za-z0-9._-]+)@v[0-9]+.*/\1/')
              tag=$(echo "$line" | sed -E 's/.*@((v[0-9]+)).*/\1/')
              commit_hash=$(git ls-remote "https://github.com/$repo.git" "refs/tags/$tag" | cut -f1)
              [ -n "$commit_hash" ] && sed -i.bak -E "s|(uses:[[:space:]]+$repo@)$tag|\1$commit_hash #$tag|g" "$workflow" && rm -f "$workflow.bak"
            done
          done
        '';
      in
      toString script_path;
  };
}
