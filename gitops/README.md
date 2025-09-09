## BookVerse GitOps (Demo)

This demo uses Argo CD to deploy only to PROD. Deployments occur when AppTrust designates a Platform release as "Recommended for PROD" and CI/CD updates the Helm values accordingly.

### Flow
1. AppTrust marks a Platform version as Recommended for PROD.
2. CI/CD opens a PR in `bookverse-helm` to update `charts/platform/values.yaml` (chart version and/or image digest).
3. Merge PR → Argo CD auto-syncs `apps/prod/platform.yaml` to the `bookverse-prod` namespace.

### Bootstrap (PROD only)
1. Apply `gitops/bootstrap/*`.
2. Apply `gitops/projects/bookverse-prod.yaml`.
3. Apply `gitops/apps/prod/platform.yaml`.

### Policies
Policies are placeholders for demo purposes and are not enforced. See `gitops/policies/` for notes.


