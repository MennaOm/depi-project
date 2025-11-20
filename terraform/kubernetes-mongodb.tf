# MongoDB Secret
resource "kubernetes_secret" "mongodb" {
  metadata {
    name      = "mongodb-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    mongodb-root-password = base64encode(var.mongodb_root_password)
  }

  type = "Opaque"
}

# MongoDB PersistentVolumeClaim
resource "kubernetes_persistent_volume_claim" "mongodb" {
  metadata {
    name      = "mongodb-pvc"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.ebs_sc.metadata[0].name

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }

  depends_on = [kubernetes_storage_class.ebs_sc]
}

# MongoDB StatefulSet
resource "kubernetes_stateful_set" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "mongodb"
    }
  }

  spec {
    service_name = "mongodb"
    replicas     = 1

    selector {
      match_labels = {
        app = "mongodb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongodb"
        }
      }

      spec {
        # POD-LEVEL SECURITY CONTEXT (MongoDB needs root for data directory)
        security_context {
          fs_group = 1000
        }

        container {
          name  = "mongodb"
          image = var.mongodb_image

          # CONTAINER-LEVEL SECURITY CONTEXT (MongoDB specific)
          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            # MongoDB needs to run as root to manage its data directory
            run_as_user = 0
            run_as_non_root = false
          }

          port {
            container_port = 27017
            name           = "mongodb"
          }

          env {
            name = "MONGO_INITDB_ROOT_USERNAME"
            value = "admin"
          }

          env {
            name = "MONGO_INITDB_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongodb.metadata[0].name
                key  = "mongodb-root-password"
              }
            }
          }

          env {
            name  = "MONGO_INITDB_DATABASE"
            value = var.mongodb_database
          }

          volume_mount {
            name       = "mongodb-data"
            mount_path = "/data/db"
          }

          resources {
            requests = {
              memory = "512Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "1Gi"
              cpu    = "500m"
            }
          }

          liveness_probe {
            exec {
              command = ["mongosh", "--eval", "db.adminCommand('ping')"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["mongosh", "--eval", "db.adminCommand('ping')"]
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }

        volume {
          name = "mongodb-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mongodb.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_persistent_volume_claim.mongodb]
}

# MongoDB Service
resource "kubernetes_service" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "mongodb"
    }
  }

  spec {
    selector = {
      app = "mongodb"
    }

    port {
      port        = 27017
      target_port = 27017
      protocol    = "TCP"
    }

    cluster_ip = "None" # Headless service for StatefulSet
    type       = "ClusterIP"
  }

  depends_on = [kubernetes_stateful_set.mongodb]
}
