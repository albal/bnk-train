# Sample backend that the Gateway's HTTPRoute sends traffic to
resource "kubernetes_namespace_v1" "demo" {
  metadata {
    name = "demo"
  }
}

resource "kubernetes_deployment_v1" "demo" {
  metadata {
    name      = "demo-web"
    namespace = kubernetes_namespace_v1.demo.metadata[0].name
    labels    = { app = "demo-web" }
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "demo-web" }
    }

    template {
      metadata {
        labels = { app = "demo-web" }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.29-alpine"

          port {
            container_port = 80
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "demo" {
  metadata {
    name      = "demo-web"
    namespace = kubernetes_namespace_v1.demo.metadata[0].name
  }

  spec {
    selector = { app = "demo-web" }

    port {
      port        = 80
      target_port = 80
    }
  }
}
