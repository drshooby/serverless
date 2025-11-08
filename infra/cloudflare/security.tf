resource "cloudflare_zone_settings_override" "ettukube" {
  zone_id = var.cloudflare_zone_id

  settings {
    ssl              = "flexible"
    always_use_https = "on"

    security_level = "medium"
  }
}
