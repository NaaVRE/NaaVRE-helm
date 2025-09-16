# NaaVRE-helm

## Overview

NaaVRE consists of several components which have their own Helm charts (Keycloak, Argo, Jupyter Hub, NaaVRE-PaaS-frontend, all NaaVRE-*-services and more).
They are all sub-charts of the `naavre` chart.

However, Helm requires to set values for all sub-charts manually.
This is time-consuming, error-prone, and results in a lot of duplicate configurations (e.g. repeated domain names or internal tokens).

To address this issue, we first render sub-chart values through the `values` chart.
This allows us to render sub-chart values from a single file without duplicate configurations.

The deployment is done in two steps:

- **Step 1:** render values for the sub-charts, using the `values` chart
- **Step 2:** Deploy the sub-charts, using the `naavre` chart and the previously-rendered values.

![Deployment overview](docs/deployment-overview.drawio.png)

## Deployment

Deployments are managed with [deploy.sh](deploy.sh):

```shell
./deploy.sh --help
```

> [!TIP]
> Whenever you run `deploy.sh`, you can add `--dry-run` to print the commands without running them:
> ```shell
> ./deploy.sh --dry-run <action>
> ```

### Initial setup

Add the third-party Helm repos:

```shell
./deploy.sh repo-add
```

Download the sub-charts:

```shell
./deploy.sh dependency-build
```

### Additional initial setup for VLIC team members

