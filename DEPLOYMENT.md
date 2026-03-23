# Deployment

VLIC-managed deployments are automatically updated from the `main` branch, either on commits (to `k8s-test-1`) or on releases (to `k8s-staging-1`).
On these events, the `deploy.yaml` action run with permission to decrypt secrets, connect to the relevant k8s cluster, and use helm.

### Environments

The `deploy.yaml` action is run by either `deploy-k8s-test-1.yaml` or `deploy-k8s-staging-1.yaml`, environments `deploy/k8s-test-1` or `deploy/k8s-staging-1`, respectively.
These environments contain the configuration and secrets needed for the deployment. This includes SSH and kubeconfig credentials.

### Secrets decryption

Secrets are decrypted with AWS KMS. The `deploy.yaml` action authenticates through OIDC and assumes a role that can be accessed through the `deploy/*` environment. When run from other contexts, the `deploy.yaml` action is not authorized to decrypt secrets.

The full setup is documented here: https://github.com/QCDIS/infrastructure/blob/main/secrets/README.md#aws-kms-setup-for-ci
