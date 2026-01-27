terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace_v1" "knowledge_repo" {
  metadata {
    name = var.namespace_name
  }
}

resource "kubernetes_secret_v1" "knowledge_repo_db_credentials" {
  metadata {
    name      = "knowledge-repo-db-credentials"
    namespace = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
    labels = {
      app = "knowledge-repo-db"
    }
  }

  data = {
    POSTGRES_USER     = "knowledge_repo"
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB       = "knowledge_repo"
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_claim_v1" "knowledge_repo_db_data" {
  metadata {
    name      = "knowledge-repo-db-data"
    namespace = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_stateful_set_v1" "knowledge_repo_db" {
  metadata {
    name      = "knowledge-repo-db"
    namespace = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
    labels = {
      app = "knowledge-repo-db"
    }
  }

  spec {
    service_name = "knowledge-repo-db"
    replicas     = 1

    selector {
      match_labels = {
        app = "knowledge-repo-db"
      }
    }

    template {
      metadata {
        labels = {
          app = "knowledge-repo-db"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = var.db_image

          port {
            container_port = 5432
            name           = "postgres"
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.knowledge_repo_db_credentials.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "knowledge_repo"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "knowledge_repo"]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.knowledge_repo_db_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "knowledge_repo_db" {
  metadata {
    name      = "knowledge-repo-db"
    namespace = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
  }
  spec {
    selector = {
      app = "knowledge-repo-db"
    }
    port {
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_secret_v1" "knowledge_repo_server_secrets" {
  metadata {
    name      = "knowledge-repo-server-secrets"
    namespace = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
  }
  data = {
    JWT_SECRET = "your-super-secret-jwt-key-change-this-in-production"
  }
  type = "Opaque"
}

resource "kubernetes_config_map_v1" "knowledge_repo_server_config" {
  metadata {
    name      = "knowledge-repo-server-config"
    namespace = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
  }

  data = {
    DATABASE_URL     = "postgresql://knowledge_repo:${var.postgres_password}@${kubernetes_service_v1.knowledge_repo_db.metadata[0].name}:5432/knowledge_repo"
    JWT_EXPIRY_HOURS = "24"
    PORT             = "5000"
    DEBUG            = "false"
    GUNICORN_WORKERS = "2"
  }
}

resource "kubernetes_persistent_volume_claim_v1" "knowledge_repo_uploads" {
  metadata {
    name      = "knowledge-repo-uploads"
    namespace = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "knowledge_repo_server" {
  metadata {
    name      = "knowledge-repo-server"
    namespace = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
    labels = {
      app = "knowledge-repo-server"
    }
  }

  spec {
    replicas = var.server_replicas

    selector {
      match_labels = {
        app = "knowledge-repo-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "knowledge-repo-server"
        }
      }

      spec {
        container {
          name              = "knowledge-repo-server"
          image             = var.server_image
          image_pull_policy = "Never" # Assuming local development or direct availability

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOF
            echo "Waiting for database..." &&
            echo "Waiting for database..." &&
            python -c "import socket, time, sys; start=time.time();
            while True:
                try:
                    socket.create_connection(('knowledge-repo-db', 5432), timeout=1); print('DB ready'); break
                except OSError:
                    if time.time()-start>120: print('Timeout waiting for DB'); sys.exit(1)
                    print('Waiting for DB...'); time.sleep(2)" &&
            python seed_root_user.py &&
            echo "Initialization done. Starting Gunicorn..." &&
            gunicorn -c gunicorn.conf.py app:app
            EOF
          ]

          port {
            container_port = 5000
            name           = "http"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.knowledge_repo_server_config.metadata[0].name
            }
          }
          env_from {
            secret_ref {
              name = kubernetes_secret_v1.knowledge_repo_server_secrets.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "uploads"
            mount_path = "/app/uploads"
          }
        }

        volume {
          name = "uploads"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.knowledge_repo_uploads.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "knowledge_repo_server" {
  metadata {
    name      = "knowledge-repo-server"
    namespace = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
  }
  spec {
    selector = {
      app = "knowledge-repo-server"
    }
    port {
      port        = 5000
      target_port = 5000
      node_port   = 30050
    }
    type = "NodePort"
  }
}

resource "kubernetes_deployment_v1" "knowledge_repo_client" {
  metadata {
    name      = "knowledge-repo-client"
    namespace = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
    labels = {
      app = "knowledge-repo-client"
    }
  }

  spec {
    replicas = var.client_replicas

    selector {
      match_labels = {
        app = "knowledge-repo-client"
      }
    }

    template {
      metadata {
        labels = {
          app = "knowledge-repo-client"
        }
      }

      spec {
        container {
          name              = "knowledge-repo-client"
          image             = var.client_image
          image_pull_policy = "Never"

          port {
            container_port = 8080
            name           = "http"
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "100m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "knowledge_repo_client" {
  metadata {
    name      = "knowledge-repo-client"
    namespace = kubernetes_namespace_v1.knowledge_repo.metadata[0].name
  }
  spec {
    selector = {
      app = "knowledge-repo-client"
    }
    port {
      port        = 80
      target_port = 8080
      node_port   = 30051
    }
    type = "NodePort"
  }
}
