variable "namespace" {
  description = "Namespace to deploy all resources into."
  type        = string
  default     = "test-nginx"
}

variable "host" {
  description = "Host used by the Ingress rules. Use /etc/hosts or curl -H 'Host: ...' to test."
  type        = string
  default     = "test-nginx.local"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Optional kubeconfig context."
  type        = string
  default     = ""
}

