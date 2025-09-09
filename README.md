# BookVerse Demo Assets

This repository is part of the JFrog AppTrust BookVerse demo. It serves as the shared assets hub used by all BookVerse microservices during demonstrations.

## What this repository contains
- Sample datasets and fixtures for service demos
- Example SBOMs, signed attestations, and policy files
- Shared GitHub Action composites and workflow snippets
- Screenshots and a presenter runbook for the demo flow

## How this repo fits the demo
- Provides reusable materials to illustrate AppTrust, SBOMs, signatures, and policy evaluation
- Hosts common workflow components referenced by service repos
- Central place for documentation and operator checklists

## Related repositories
- Services: `bookverse-inventory`, `bookverse-recommendations`, `bookverse-checkout`
- Shared: `bookverse-platform`

---
This repository is intentionally minimal and will be populated with demo collateral as needed.

## ArgoCD bootstrap

Bootstrap ArgoCD with Helm repository credentials and Docker registry pull secrets:

1) Edit `gitops/bootstrap/argocd-helm-repos.yaml` and set credentials for:
   - `https://evidencetrial.jfrog.io/artifactory/bookverse-helm-internal-helm-nonprod-local`
   - `https://evidencetrial.jfrog.io/artifactory/bookverse-helm-internal-helm-release-local`

2) Create a Docker config JSON for `apptrustswampupc.jfrog.io` and base64 it:

```
export JF_USER=<user>
export JF_PASS=<password-or-token>
cat > /tmp/.dockerconfigjson <<EOF
{
  "auths": {
    "apptrustswampupc.jfrog.io": {
      "auth": "$(printf "%s:%s" "$JF_USER" "$JF_PASS" | base64 -w 0)"
    }
  }
}
EOF
base64 -w 0 /tmp/.dockerconfigjson > /tmp/.dockerconfigjson.b64
```

3) Replace `PLACEHOLDER_BASE64_DOCKERCONFIG` in `gitops/bootstrap/docker-pull-secrets.yaml` with the contents of `/tmp/.dockerconfigjson.b64`.

4) Apply the bootstrap resources (requires the `argocd` namespace and the env namespaces to exist):

```
kubectl apply -f gitops/bootstrap/argocd-helm-repos.yaml
kubectl apply -f gitops/bootstrap/docker-pull-secrets.yaml
```

ArgoCD will then be able to fetch the platform Helm chart from JFrog and Kubernetes will be able to pull images from the JFrog Docker registry.
