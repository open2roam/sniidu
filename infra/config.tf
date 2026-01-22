variable "state_passphrase" {
  type        = string
  sensitive   = true
  description = "value of the passphrase used to encrypt the state file"
  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "The passphrase must be at least 16 characters long."
  }
}

terraform {
  required_version = ">= 1.9.0"
  encryption {
    key_provider "pbkdf2" "mykey" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "passphrase" {
      keys = key_provider.pbkdf2.mykey
    }
    state {
      enforced = true
      method   = method.aes_gcm.passphrase
    }
    plan {
      enforced = true
      method   = method.aes_gcm.passphrase
    }
  }

  # Added following https://developers.cloudflare.com/terraform/advanced-topics/remote-backend/
  # Access key, secret key and the s3 url override come from secrets/infra.yaml
  backend "s3" {
    bucket                      = "infra-state"
    key                         = "open2log/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
