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
  ];

  # https://devenv.sh/languages/
  languages.elixir.enable = true;
  languages.elixir.package = pkgs-unstable.elixir_1_19;
  languages.opentofu.enable = true;

  # Shorthands for tofu:
  # $ infra init -upgrade
  # $ infra plan
  # $ infra apply
  scripts.infra.exec = ''
    sops exec-env ${config.git.root}/secrets/infra.yaml "tofu -chdir=${config.git.root}/infra $@"
  '';

  # useful in scripting
  scripts.get_secret_env.exec = ''
    sops exec-env ${config.git.root}/secrets/infra.yaml "printenv $1"
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
