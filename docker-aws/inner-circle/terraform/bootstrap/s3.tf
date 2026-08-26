resource "aws_s3_bucket" "alb_logs" {
  bucket = "inner-circle-alb-logs-343218184480"
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::127311923021:root"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::inner-circle-alb-logs-343218184480/AWSLogs/343218184480/*"
      }
    ]
  })
}

