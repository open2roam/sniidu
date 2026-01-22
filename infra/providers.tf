terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    hrobot = {
      source  = "midwork-finds-jobs/hrobot"
      version = "~> 0.1.0"
    }
    hcloud = {
      source  = "hashicorp/hcloud"
      version = "~> 1.59"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "hrobot" {
  username = var.hrobot_username
  password = var.hrobot_password
}

provider "hcloud" {
  # Token comes from HCLOUD_TOKEN env var via sops
}
