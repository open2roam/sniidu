resource "hrobot_ssh_key" "onnimonni" {
  name       = "onnimonni"
  public_key = file("keys/onnimonni.pub")
}

resource "hrobot_server" "main" {
  server_type = "Server Auction"
  server_id   = var.hetzner_auction_server_id
  server_name = "memento-mori"

  # These are used only for the initial deployment
  authorized_keys = [hrobot_ssh_key.onnimonni.fingerprint]

  public_net {
    ipv4_enabled = true
  }

  lifecycle {
    # Do not accidentally delete this
    prevent_destroy = true
  }
}

resource "hcloud_storage_box" "open2log" {
  name             = "open2log"
  storage_box_type = "bx11"
  location         = "hel1"
  password         = var.hetzner_storage_box_admin_password

  labels = {
    visibility = "public",
    contains   = "ducklake",
    env        = "production"
  }

  access_settings = {
    reachable_externally = true
    ssh_enabled          = true
    webdav_enabled       = true

    samba_enabled = false
    zfs_enabled   = false
  }

  # You can set the initial SSH Keys as an attribute on the resource, but these
  # can not be updated through the API and through the terraform provider.
  # If this attribute is ever changed, the provider will mark the resource as
  # "requires replacement" and you could loose the data stored on the Storage Box.
  ssh_keys = [
    file("keys/onnimonni.pub")
  ]

  # Do not accidentally delete this
  lifecycle {
    ignore_changes = [
      ssh_keys
    ]
    prevent_destroy = true
  }
}

output "ip" {
  description = "Main ipv4 address of the server"
  value       = hrobot_server.main.public_net.ipv4
}

output "storagebox_id" {
  description = "Storage Box ID"
  value       = hcloud_storage_box.open2log.id
}

output "storagebox_server" {
  description = "Storage Box server (username for WebDAV)"
  value       = hcloud_storage_box.open2log.server
}

output "storagebox_webdav_url" {
  description = "WebDAV URL for the storage box"
  value       = "https://${hcloud_storage_box.open2log.server}.your-storagebox.de"
}