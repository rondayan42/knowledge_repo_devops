output "app_service_port" {
  value = module.kubernetes_resources.server_service_node_port
}

output "ecr_repository_url_server" {
  value = module.registry.repository_urls["knowledge-repo-server"]
}

output "ecr_repository_url_client" {
  value = module.registry.repository_urls["knowledge-repo-client"]
}
