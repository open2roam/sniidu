# Cloudflare resources for open2log

# Data sources for existing zones
data "cloudflare_zone" "open2log" {
  account_id = var.cloudflare_account_id
  name       = "open2log.com"
}

data "cloudflare_zone" "opentolog" {
  account_id = var.cloudflare_account_id
  name       = "opentolog.com"
}

# R2 bucket for product images and user uploads
resource "cloudflare_r2_bucket" "images" {
  account_id = var.cloudflare_account_id
  name       = "open2log-images"
  location   = "EEUR" # Eastern Europe for lower latency to Finland
}

# R2 bucket for DuckLake parquet files (synced from Hetzner)
resource "cloudflare_r2_bucket" "data" {
  account_id = var.cloudflare_account_id
  name       = "open2log-data"
  location   = "EEUR"
}

# D1 database for shared shopping lists
resource "cloudflare_d1_database" "shopping_lists" {
  account_id = var.cloudflare_account_id
  name       = "open2log-shopping-lists"
}

# DNS records for main domain - proxied through Cloudflare
resource "cloudflare_record" "open2log_root" {
  zone_id = data.cloudflare_zone.open2log.id
  name    = "@"
  content = hrobot_server.main.public_net.ipv4
  type    = "A"
  proxied = true
  ttl     = 1 # Auto TTL when proxied
}

resource "cloudflare_record" "open2log_www" {
  zone_id = data.cloudflare_zone.open2log.id
  name    = "www"
  content = hrobot_server.main.public_net.ipv4
  type    = "A"
  proxied = true
  ttl     = 1
}

# API subdomain
resource "cloudflare_record" "open2log_api" {
  zone_id = data.cloudflare_zone.open2log.id
  name    = "api"
  content = hrobot_server.main.public_net.ipv4
  type    = "A"
  proxied = true
  ttl     = 1
}

# Redirect opentolog.com to open2log.com
resource "cloudflare_record" "opentolog_root" {
  zone_id = data.cloudflare_zone.opentolog.id
  name    = "@"
  content = "open2log.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

resource "cloudflare_ruleset" "opentolog_redirect" {
  zone_id = data.cloudflare_zone.opentolog.id
  name    = "Redirect to open2log.com"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules {
    action = "redirect"
    action_parameters {
      from_value {
        status_code = 301
        target_url {
          expression = "concat(\"https://open2log.com\", http.request.uri.path)"
        }
        preserve_query_string = true
      }
    }
    expression  = "true"
    description = "Redirect all traffic to open2log.com"
    enabled     = true
  }
}

# Rate limiting for API endpoints
resource "cloudflare_ruleset" "rate_limiting" {
  zone_id = data.cloudflare_zone.open2log.id
  name    = "API Rate Limiting"
  kind    = "zone"
  phase   = "http_ratelimit"

  # Price submission rate limit - 10 per minute per IP
  rules {
    action = "block"
    ratelimit {
      characteristics     = ["ip.src"]
      period              = 60
      requests_per_period = 10
      mitigation_timeout  = 600
    }
    expression  = "(http.request.uri.path matches \"^/api/v1/prices$\" and http.request.method eq \"POST\")"
    description = "Limit price submissions to 10/minute"
    enabled     = true
  }

  # Registration rate limit - 3 per hour per IP
  rules {
    action = "block"
    ratelimit {
      characteristics     = ["ip.src"]
      period              = 3600
      requests_per_period = 3
      mitigation_timeout  = 3600
    }
    expression  = "(http.request.uri.path matches \"^/api/v1/auth/register$\" and http.request.method eq \"POST\")"
    description = "Limit registrations to 3/hour"
    enabled     = true
  }

  # General API rate limit - 100 per minute per IP
  rules {
    action = "block"
    ratelimit {
      characteristics     = ["ip.src"]
      period              = 60
      requests_per_period = 100
      mitigation_timeout  = 60
    }
    expression  = "(http.request.uri.path matches \"^/api/\")"
    description = "General API rate limit"
    enabled     = true
  }
}

# SSL/TLS settings
resource "cloudflare_zone_settings_override" "open2log_settings" {
  zone_id = data.cloudflare_zone.open2log.id

  settings {
    ssl                      = "strict"
    always_use_https         = "on"
    min_tls_version          = "1.2"
    automatic_https_rewrites = "on"
    security_header {
      enabled            = true
      include_subdomains = true
      max_age            = 31536000
      nosniff            = true
      preload            = true
    }
    browser_cache_ttl = 14400
    cache_level       = "aggressive"
  }
}

# Cache rules for static content
resource "cloudflare_ruleset" "cache_rules" {
  zone_id = data.cloudflare_zone.open2log.id
  name    = "Cache Rules"
  kind    = "zone"
  phase   = "http_request_cache_settings"

  # Cache product images for 1 week
  rules {
    action = "set_cache_settings"
    action_parameters {
      cache = true
      edge_ttl {
        mode    = "override_origin"
        default = 604800 # 1 week
      }
      browser_ttl {
        mode    = "override_origin"
        default = 86400 # 1 day
      }
    }
    expression  = "(http.request.uri.path matches \"\\.(jpg|jpeg|png|avif|webp|svg)$\")"
    description = "Cache images for 1 week at edge, 1 day in browser"
    enabled     = true
  }

  # Cache static assets for 1 month
  rules {
    action = "set_cache_settings"
    action_parameters {
      cache = true
      edge_ttl {
        mode    = "override_origin"
        default = 2592000 # 30 days
      }
    }
    expression  = "(http.request.uri.path matches \"\\.(css|js|woff2?)$\")"
    description = "Cache static assets for 1 month"
    enabled     = true
  }
}

# Outputs for use in other configs
output "r2_images_bucket_name" {
  value = cloudflare_r2_bucket.images.name
}

output "d1_database_id" {
  value = cloudflare_d1_database.shopping_lists.id
}

output "zone_id" {
  value = data.cloudflare_zone.open2log.id
}
