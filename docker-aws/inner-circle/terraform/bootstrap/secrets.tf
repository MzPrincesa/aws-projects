resource "aws_secretsmanager_secret" "internal_api_key" {
  name        = "inner-circle/internal-api-key"
  description = "Internal API key for inner-circle protected routes (placeholder for future auth)"
}

resource "aws_secretsmanager_secret_version" "internal_api_key" {
  secret_id     = aws_secretsmanager_secret.internal_api_key.id
  secret_string = jsonencode({
    INTERNAL_API_KEY = var.internal_api_key
  })
}