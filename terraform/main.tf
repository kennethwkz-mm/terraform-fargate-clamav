terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    encrypt        = true
    bucket         = "mm-tf-clamav-fargate-state"
    dynamodb_table = "tf-dynamodb-lock"
    region         = "ap-southeast-1"
    key            = "terraform.tfstate"
  }
}

provider "aws" {
  profile = "default"
  region  = "ap-southeast-1"
}
