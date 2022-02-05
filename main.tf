terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.74.0"
    }
  }
}

module "sqs" {
    source = "./sqs"
    
    sns_account = var.sns_account
}

module "sns" {
    source = "./sns"

    sqs_account = var.sqs_account
}