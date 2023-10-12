
resource "random_password" "fence_password" {
  length  = var.password_length
  special = false
}

resource "random_password" "sheepdog_password" {
  length  = var.password_length
  special = false
}

resource "random_password" "peregrine_password" {
  length  = var.password_length
  special = false
}

resource "random_password" "indexd_password" {
  length  = var.password_length
  special = false
}

resource "random_password" "hmac_encryption_key" {
  length  = 32
  special = false
}

resource "random_password" "sheepdog_secret_key" {
  length  = 50
  special = false
}

resource "random_password" "sheepdog_indexd_password" {
  length  = 32
  special = false
}
