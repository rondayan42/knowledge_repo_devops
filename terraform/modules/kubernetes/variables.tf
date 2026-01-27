variable "namespace_name" {
  type    = string
  default = "knowledge-repo"
}

variable "postgres_password" {
  type    = string
  default = "password"
}

variable "db_image" {
  type    = string
  default = "postgres:13"
}

variable "server_replicas" {
  type    = number
  default = 1
}

variable "client_replicas" {
  type    = number
  default = 1
}

variable "environment" {
  description = "The deployment environment (dev/prod)"
  type        = string
}

variable "image_repository_server" {
  description = "ECR Repository URL for the server"
  type        = string
}

variable "image_repository_client" {
  description = "ECR Repository URL for the client"
  type        = string
}
