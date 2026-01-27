variable "environment" {
  description = "The deployment environment (dev/prod)"
  type        = string
}

variable "repositories" {
  description = "List of repository names to create"
  type        = list(string)
  default     = ["knowledge-repo-server", "knowledge-repo-client"]
}
