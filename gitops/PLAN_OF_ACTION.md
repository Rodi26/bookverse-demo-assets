## BookVerse GitOps Plan of Action

This document outlines a demo‑focused GitOps strategy, optimized for simplicity and clarity. For the purposes of the AppTrust demo, the only environment actively deploying to Kubernetes is PROD, and deployments are triggered exclusively by AppTrust “Recommended Platform Version” events. DEV/QA/STAGING are out of scope for live cluster deployments in this demo and are mentioned only for context.

### Objectives
- **Single source of truth**: All desired state is expressed as code in this repo and `bookverse-helm`.
- **Simplicity for demo**: Keep manifests minimal and readable; favor defaults; avoid complexity.
- **PROD-only live deploys**: Only AppTrust-approved Platform versions deploy to the cluster.
- **Automated drift detection and reconciliation**: Argo CD auto-sync in PROD.
- **Provenance & trust (placeholder)**: Policies are outlined as comments/placeholders; not implemented in demo.

### Repos and Responsibilities
- **bookverse-demo-assets (this repo)**: GitOps control-plane repo for Argo CD Projects, Applications, bootstrap, and environment-level secrets/policies.
- **bookverse-helm**: Application Helm charts using a single values file (`charts/platform/values.yaml`).
- **service repos**: Application source; CI builds images and pushes charts to Artifactory, then opens PRs updating Helm chart versions.
- **AppTrust**: Source of truth for “Recommended Platform Version” in PROD; emits events used to update Helm chart references.

### High-level Flow
1. Bootstrap cluster with `gitops/bootstrap/*` to configure Argo CD repository credentials for Helm repos and docker pull secrets in the `bookverse-prod` namespace.
2. Apply `gitops/projects/bookverse-prod.yaml` to define the PROD `AppProject`.
3. Create `gitops/apps/prod/platform.yaml` Argo CD `Application` pointing to `bookverse-helm/charts/platform` with the default `values.yaml`.
4. AppTrust designates a “Recommended Platform Version” for PROD; CI/CD opens a PR to update the chart version/image digest referenced by `values-prod.yaml`.
5. Merge PR → Argo CD reconciles and deploys to the `bookverse-prod` namespace.

### Environment Strategy (Demo Scope)
- **PROD (active)**: Auto-sync enabled. Deploy only AppTrust‑recommended Platform releases.
- **DEV/QA/STAGING (inactive for demo)**: No live cluster deploys. Referenced only to show potential structure.

### Branching and Versioning Model
- `bookverse-helm` uses semantic versioning for the `platform` chart.
- PROD tracks `main` with `values.yaml`. A change is permitted only when AppTrust emits a “Recommended Platform Version” event for PROD.
- CI opens a PR to update `values.yaml` chart version and/or image digest to the recommended version. Upon merge, Argo CD reconciles.
- Other environments are out of scope for this demo.

### Artifact Trust and Policy Controls
- Configure Argo CD repo credentials to JFrog Helm repos via `gitops/bootstrap/argocd-helm-repos.yaml`.
- Configure `kubernetes.io/dockerconfigjson` secrets per namespace via `gitops/bootstrap/docker-pull-secrets.yaml`.
- Policies (placeholder, not implemented in demo):
  - Images should come from `apptrustswampupc.jfrog.io` with immutable tags.
  - Prefer signed images and chart provenance files.
  - Avoid `latest` tags.

### Desired State Structure
- `gitops/`
  - `bootstrap/` → Argo CD repo and pull-secret configuration
  - `projects/` → Argo CD `AppProject` for PROD only (demo)
  - `apps/` → Argo CD `Application` for PROD only (demo)
  - `policies/` (optional) → OPA/Kyverno policies (placeholders only for demo)

### Synchronization Logic (Algorithms)
1. Reconciliation loop per Application (PROD only in demo):
   - Poll source (Git for charts definitions + Helm repo for charts) at interval `T`.
   - If `targetRevision` and Helm chart version resolve to a new digest:
     - Fetch manifests via `helm template` with `values.yaml`.
     - Run diff with live cluster objects.
     - If drift detected and auto-sync enabled, apply changes.
2. Drift handling algorithm (PROD only):
   - For each Kubernetes object under management:
     - Compute desired spec hash `Hdesired` and live spec hash `Hlive`.
     - If `Hdesired != Hlive`, mark OutOfSync.
     - If sync policy `automated` and in sync window, perform `kubectl apply`-equivalent.
3. Health checks (PROD only):
   - For each workload, evaluate readiness gates:
     - Deployments: minReadySeconds, available replicas.
     - Jobs/CronJobs: completion status.
     - Ingress/Services: endpoints availability.
   - Gate sync completion on health = Healthy.
4. Rollback algorithm (PROD only):
   - Identify last successful SyncRevision `Rprev`.
   - `argocd app rollback <app> --to-revision Rprev`.
   - Verify health post-rollback.

### Promotion Logic
1. CI builds image `repo/image@sha256:<digest>`, publishes to JFrog.
2. AppTrust marks a Platform release as “Recommended for PROD”.
3. CI/CD opens a PR against `bookverse-helm` to update `values.yaml` to the recommended chart/image version.
4. Merge PR → Argo CD deploys to PROD.

### Rollout Strategies
- Use a simple RollingUpdate in PROD for demo clarity. Optionally mention Blue/Green/Canary as future enhancement.

### Secrets Management
- Keep secrets minimal for demo. Use namespaced `Secret`s created in `bootstrap` and reference via `imagePullSecrets: [jfrog-docker-pull]`.
- Ensure mount/refs are captured in Helm values (e.g., `imagePullSecrets: [jfrog-docker-pull]`).

### Observability and SLOs
- Minimal observability for demo: ensure Argo CD app health and sync status are visible; optional alerts can be added later.

### Operational Runbooks
- Bootstrap (PROD only in demo):
  1. Apply `gitops/bootstrap/*`.
  2. Apply `gitops/projects/bookverse-prod.yaml`.
  3. Apply `gitops/apps/prod/platform.yaml`.
- Rotate credentials:
  - Update secrets in `bootstrap`; re-apply; confirm Argo CD repo connectivity and successful pulls.
- Emergency rollback:
  - Use Argo CD UI/CLI; rollback to last healthy revision; create follow-up issue.

### Future Enhancements
- Split platform into per-service Applications.
- Add Kyverno/Gatekeeper policies.
- Adopt Argo Rollouts for canary/blue-green.
- Add drift dashboards and SLOs.

### Acceptance Criteria
- PROD deploys successfully via Argo CD with auto-sync when a Recommended Platform Version is released.
- Changes flow via PRs only; no manual kubectl in managed namespace.
- Policies remain placeholders (not implemented) as per demo scope.
- Bootstrap and rollback procedures validated for PROD.


