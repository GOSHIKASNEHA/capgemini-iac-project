terraform {
  backend "s3" {
    bucket         = "capgemini-terraform-state-sneha"
    key            = "dev/capgemini/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
