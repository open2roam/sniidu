# NixOS deployment using nixos-anywhere (using fork with use_target_as_builder)
# See: https://github.com/onnimonni/nixos-anywhere/issues/1

module "nixos_deploy" {
  source = "github.com/onnimonni/nixos-anywhere//terraform/all-in-one"

  nixos_system_attr      = "${abspath("${path.module}/..")}#nixosConfigurations.memento-mori.config.system.build.toplevel"
  nixos_partitioner_attr = "${abspath("${path.module}/..")}#nixosConfigurations.memento-mori.config.system.build.diskoScript"

  target_host = hrobot_server.main.public_net.ipv4
  instance_id = hrobot_server.main.server_id

  # Boot kexec first, then build on target - nix store preserved
  use_target_as_builder = true
  build_on_remote       = true
  debug_logging         = true

  # User for post-deployment verification
  target_user = "root"

  # Extract SSH host keys from SOPS before installation
  extra_environment = {
    NIXOS_SYSTEM_NAME   = "memento-mori"
    STORAGEBOX_SERVER   = hcloud_storage_box.open2log.server
    STORAGEBOX_PASSWORD = var.hetzner_storage_box_admin_password
    STORAGEBOX_ID       = hcloud_storage_box.open2log.id
  }
  extra_files_script = abspath("${path.module}/scripts/get-ssh-host-key.sh")

  # Pass terraform variables to NixOS config
  special_args = {
    terraformArgs = {
      storagebox_server = hcloud_storage_box.open2log.server
    }
  }
}
