variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "il-central-1"
}

variable "server_replicas" {
  description = "Number of server replicas"
  type        = number
  default     = 2
}

variable "client_replicas" {
  description = "Number of client replicas"
  type        = number
  default     = 2
}
