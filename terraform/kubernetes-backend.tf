# Backend ConfigMap
resource "kubernetes_config_map" "backend" {
  metadata {
    name      = "backend-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    NODE_ENV      = var.environment
    PORT          = "5000"
    MONGODB_URI   = "mongodb://admin:${var.mongodb_root_password}@mongodb:27017/${var.mongodb_database}?authSource=admin"
    DATABASE_NAME = var.mongodb_database
  }
}

# Backend Secret
resource "kubernetes_secret" "backend" {
  metadata {
    name      = "backend-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    jwt-secret = base64encode(var.jwt_secret)
  }

  type = "Opaque"
}

# Backend Deployment
resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "backend"
    }
  }

  spec {
    replicas = var.backend_replicas

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        #  POD-LEVEL SECURITY CONTEXT
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000
        }
        container {
          name  = "backend"
          image = var.backend_image
          image_pull_policy = "Always"

          #  CONTAINER-LEVEL SECURITY CONTEXT
          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
            run_as_non_root          = true
            run_as_user              = 1000
          }          

          port {
            container_port = 5000
            name           = "http"
          }

          env {
            name = "NODE_ENV"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.backend.metadata[0].name
                key  = "NODE_ENV"
              }
            }
          }

          env {
            name = "PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.backend.metadata[0].name
                key  = "PORT"
              }
            }
          }

          env {
            name = "MONGODB_URI"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.backend.metadata[0].name
                key  = "MONGODB_URI"
              }
            }
          }

          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.backend.metadata[0].name
                key  = "jwt-secret"
              }
            }
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "200m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }

        # Wait for MongoDB to be ready
        init_container {
          name  = "wait-for-mongodb"
          image = "busybox:1.35"
          
          #  INIT CONTAINER SECURITY CONTEXT
          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            run_as_non_root = true
            run_as_user     = 1000
          }
          command = [
            "sh",
            "-c",
            "until nc -z mongodb 27017; do echo waiting for mongodb; sleep 2; done"
          ]
        }
      }
    }
  }

  depends_on = [
    kubernetes_service.mongodb,
    kubernetes_config_map.backend,
    kubernetes_secret.backend
  ]
}

# Backend Service
resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "backend"
    }
  }

  spec {
    selector = {
      app = "backend"
    }

    port {
      port        = 5000
      target_port = 5000
      protocol    = "TCP"
      name        = "http"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.backend]
}