Configure Kubernetes access following the [internal documentation](https://github.com/QCDIS/infrastructure/blob/main/doc/kubernetes/deployment-from-laptop.md).
The configuration is successful when you can run `kubectl` locally with the desired context:

```shell
kubectl --context k8s-test-1 get ns new-naavree
```

Configure SOPS to decode VLIC secrets following the [internal documentation](https://github.com/QCDIS/infrastructure/blob/main/secrets/README.md).
Don't forget to set the `AWS_PROFILE` environment variable for the project and to run `aws sso login --profile ...` before running `deploy.sh`.
The configuration is successful when you can decrypt SOPS files:
```shell
sops decrypt values/values-deploy-k8s-test-1.secrets.yaml
```

Install `helm-secrets`:

```shell
helm plugin install https://github.com/jkroepke/helm-secrets
```

### Manage existing deployments

> [!IMPORTANT]
> For VLIC-managed deployments, run the following commands before `deploy.sh`:
> * `ssh -TL 127.0.1.<x>:6443:localhost:6443 <context>` ([internal documentation](https://github.com/QCDIS/infrastructure/blob/main/doc/kubernetes/deployment-from-laptop.md#open-the-ssh-tunnel))
> * `aws sso login --profile <profile name>` ([internal documentation](https://github.com/QCDIS/infrastructure/blob/main/secrets/README.md#reading-and-editing-files))
> * `git checkout main && git pull`

#### Install or upgrade

To install or upgrade an existing deployment, use:

```shell
./deploy.sh --kube-context <deployment name> -n <namespace> [--use-vlic-secrets] upgrade --install
```

For example, to install or upgrade the `minikube` deployment ([values/values-deploy-minikube.yaml](values/values-deploy-minikube.yaml)), run:

```shell
./deploy.sh --kube-context minikube -n new-naavre upgrade --install
```

To install or upgrade the `k8s-test-1` deployment ([values/values-deploy-k8s-test-1.public.yaml](values/values-deploy-k8s-test-1.public.yaml) and [values/values-deploy-k8s-test-1.secrets.yaml](values/values-deploy-k8s-test-1.secrets.yaml)), run:

```shell
./deploy.sh --kube-context k8s-test-1 -n new-naavre --use-vlic-secrets upgrade --install --timeout 30m
```

Adjust the value of `--timeout` if you get the error message `Error: UPGRADE FAILED: pre-upgrade hooks failed: 1 error occurred: * timed out waiting for the condition`.

#### Rollback

To rollback an existing deployment, use:

```shell
./deploy.sh --kube-context <deployment name> -n <namespace> rollback [REVISION]
```

Examples:

```shell
./deploy.sh --kube-context minikube -n new-naavre rollback
./deploy.sh --kube-context k8s-test-1 -n new-naavre rollback 1
```

#### Uninstall

To uninstall an existing deployment, use:

```shell
./deploy.sh --kube-context <deployment name> -n <namespace> uninstall
```

Examples:

```shell
./deploy.sh --kube-context minikube -n new-naavre uninstall
./deploy.sh --kube-context k8s-test-1 -n new-naavre uninstall
```

### Create a new deployment

#### Without VLIC secrets

Create a new root values file and fill in your values. This can be done by copying one of the examples:

```shell
cp values/values-example-basic.yaml values/values-deploy-my-k8s-context.yaml
vim values/values-deploy-my-k8s-context.yaml
```

> [!CAUTION]
> Values files (`values/values-deploy-*.yaml`) contain secrets. They are ignored by default by Git. Never commit them!

#### With VLIC secrets

A deployment consists of two files:

- `values/values-deploy-<context>.public.yaml` (clear text)
- `values/values-deploy-<context>.secrets.yaml` (SOPS-encrypted)

For VLIC-managed deployments, virtual labs are defined in separate files placed in `values/virtual-labs/`. Labels are defined in `values/virtual-labs/labels.yaml`. As for deployments, a virtual lab definition consist of two files:

- `values/virtual-labs/values-<vl-slug>.public.yaml`
- `values/virtual-labs/values-<vl-slug>.secrets.yaml`

Virtual labs are disabled by default. To activate a virtual lab for a deployment, set `jupyterhub.vlabs.<slug>.enabled: true` in `values/values-deploy-<context>.public.yaml`

Clear-text files should only contain public values. Secrets should be stored in the SOPS-encrypted files (typically, everything under `global.secrets`, as well as sensitive values under `global.externalServices` and `jupyterhub.vlabs.*`). Both files can safely commited to Git.

To create or edit a SOPS-encrypted file, run:

```shell
helm secrets edit my-file.secrets.yaml
```

Or in Pycharm using the [Simple Sops Edit plugin](https://plugins.jetbrains.com/plugin/21317-simple-sops-edit) (read our [documentation](https://github.com/QCDIS/infrastructure/blob/main/secrets/README.md#pycharm-integration)).

## Maintenance

To update sub-charts versions, edit [naavre/Chart.yaml](naavre/Chart.yaml) and run

```shell
./deploy.sh dependency-update
```

to update [naavre/Chart.lock](naavre/Chart.lock).

## Advanced setups

### Add MinIO mount to user home directory 

To add MinIO mounts to the user's home directory, you can use the `extraVolumes` and `extraVolumeMounts` options in the Jupyter Hub configuration.
This is an example of how to add a MinIO mount to the user's home directory:
[values-example-mount-minio-buckets.yaml](values/values-example-mount-minio-buckets.yaml)


### Run a command after starting Jupyter Lab

This shows how to run a command after starting a user's Jupyter Lab instance in the singleuser pod. This is useful to, e.g., clone a Git repository.
For each virtual lab, you can provide a snippet that will be executed by
`sh -c` in Kubernetes' `postStart` hook.

```yaml
jupyterhub:
  vlabs:
    openlab:
      slug: openlab
      ...
      postStartShSnippet: |
        echo "Pulling some data"
        gitpuller https://github.com/user/repo.git main folder
```

### TLS certificates with cert-manager

This shows how to automatically provision TLS certificates with [cert-manager](https://cert-manager.io/).

1. Create an `Issuer` in the target namespace, or create a `ClusterIssuer` ([doc](https://cert-manager.io/docs/concepts/issuer/), [tutorial](https://cert-manager.io/docs/tutorials/acme/nginx-ingress/#step-6---configure-a-lets-encrypt-issuer)). We'll assume that the issuer is named `letsencrypt-prod`.

2. Add the following to the root values file:

```yaml
global:
  ingress:
    commonAnnotations:
      # if using a namespaced Issuer
      cert-manager.io/issuer: "letsencrypt-prod"
      # if using a ClusterIssuer
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      enabled: true
```

### Export Prometheus metrics

To export prometheus metrics, add the following to the root values file (generate a random token):

```yaml
jupyterhub:
  hub:
    extraConfig:
      prometheus.py: |
        c.JupyterHub.services += [{
          'name': 'service-prometheus',
          'api_token': '<a random token>',
          }]
        c.JupyterHub.load_roles += [{
          'name': 'service-metrics-role',
          'description': 'access metrics',
          'scopes': [ 'read:metrics'],
          'services': ['service-prometheus'],
          }]
```

### Customize the Jupyter Hub templates

To customize the Jupyter Hub templates ([doc](https://jupyterhub.readthedocs.io/en/stable/howto/templates.html)), add the following to the root values:

```yaml
jupyterhub:
  hub:
    initContainers:
      - name: git-clone-templates
        image: alpine/git
        args:
          - clone
          - --single-branch
          - --branch=lifeWatch-jh-4
          - --depth=1
          - --
          - https://github.com/QCDIS/k8s-jhub.git
          - /etc/jupyterhub/custom
        securityContext:
          runAsUser: 1000
        volumeMounts:
          - name: hub-templates
            mountPath: /etc/jupyterhub/custom
      - name: copy-static
        image: busybox:1.28
        command: ["sh", "-c", "mv /etc/jupyterhub/custom/static/* /usr/local/share/jupyterhub/static/external"]
        securityContext:
          runAsUser: 1000
        volumeMounts:
          - name: hub-templates
            mountPath: /etc/jupyterhub/custom
          - name: hub-static
            mountPath: /usr/local/share/jupyterhub/static/external
    extraVolumes:
      - name: hub-templates
        emptyDir: { }
      - name: hub-static
        emptyDir: { }
    extraVolumeMounts:
      - name: hub-templates
        mountPath: /etc/jupyterhub/custom
      - name: hub-static
        mountPath: /usr/local/share/jupyterhub/static/external
    extraConfig:
      templates.py: |
        c.JupyterHub.template_paths = ['/etc/jupyterhub/custom/templates']
```

### Schedule Jupyter user pods on dedicated set nodes

This shows how to schedule Jupyter user pods on a dedicated set of nodes, and to only pre-pull images on these nodes (see the [z2jh documentation](https://z2jh.jupyter.org/en/stable/administrator/optimization.html#using-a-dedicated-node-pool-for-users) for more).

1. Set the `hub.jupyter.org/node-purpose=user` on the target nodes. E.g. with kubectl:

   ```shell
   kubectl label nodes my-node-1 hub.jupyter. org/node-purpose=user
   kubectl label nodes my-node-2 hub.jupyter. org/node-purpose=user
   ```

2. Add the following to the root values:

   ```yaml
   jupyterhub:
     scheduling:
       userPods:
         nodeAffinity:
          matchNodePurpose: require
   ```

## Limitations

- Assumes that all components are served from one domain
- Assumes that everything runs within a single k8s namespace
- Assumes it is the only NaaVRE instance running in said namespace
- Assumes that the [Ingress NGINX Controller](https://kubernetes.github.io/ingress-nginx/) is deployed on the cluster
- Does not deploy monitoring (see https://github.com/QCDIS/infrastructure/blob/main/doc/monitoring.md)
- Does not configure pod affinities (see https://github.com/QCDIS/infrastructure/blob/main/doc/pod-affinities.md)
- Does support argo workflow artifacts
