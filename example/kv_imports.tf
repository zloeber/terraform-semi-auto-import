import {
  to = vault_kv_secret_v2.secrets["api-keys"]
  id = "kv/data/api-keys"
}

import {
  to = vault_kv_secret_v2.secrets["app-config"]
  id = "kv/data/app-config"
}

import {
  to = vault_kv_secret_v2.secrets["database-config"]
  id = "kv/data/database-config"
}

import {
  to = vault_kv_secret_v2.secrets["deployment-config"]
  id = "kv/data/deployment-config"
}

import {
  to = vault_kv_secret_v2.secrets["email-config"]
  id = "kv/data/email-config"
}

import {
  to = vault_kv_secret_v2.secrets["monitoring-config"]
  id = "kv/data/monitoring-config"
}

import {
  to = vault_kv_secret_v2.secrets["redis-config"]
  id = "kv/data/redis-config"
}

import {
  to = vault_kv_secret_v2.secrets["security-config"]
  id = "kv/data/security-config"
}

import {
  to = vault_kv_secret_v2.secrets["third-party-services"]
  id = "kv/data/third-party-services"
}

import {
  to = vault_kv_secret_v2.secrets["user-credentials"]
  id = "kv/data/user-credentials"
}

import {
  to = vault_mount.kv
  id = "kv"
}
