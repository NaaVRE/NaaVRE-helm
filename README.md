# NaaVRE-helm

## Deployment

NaaVRE consists of several sub-charts, whose values need to be derived from a root values file.
This is not directly supported by Helm, so deployment is done in two steps:

- **Step 1:** render values for the sub-charts, using the `values` chart
  - copy the example root values
    ```shell
    cp ./values/values-example-basic.yaml ./root-values/values-my-deployment.yaml
    ```
  - fill in your values
    ```shell
    vim ./root-values/values-my-deployment.yaml
    ```
  - render the `values` chart
    ```shell
    helm template values/ --output-dir values/rendered -f ./root-values/values-my-deployment.yaml
    ```
    > Note: never edit files in `values/rendered`. Instead, change `./root-values/values-my-deployment.yaml` or `values/templates/*.yaml` and re-render the `values` chart.


- **Step 2:** Deploy the sub-charts, using the `naavre` chart and the previously-rendered values.
  - get subcharts
  ```shell
  helm dependency build naavre
  ```
  - deploy subcharts
  ```shell
  helm -n naavre upgrade --create-namespace --install naavre naavre/ $(find values/rendered/values/templates -type f | xargs -I{} echo -n " -f {}")
  ```

## Uninstall

```shell
helm -n naavre uninstall naavre
```

## Advanced setups

### Run a command before starting Jupyter Lab

This shows how to run a command before starting a user's Jupyter Lab instance in the singleuser pod. This is useful to, e.g., add cells to the local cell catalogue (`~/NaaVRE/NaaVRE_db.json`). Unlike kubernetes' `postStart` lifecycle hook which is asynchronous, this method makes it possible to run commands before calling the container's entrypoint.

```yaml
jupyterhub:
  singleuser:
    lifecycleHooks: null
  vlabs:
    - slug: example-lab
      title: "Example"
      description: "Example"
      image:
        name: qcdis/n-a-a-vre
        tag: v2.6.0
      GitHubRepoNaaVRECells:
        url: "<Repo created from template https://github.com/QCDIS/NaaVRE-cells>"
        token: "<Token generated following the instructions from the template>"
      cmd:
        - "sh"
        - "-c"
        - |
          /tmp/init_script.sh
          echo "this runs before starting Jupyter Lab"
          # ... modify 
          /usr/local/bin/start-jupyter-venv.sh
```

In this example, the synchronous command runs after `/tmp/init_script.sh` which initializes user's database (`~/NaaVRE/NaaVRE_db.json`), and before `/usr/local/bin/start-jupyter-venv.sh` which starts Jupyter Lab.
These scripts should be explicitly included in `jupyterhub.vlabs[*].cmd` as shown here.
If the command does require the database to be initialized, `/tmp/init_script.sh` can be omitted.

> [!IMPORTANT]
> If `/tmp/init_script.sh` is included in the synchronous command, the lifecycle hooks must be disabled by explicitly setting `jupyterhub.singleuser.lifecycleHooks: null` (otherwise, the script runs twice which can corrupt the user's database).
> In this case, all virtual labs must have a `cmd` that includes `/tmp/init_script.sh`.

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

## Limitations

- Assumes that all components are served from one domain
- Assumes that everything runs within a single k8s namespace
- Assumes it is the only NaaVRE instance running in said namespace
- Assumes that the [Ingress NGINX Controller](https://kubernetes.github.io/ingress-nginx/) is deployed on the cluster
- Does not deploy monitoring (see https://github.com/QCDIS/infrastructure/blob/main/doc/monitoring.md)
- Does not configure pod affinities (see https://github.com/QCDIS/infrastructure/blob/main/doc/pod-affinities.md)
- Does support argo workflow artifacts
