provider "aws" {
  region = "us-east-2"
}
# Partial configuration. The other settings will be 
# passed in from a file via -backend-config arguments to 'terraform init'
terraform {
  backend "s3" {
    key            = "prod/services/webserver-cluster"
    region         = "us-east-2"
    dynamodb_table = "hezebonica-terraform-up-and-running-locks"
  }
}

module "webserver_cluster" {
  source                 = "../../../modules/services/webserver-cluster"
  cluster_name           = "webservers-prod"
  db_remote_state_bucket = "hezebonica-terraform-up-and-running-state"
  db_remote_state_key    = "prod/data-stores/mysql/terraform.tfstate"

  instance_type = "t2.micro"
  min_size      = 2
  max_size      = 4
}
