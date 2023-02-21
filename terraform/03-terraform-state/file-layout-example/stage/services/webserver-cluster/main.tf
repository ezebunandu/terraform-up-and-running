provider "aws" {
  region = "us-east-2"
}
# Partial configuration. The other settings will be 
# passed in from a file via -backend-config arguments to 'terraform init'
terraform {
  backend "s3" {
    key            = "stage/services/webserver-cluster"
    region         = "us-east-2"
    dynamodb_table = "hezebonica-terraform-up-and-running-locks"
  }
}

module "webserver_cluster" {
  source                 = "../../../modules/services/webserver-cluster"
  cluster_name           = "webservers-stage"
  db_remote_state_bucket = "hezebonica-terraform-up-and-running-state"
  db_remote_state_key    = "stage/data-stores/mysql/terraform.tfstate"
}
