# ArgoCD Deployment on GKE with External Access

Complete ArgoCD setup for GKE with external access via Google Cloud Load Balancer.

## 🎯 What This Provides

- ✅ ArgoCD accessible externally via domain (`argocd.rodolphef.org`)
- ✅ Global static IP address
- ✅ Google-managed SSL certificate (automatic HTTPS)
- ✅ GKE Ingress with Google Cloud Load Balancer
- ✅ Pre-configured with BookVerse JFrog repositories
- ✅ Based on your working Artifactory example

## 📂 Files Structure

```
gke-argocd/
├── README.md                           # This file
├── deploy-argocd-gke.sh               # Automated deployment script
├── 00-argocd-namespace.yaml           # ArgoCD namespace
├── 01-argocd-ingress.yaml             # GKE Ingress with static IP
├── 02-argocd-managed-certificate.yaml # Google-Managed SSL certificate
└── 03-argocd-values-gke.yaml          # Helm values for ArgoCD on GKE
```

## 🚀 Quick Deployment

### Prerequisites

- GKE cluster running
- `kubectl`, `helm`, `gcloud` CLI tools installed
- Domain name (e.g., `argocd.rodolphef.org`)

### Step 1: Reserve Static IP

```bash
export PROJECT_ID="your-gcp-project"

gcloud compute addresses create argocd-ip --global --project=$PROJECT_ID

# Get the IP
STATIC_IP=$(gcloud compute addresses describe argocd-ip --global --format="value(address)")
echo "Static IP: $STATIC_IP"
```

### Step 2: Configure DNS

Create DNS A record:
- Name: `argocd.rodolphef.org`
- Type: A
- Value: `$STATIC_IP`

### Step 3: Deploy ArgoCD

**Option A: Automated (Recommended)**
```bash
cd /Users/rodolphefontaine/bookverse-demo/bookverse-demo-assets/gke-argocd

./deploy-argocd-gke.sh
```

**Option B: Manual Steps**
```bash
# 1. Create namespace
kubectl apply -f 00-argocd-namespace.yaml

# 2. Add Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 3. Create managed certificate
kubectl apply -f 02-argocd-managed-certificate.yaml

# 4. Deploy ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --values 03-argocd-values-gke.yaml

# 5. Apply ingress
kubectl apply -f 01-argocd-ingress.yaml

# 6. Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## 🔐 Access ArgoCD

### Get Credentials

```bash
# Username
admin

# Password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Access URL

Once certificate is active (15-60 minutes):
```
https://argocd.rodolphef.org
```

## 📦 Configure BookVerse in ArgoCD

### 1. Add JFrog Helm Repositories

In ArgoCD UI: **Settings → Repositories → Connect Repo**

**Internal Helm Repo:**
- Type: `Helm`
- Name: `bookverse-helm-internal`
- URL: `https://rodolphefplus.jfrog.io/artifactory/bookverse-helm-helm-internal-local`
- Username: `your-jfrog-user`
- Password: `your-jfrog-token`

**Release Helm Repo:**
- Type: `Helm`
- Name: `bookverse-helm-release`
- URL: `https://rodolphefplus.jfrog.io/artifactory/bookverse-helm-helm-release-local`
- Username: `your-jfrog-user`
- Password: `your-jfrog-token`

### 2. Add GitHub Repository

**BookVerse GitOps Repo:**
- Type: `Git`
- URL: `https://github.com/Rodi26/bookverse-demo-assets.git`
- Path: `gitops/apps/`

### 3. Create Applications

Use the application definitions in `../gitops/apps/`:
- `dev/platform.yaml`
- `qa/platform.yaml`
- `staging/platform.yaml`
- `prod/platform.yaml`

## 🔍 Monitoring

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ingress
kubectl get ingress -n argocd

# Check certificate status
kubectl get managedcertificate -n argocd

# View ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

## 🎯 GKE-Specific Features

### Static IP
```yaml
annotations:
  kubernetes.io/ingress.global-static-ip-name: argocd-ip
```

### Google-Managed Certificate
```yaml
annotations:
  networking.gke.io/managed-certificates: argocd-cert
```

### GCE Ingress Class
```yaml
spec:
  ingressClassName: gce
```

## 🔄 Architecture

```
Internet
   ↓
DNS: argocd.rodolphef.org → STATIC_IP
   ↓
Google Cloud Load Balancer
   ├─ Static IP: argocd-ip
   ├─ SSL Certificate: Google-Managed
   └─ Backend: ArgoCD Server (NodePort)
       ↓
   ArgoCD (namespace: argocd)
   ├─ argocd-server (UI/API)
   ├─ argocd-repo-server
   ├─ argocd-application-controller
   └─ argocd-redis
       ↓
   Manages BookVerse deployments across:
   ├─ bookverse-dev
   ├─ bookverse-qa
   ├─ bookverse-staging
   └─ bookverse-prod
```

## 🐛 Troubleshooting

### Cannot Access ArgoCD UI

```bash
# Check ingress has external IP
kubectl get ingress argocd-server-ingress -n argocd

# Check certificate status (must be ACTIVE)
kubectl describe managedcertificate argocd-cert -n argocd

# Check DNS resolution
nslookup argocd.rodolphef.org
```

### Certificate Stuck in PROVISIONING

Wait 15-60 minutes and ensure:
- DNS record points to correct static IP
- Domain is accessible on port 80/443

### Admin Password Not Working

Reset the password:
```bash
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "'$(htpasswd -bnBC 10 "" YOUR_NEW_PASSWORD | tr -d ':\n')'"}}'
```

## 🗑️ Cleanup

```bash
# Delete ArgoCD
helm uninstall argocd -n argocd

# Delete resources
kubectl delete -f 01-argocd-ingress.yaml
kubectl delete -f 02-argocd-managed-certificate.yaml
kubectl delete namespace argocd

# Delete static IP
gcloud compute addresses delete argocd-ip --global
```

## 📚 References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD on GKE](https://cloud.google.com/architecture/building-deployment-pipelines-with-argocd-and-gke)
- [GKE Ingress](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress)

## ⚠️ Important

- ✅ This is a **separate configuration** for ArgoCD on GKE
- ✅ Does **not modify** the generic ArgoCD configs in `../gitops/`
- ✅ **Production-ready** with external access
- ✅ Based on your **working Artifactory GKE example**

