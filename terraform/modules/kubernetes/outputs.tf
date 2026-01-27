output "namespace" {
  value = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
}

output "client_service_name" {
  value = kubernetes_service_v1.knowledge_repo_client.metadata[0].name
}

output "server_service_name" {
  value = kubernetes_service_v1.knowledge_repo_server.metadata[0].name
}
