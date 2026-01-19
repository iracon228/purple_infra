resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

locals {
  red_index_html = <<-HTML
  <!doctype html>
  <html>
    <head>
      <meta charset="utf-8" />
      <meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate, max-age=0" />
      <meta http-equiv="Pragma" content="no-cache" />
      <meta http-equiv="Expires" content="0" />
      <title>RED NGINX</title>
      <style>
        html, body { height: 100%; margin: 0; }
        body {
          display: flex; align-items: center; justify-content: center;
          background: #d00000; color: white; font-family: Arial, sans-serif;
        }
        h1 { font-size: 56px; letter-spacing: 2px; }
      </style>
    </head>
    <body>
      <h1>RED NGINX</h1>
    </body>
  </html>
  HTML

  blue_index_html = <<-HTML
  <!doctype html>
  <html>
    <head>
      <meta charset="utf-8" />
      <meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate, max-age=0" />
      <meta http-equiv="Pragma" content="no-cache" />
      <meta http-equiv="Expires" content="0" />
      <title>BLUE NGINX</title>
      <style>
        html, body { height: 100%; margin: 0; }
        body {
          display: flex; align-items: center; justify-content: center;
          background: #0050d0; color: white; font-family: Arial, sans-serif;
        }
        h1 { font-size: 56px; letter-spacing: 2px; }
      </style>
    </head>
    <body>
      <h1>BLUE NGINX</h1>
    </body>
  </html>
  HTML
}

resource "kubernetes_config_map" "red" {
  metadata {
    name      = "red-nginx-index"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    "index.html" = local.red_index_html
  }
}

resource "kubernetes_config_map" "blue" {
  metadata {
    name      = "blue-nginx-index"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    "index.html" = local.blue_index_html
  }
}

resource "kubernetes_deployment" "red" {
  metadata {
    name      = "red-nginx"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels = {
      app  = "nginx-test"
      tier = "web"
      color = "red"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app   = "nginx-test"
        color = "red"
      }
    }

    template {
      metadata {
        labels = {
          app   = "nginx-test"
          tier  = "web"
          color = "red"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.25-alpine"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "index-html"
            mount_path = "/usr/share/nginx/html/index.html"
            sub_path   = "index.html"
            read_only  = true
          }
        }

        volume {
          name = "index-html"

          config_map {
            name = kubernetes_config_map.red.metadata[0].name

            items {
              key  = "index.html"
              path = "index.html"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "blue" {
  metadata {
    name      = "blue-nginx"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels = {
      app  = "nginx-test"
      tier = "web"
      color = "blue"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app   = "nginx-test"
        color = "blue"
      }
    }

    template {
      metadata {
        labels = {
          app   = "nginx-test"
          tier  = "web"
          color = "blue"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.25-alpine"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "index-html"
            mount_path = "/usr/share/nginx/html/index.html"
            sub_path   = "index.html"
            read_only  = true
          }
        }

        volume {
          name = "index-html"

          config_map {
            name = kubernetes_config_map.blue.metadata[0].name

            items {
              key  = "index.html"
              path = "index.html"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "red" {
  metadata {
    name      = "red-nginx-svc"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels = {
      app   = "nginx-test"
      color = "red"
    }
  }

  spec {
    selector = {
      app   = "nginx-test"
      color = "red"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_service" "combined" {
  metadata {
    name      = "nginx-combined-svc"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels = {
      app = "nginx-test"
    }
  }

  spec {
    # Must match BOTH red and blue pods.
    selector = {
      app  = "nginx-test"
      tier = "web"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}


resource "kubernetes_service" "blue" {
  metadata {
    name      = "blue-nginx-svc"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels = {
      app   = "nginx-test"
      color = "blue"
    }
  }

  spec {
    selector = {
      app   = "nginx-test"
      color = "blue"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "single" {
  metadata {
    name      = "nginx-single-ingress"
    namespace = kubernetes_namespace.this.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/load-balance" = "round_robin"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.combined.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

