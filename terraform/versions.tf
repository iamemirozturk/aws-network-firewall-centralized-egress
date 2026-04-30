terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
  }

  # Uncomment and configure for remote state with state locking.
  # backend "s3" {
  #   bucket         = "my-tf-state-bucket"
  #   key            = "aws-centralized-egress-inspection/terraform.tfstate"
  #   region         = "eu-west-1"
  #   encrypt        = true
  #   dynamodb_table = "my-tf-state-lock"
  # }
}
