# configure the Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "demo" {
  bucket = "govind-s3-bucket-devops-demo"

  tags = {
    Name        = "govind-s3-bucket-devops-demo"
    Environment = "DevOps"
  }
}



