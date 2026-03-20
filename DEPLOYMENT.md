# Deployment

VLIC-managed deployments are automatically updated when commits are pushed to the `deploy/*` branches. The `deploy.yaml` action running on these branches can decrypt secrets, connect to the relevant k8s cluster, and use helm.

To update a deployment, the `main` branch should be merged in the appropriate `deploy/` branch through a PR. Upon merging, the `deploy.yaml` action will update the changes.

The diagram below illustrates the creation and merging of a feature branch into `main`, followed by the deployment to `k8s-test-1` and later to `k8s-staging-1`.

```mermaid
---
config:
    gitGraph:
        mainBranchOrder: 3
---
gitGraph
    branch deploy/k8s-staging-1 order: 1
    branch deploy/k8s-test-1 order: 2

    checkout deploy/k8s-staging-1
    commit id: "staging-A"

    checkout deploy/k8s-test-1
    commit id: "test-A"

    checkout main
    commit id: "main-A"
    branch feature-1 order: 4
    commit id: "feat-A"
    commit id: "feat-B"
    commit id: "feat-C"
    checkout main
    merge feature-1 id: "merge feature-1"

    checkout deploy/k8s-test-1
    merge main id: "merge main in deploy/k8s-test-1"

    checkout deploy/k8s-staging-1
    merge main id: "merge main in deploy/k8s-staging-1"
```

### Branches protection

Branches `deploy/**/*` are protected by a ruleset, which enforces that changes be made through a PR with passing tests and approval.

### Environments

Each `deploy/*` branch has a matching environment, containing the configuration and secrets needed for the deployment. This includes SSH and kubeconfig credentials.

### Secrets decryption

Secrets are decrypted with AWS KMS. The `deploy.yaml` action authenticates through OIDC and assumes a role that can be accessed through the `deploy/*` environment. When run from other contexts, the `deploy.yaml` action is not authorized to decrypt secrets.

The full setup is documented here: https://github.com/QCDIS/infrastructure/blob/main/secrets/README.md#aws-kms-setup-for-ci