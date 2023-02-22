provider "aws" {
  region = "us-east-2"
}

resource "aws_db_instance" "example" {
  identifier_prefix   = "terraform-up-and-running-prod"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t2.micro"
  skip_final_snapshot = true
  db_name             = "prod_db"

  username = var.db_username
  password = var.db_password
}

terraform {
  backend "s3" {
    bucket = "hezebonica-terraform-up-and-running-state"
    key    = "prod/data-stores/mysql/terraform.tfstate"
    region = "us-east-2"

    dynamodb_table = "hezebonica-terraform-up-and-running-locks"
    encrypt        = true
  }
}
