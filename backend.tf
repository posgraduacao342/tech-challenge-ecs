terraform {
  backend "s3" {
    bucket = "pos-graduacao-terraform-state"
    key    = "ecs/terraform.tfstate"
    region = "us-east-1"
  }
}