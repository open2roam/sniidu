# NixOS deployment using nixos-anywhere
# Passes storage box credentials securely to the server

module "nixos_deploy" {
  source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"

  nixos_system_attr      = ".#nixosConfigurations.memento-mori.config.system.build.toplevel"
  nixos_partitioner_attr = ".#nixosConfigurations.memento-mori.config.system.build.diskoScript"

  target_host = hrobot_server.main.public_net.ipv4
  instance_id = hrobot_server.main.server_id

  # Pass storage box credentials via extra_files_script
  extra_files_script = "${path.module}/scripts/generate-secrets.sh"

  extra_environment = {
    STORAGEBOX_SERVER   = hcloud_storage_box.open2log.server
    STORAGEBOX_PASSWORD = var.hetzner_storage_box_admin_password
    STORAGEBOX_ID       = hcloud_storage_box.open2log.id
  }
}
