output "server_service_node_port" {
  value = kubernetes_service_v1.knowledge_repo_server.spec[0].port[0].node_port
}
