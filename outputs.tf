output "namespace" {
  value = var.namespace
}

output "ingress_host" {
  value = var.host
}

output "services" {
  value = {
    red  = "${kubernetes_service.red.metadata[0].name}:80"
    blue = "${kubernetes_service.blue.metadata[0].name}:80"
  }
}

