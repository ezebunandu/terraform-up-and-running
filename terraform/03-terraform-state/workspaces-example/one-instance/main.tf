provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example" {
  ami           = "ami-0b37b2354291b7da9"
  instance_type = "t2.micro"
}

terraform {
  backend "s3" {
    bucket = "hezebonica-terraform-up-and-running-state"
    key    = "workspace-example/terraform.tfstate"
    region = "us-east-2"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}
