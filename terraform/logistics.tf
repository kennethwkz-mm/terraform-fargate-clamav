provider "aws" {
  region = "ap-southeast-1"
  alias  = "asia"
  default_tags {
    tags = {
      app    = "clamav"
      env    = "prod"
      region = "global"
      team   = "engineering"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_s3_bucket" "quarantine_bucket" {
  provider = aws.asia
  bucket   = "mm-clamav-quarantine"
}

resource "aws_s3_bucket_acl" "quarantine_bucket" {
  bucket = aws_s3_bucket.quarantine_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "quarantine_bucket" {
  bucket = aws_s3_bucket.quarantine_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "quarantine_bucket" {
  bucket = aws_s3_bucket.quarantine_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "quarantine_bucket" {
  bucket = aws_s3_bucket.quarantine_bucket.bucket

  rule {
    id     = "auto-delete-virus-rule"
    status = "Enabled"

    # Anything in the bucket remaining is a virus, so
    # we'll just delete it after a week.
    expiration {
      days = 7
    }
  }

  depends_on = [aws_s3_bucket.quarantine_bucket]
}

resource "aws_s3_bucket_cors_configuration" "quarantine_bucket" {
  bucket = aws_s3_bucket.quarantine_bucket.bucket

  cors_rule {
    allowed_headers = ["Authorization"]
    allowed_methods = ["GET", "POST"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

  depends_on = [aws_s3_bucket.quarantine_bucket]
}


resource "aws_s3_bucket" "clean_bucket" {
  provider = aws.asia
  bucket   = "mm-clamav-clean"
}

resource "aws_s3_bucket_acl" "clean_bucket" {
  bucket = aws_s3_bucket.clean_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "clean_bucket" {
  bucket = aws_s3_bucket.clean_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "clean_bucket" {
  bucket = aws_s3_bucket.clean_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "clean_bucket" {
  bucket = aws_s3_bucket.clean_bucket.bucket

  cors_rule {
    allowed_headers = ["Authorization"]
    allowed_methods = ["GET", "POST"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

  depends_on = [aws_s3_bucket.clean_bucket]
}


data "template_file" "event_queue_policy" {
  template = file("templates/event_queue_policy.tpl.json")

  vars = {
    bucketArn = aws_s3_bucket.quarantine_bucket.arn
  }

  depends_on = [aws_s3_bucket.quarantine_bucket]
}

resource "aws_sqs_queue" "clamav_event_queue" {
  name = "s3_clamav_event_queue"

  policy = data.template_file.event_queue_policy.rendered

  depends_on = [aws_s3_bucket.quarantine_bucket]
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.quarantine_bucket.bucket

  queue {
    queue_arn = aws_sqs_queue.clamav_event_queue.arn
    events    = ["s3:ObjectCreated:*"]
  }
  depends_on = [
    aws_s3_bucket.quarantine_bucket,
    aws_sqs_queue.clamav_event_queue
  ]
}

resource "aws_cloudwatch_log_group" "clamav_fargate_log_group" {
  name = "/aws/ecs/clamav_fargate"
}
