terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "knowledge-repo-tf-state-storage-unique-id"
    key            = "global/s3/terraform.tfstate"
    region         = "il-central-1"
    dynamodb_table = "knowledge-repo-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

module "registry" {
  source      = "./modules/registry"
  environment = terraform.workspace
}

module "kubernetes_resources" {
  source                  = "./modules/kubernetes"
  environment             = terraform.workspace
  image_repository_server = module.registry.repository_urls["knowledge-repo-server"]
  image_repository_client = module.registry.repository_urls["knowledge-repo-client"]
  server_replicas         = var.server_replicas
  client_replicas         = var.client_replicas
}
