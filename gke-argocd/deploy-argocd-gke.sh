#!/usr/bin/env bash

# =============================================================================
# ARGOCD DEPLOYMENT ON GKE WITH EXTERNAL ACCESS
# =============================================================================
# Deploys ArgoCD on GKE with:
# - Global static IP
# - Google-managed SSL certificate  
# - External access via domain
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
STATIC_IP_NAME="${STATIC_IP_NAME:-argocd-ip}"
DOMAIN="${DOMAIN:-argocd.rodolphef.org}"
NAMESPACE="argocd"

echo ""
log_info "ArgoCD GKE Deployment with External Access"
echo "============================================="
log_info "Project: $PROJECT_ID"
log_info "Domain: $DOMAIN"
log_info "Static IP Name: $STATIC_IP_NAME"
echo ""

# Step 1: Check prerequisites
log_info "Step 1: Checking prerequisites..."
MISSING_TOOLS=()
command -v kubectl >/dev/null 2>&1 || MISSING_TOOLS+=("kubectl")
command -v helm >/dev/null 2>&1 || MISSING_TOOLS+=("helm")
command -v gcloud >/dev/null 2>&1 || MISSING_TOOLS+=("gcloud")

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    log_error "Missing required tools: ${MISSING_TOOLS[*]}"
    exit 1
fi
log_success "All tools available"
echo ""

# Step 2: Reserve Static IP
log_info "Step 2: Reserving static IP address..."
if gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" &>/dev/null; then
    STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" --format="value(address)")
    log_warning "Static IP already exists: $STATIC_IP"
else
    gcloud compute addresses create "$STATIC_IP_NAME" --global --project="$PROJECT_ID"
    STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" --format="value(address)")
    log_success "Static IP created: $STATIC_IP"
fi
echo ""

# Step 3: Display DNS instructions
log_warning "Step 3: Configure DNS (MANUAL STEP REQUIRED)"
echo "============================================="
echo "Please create a DNS A record:"
echo "  Type: A"
echo "  Name: $DOMAIN"
echo "  Value: $STATIC_IP"
echo "  TTL: 300"
echo ""
log_info "Example with Google Cloud DNS:"
echo "  gcloud dns record-sets create ${DOMAIN}. \\"
echo "    --zone=YOUR_DNS_ZONE \\"
echo "    --type=A \\"
echo "    --ttl=300 \\"
echo "    --rrdatas=$STATIC_IP"
echo ""
read -p "Press Enter once DNS is configured (or Ctrl+C to abort)..."
echo ""

# Step 4: Create namespace
log_info "Step 4: Creating ArgoCD namespace..."
kubectl apply -f 00-argocd-namespace.yaml
log_success "Namespace created"
echo ""

# Step 5: Add ArgoCD Helm repository
log_info "Step 5: Adding ArgoCD Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update
log_success "Helm repo added"
echo ""

# Step 6: Create managed certificate
log_info "Step 6: Creating Google-managed certificate..."
kubectl apply -f 02-argocd-managed-certificate.yaml
log_success "Managed certificate created"
log_warning "Certificate provisioning takes 15-60 minutes after DNS configuration"
echo ""

# Step 7: Deploy ArgoCD
log_info "Step 7: Deploying ArgoCD with Helm..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --values 03-argocd-values-gke.yaml \
  --wait \
  --timeout 10m

log_success "ArgoCD deployed"
echo ""

# Step 8: Apply custom ingress
log_info "Step 8: Applying GKE Ingress..."
kubectl apply -f 01-argocd-ingress.yaml
log_success "Ingress created"
echo ""

# Step 9: Get admin password
log_info "Step 9: Getting ArgoCD admin credentials..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

if [[ -n "$ARGOCD_PASSWORD" ]]; then
    echo ""
    log_success "ArgoCD Credentials:"
    echo "  URL: https://$DOMAIN"
    echo "  Username: admin"
    echo "  Password: $ARGOCD_PASSWORD"
    echo ""
    log_warning "Save these credentials securely!"
else
    log_warning "Could not retrieve admin password. Get it manually with:"
    echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
fi
echo ""

# Step 10: Display status
log_info "Step 10: Deployment Status"
echo "============================"
echo ""
kubectl get pods -n argocd
echo ""
kubectl get ingress -n argocd
echo ""
kubectl get managedcertificate -n argocd
echo ""

# Final instructions
log_success "ArgoCD Deployment Complete!"
echo ""
log_info "Next Steps:"
echo "1. ⏱️  Wait for certificate provisioning (15-60 minutes)"
echo "   Monitor: kubectl get managedcertificate -n argocd -w"
echo ""
echo "2. 🌐 Access ArgoCD UI:"
echo "   URL: https://$DOMAIN"
echo "   Username: admin"
echo "   Password: (shown above)"
echo ""
echo "3. 📦 Configure BookVerse repositories in ArgoCD UI"
echo "   - Add JFrog Helm repositories"
echo "   - Add GitHub repository (bookverse-demo-assets)"
echo ""
echo "4. 🚀 Deploy BookVerse applications via ArgoCD"
echo "   See: ../gitops/apps/ for application definitions"
echo ""

