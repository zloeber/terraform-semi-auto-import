terraform {
  required_version = ">= 1.0"
  
  required_providers {
    vault = {
      source  = "hashicorp/vault"
    }
  }
  backend "local" {}
}

# Configure the Vault Provider
provider "vault" {
  # For local Vault instance, typically runs on localhost:8200
  address = "http://localhost:8200"
  
  # For development, you might want to disable TLS verification
  # In production, always use proper TLS certificates
  skip_tls_verify = true
  
  # Token for authentication (you'll need to set this)
  # You can also use VAULT_TOKEN environment variable
  # token = var.vault_token
}

# Variables
variable "vault_token" {
  description = "Vault token for authentication"
  type        = string
  sensitive   = true
  default     = "dev-token-12345"
}

# Enable KV v2 secrets engine if not already enabled
resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine"
}

# Generate 10 different KV secrets with various data types
locals {
  kv_secrets = {
    "app-config" = {
      database_url = "postgresql://user:pass@localhost:5432/mydb"
      api_key      = "sk-1234567890abcdef"
      environment  = "development"
      debug_mode   = "true"
    }
    
    "user-credentials" = {
      admin_username = "admin"
      admin_password = "secure_password_123"
      user_count     = "150"
      last_backup    = "2024-01-15T10:30:00Z"
    }
    
    "api-keys" = {
      stripe_key     = "sk_test_51ABC123DEF456"
      aws_access_key = "AKIAIOSFODNN7EXAMPLE"
      aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      github_token   = "ghp_1234567890abcdef"
    }
    
    "database-config" = {
      host     = "db.example.com"
      port     = "5432"
      name     = "production_db"
      username = "db_user"
      password = "db_password_secure"
      ssl_mode = "require"
    }
    
    "redis-config" = {
      host        = "redis.example.com"
      port        = "6379"
      password    = "redis_password"
      db_number   = "0"
      max_memory  = "2gb"
      persistence = "true"
    }
    
    "email-config" = {
      smtp_host     = "smtp.gmail.com"
      smtp_port     = "587"
      smtp_username = "noreply@example.com"
      smtp_password = "email_password_secure"
      from_address  = "noreply@example.com"
      reply_to      = "support@example.com"
    }
    
    "monitoring-config" = {
      prometheus_url = "http://prometheus:9090"
      grafana_url    = "http://grafana:3000"
      alertmanager   = "http://alertmanager:9093"
      log_level      = "info"
      metrics_port   = "8080"
    }
    
    "security-config" = {
      jwt_secret        = "super_secret_jwt_key_12345"
      session_secret    = "session_secret_key_67890"
      encryption_key    = "encryption_key_abcdef123456"
      rate_limit_window = "60"
      max_requests      = "1000"
    }
    
    "third-party-services" = {
      slack_webhook     = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
      discord_webhook   = "https://discord.com/api/webhooks/123456789/abcdefghijklmnop"
      pagerduty_key     = "pagerduty_integration_key_123"
      sentry_dsn        = "https://1234567890abcdef@sentry.io/123456"
    }
    
    "deployment-config" = {
      docker_registry = "registry.example.com"
      image_tag       = "v1.2.3"
      replicas        = "3"
      cpu_limit       = "500m"
      memory_limit    = "512Mi"
      health_check    = "/health"
      readiness_path  = "/ready"
    }
  }
}

# Create KV secrets
resource "vault_kv_secret_v2" "secrets" {
  for_each = local.kv_secrets
  
  mount = vault_mount.kv.path
  name  = each.key
  
  data_json = jsonencode(each.value)
}

# Output the created secret paths
output "vault_secret_paths" {
  description = "Paths to the created Vault secrets"
  value       = [for secret in vault_kv_secret_v2.secrets : "${vault_mount.kv.path}/${secret.name}"]
}

output "secret_count" {
  description = "Number of secrets created"
  value       = length(vault_kv_secret_v2.secrets)
}

output "vault_mount_path" {
  description = "Path where the KV secrets engine is mounted"
  value       = vault_mount.kv.path
}

# Example of how to read a secret (for reference)
data "vault_kv_secret_v2" "example_read" {
  mount = vault_mount.kv.path
  name  = "app-config"
  
  depends_on = [vault_kv_secret_v2.secrets]
}

output "example_secret_data" {
  description = "Example of reading secret data"
  value       = data.vault_kv_secret_v2.example_read.data
  sensitive   = true
}
