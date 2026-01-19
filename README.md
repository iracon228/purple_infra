# Test Assignment — Two NGINX Deployments + Ingress Round-Robin (Terraform + Kubernetes)

This repository contains a Terraform configuration that deploys two NGINX pods (RED and BLUE) with custom start pages and exposes them through a single Kubernetes Ingress using NGINX Ingress Controller with round-robin load balancing.

## Objective

Provision the following Kubernetes resources using Terraform:

- Dedicated namespace (`test-nginx` by default)
- Two NGINX Deployments:
  - **RED NGINX** (red background)
  - **BLUE NGINX** (blue background)
- Two Services to expose each deployment
- **One Ingress** (IngressClass: `nginx`) that serves `/` and distributes requests using:
  - `nginx.ingress.kubernetes.io/load-balance: round_robin`

The custom start page for each deployment is provided via a ConfigMap and mounted to replace:
`/usr/share/nginx/html/index.html`.

## Implementation Notes

### Why a “combined” Service is used
The Kubernetes Ingress API (`networking.k8s.io/v1`) supports only one backend per `host + path` rule.  
To use **one Ingress resource** while still alternating between RED and BLUE, this solution introduces an additional service:

- `nginx-combined-svc` — selects both RED and BLUE pods and provides a single backend for the Ingress
- NGINX Ingress Controller then load-balances between the two endpoints (pods) using the requested `round_robin` algorithm

This preserves the requirement to have:
- 2 Deployments
- 2 Services (per deployment)
- 1 Ingress resource  
…while enabling alternating responses at `/`.

## Prerequisites

- Kubernetes cluster (tested on **minikube**)
- `kubectl`
- `terraform` (>= 1.4)
- NGINX Ingress Controller available with `IngressClass` named **`nginx`**

### Minikube (recommended setup)
Enable the built-in ingress addon:

```bash
minikube addons enable ingress
````

Verify it is running:

```bash
kubectl get pods -n ingress-nginx
kubectl get ingressclass
```

## Deployed Resources

Namespace (default): `test-nginx`

- ConfigMaps:
    
    - `red-nginx-index`
        
    - `blue-nginx-index`
        
- Deployments:
    
    - `red-nginx`
        
    - `blue-nginx`
        
- Services:
    
    - `red-nginx-svc`
        
    - `blue-nginx-svc`
        
    - `nginx-combined-svc` (used as Ingress backend)
        
- Ingress:
    
    - `nginx-single-ingress` (IngressClass: `nginx`)
        

## How to Deploy

```bash
terraform init
terraform apply
```

Outputs include:

- `namespace`
    
- `ingress_host` (default `test-nginx.local`)
    
- service names
    

## How to Verify

### 1) Confirm pods and ingress

```bash
kubectl get pods,svc,ingress -n test-nginx
```

### 2) Verify each pod serves the correct page

```bash
kubectl -n test-nginx exec deploy/red-nginx  -- sh -c 'wget -qO- http://127.0.0.1/ | grep -m1 -Eo "(RED|BLUE) NGINX"'
kubectl -n test-nginx exec deploy/blue-nginx -- sh -c 'wget -qO- http://127.0.0.1/ | grep -m1 -Eo "(RED|BLUE) NGINX"'
```

Expected:

- `RED NGINX`
    
- `BLUE NGINX`
    

### 3) Verify Ingress load balancing

Depending on your cluster environment, the ingress controller may not be directly reachable via the node IP/NodePort.  
On minikube, the most reliable method is port-forwarding the ingress controller service:

**Terminal 1:**

```bash
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8080:80
```

**Terminal 2:**

```bash
for i in $(seq 1 20); do
  curl -s --http1.1 \
    -H "Host: test-nginx.local" \
    -H "Connection: close" \
    "http://127.0.0.1:8080/?r=$i" | grep -m1 -Eo "(RED|BLUE) NGINX"
done
```

Expected: a mix of `RED NGINX` and `BLUE NGINX` across repeated requests.

> Tip: `?r=$i` helps avoid client/proxy caching. `Connection: close` avoids keep-alive effects.

## Configuration

Default values are defined in `variables.tf`:

- `namespace` (default: `test-nginx`)
    
- `host` (default: `test-nginx.local`)
    
- `kubeconfig_path` (default: `~/.kube/config`)
    
- `kubeconfig_context` (optional)
    

You can override them, for example:

```bash
terraform apply -var="namespace=test-nginx" -var="host=test-nginx.local"
```

## Cleanup

```bash
terraform destroy
```

## Result

After deployment, the Ingress serves `/` and repeated requests alternate between:

- **RED NGINX** page (red background)
    
- **BLUE NGINX** page (blue background)
    

This demonstrates round-robin distribution across two NGINX endpoints behind a single Ingress.
