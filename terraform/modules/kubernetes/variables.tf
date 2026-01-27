variable "namespace_name" {
  description = "The name of the Kubernetes namespace"
  type        = string
  default     = "knowledge-repo"
}

variable "client_image" {
  description = "The Docker image for the client application"
  type        = string
  default     = "knowledge-repo-client:latest"
}

variable "client_replicas" {
  description = "Number of replicas for the client deployment"
  type        = number
  default     = 2
}

variable "server_image" {
  description = "The Docker image for the server application"
  type        = string
  default     = "knowledge-repo-server:latest"
}

variable "server_replicas" {
  description = "Number of replicas for the server deployment"
  type        = number
  default     = 2
}

variable "db_image" {
  description = "The Docker image for the database"
  type        = string
  default     = "postgres:15-alpine"
}

variable "postgres_password" {
  description = "The password for the PostgreSQL database"
  type        = string
  sensitive   = true
  default     = "password_placeholder_change_me"
}
