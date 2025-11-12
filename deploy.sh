#!/bin/bash

set -e

g_usage="Usage: ./deploy.sh [options] [action] [action options]

Summary:
  Manage NaaVRE deployments with helm:
  * run \`helm template\` on the \`values/\` chart (install and upgrade only)
  * run \`helm <action>\` on the \`naavre/\` chart

Options:
  --kube-context        Kubernetes context (default: \"\")
  -n,--namespace        Kubernetes namespace (default: \"\")
  -r,--release-name     helm release name (default: \"naavre\")
  -f,--values           value file(s) for the values/ chart (default: guess
                        from --kube-context and --use-vlic-secrets)
  -s,--use-vlic-secrets use VLIC secrets (default: false)
  --dry-run             print the commands without running them
  -h,--help             print help and exit

Actions:
  repo-add              add repositories for subcharts of naavre/
  install-keycloak-operator   install the keycloak operator in the current namespace
  dependency-build      rebuild the naavre/charts/ directory based on the naavre/Chart.lock file
  dependency-update     update naavre/charts/ based on the contents of naavre/Chart.yaml
  install               render values/ and create a new deployment of naavre/
  upgrade               render values/ and upgrade an existing deployment of naavre/
  rollback              rollback an existing deployment
  uninstall             uninstall an existing deployment
  template              render charts to values/rendered/ and naavre/rendered, for debug purposes

Action options:
  Passed to \`helm <action>\`
"

g_context=""
g_namespace=""
g_release_name="naavre"
g_value_files=()
g_use_vlic_secrets=0
g_dry_run=0

g_allowed_actions=(
  "repo-add"
  "install-keycloak-operator"
  "dependency-build"
  "dependency-update"
  "install"
  "upgrade"
  "rollback"
  "uninstall"
  "template"
)
g_action=""


exit_error() {
  echo "$1"
  exit 1
}

run_cmd() {
  cmd="$1"
  echo "$cmd"
  if [[ "$g_dry_run" -eq 0 ]]; then
    bash -c "$cmd"
  fi
}

gen_kubectl_cmd() {
  if [[ -n "$g_context" ]]; then
    cmd="kubectl --context $g_context"
  else
    cmd="kubectl"
  fi
  echo "$cmd"
}

gen_find_helm_value_files() {
  dir="$1"
  echo "find $dir -type f -exec echo -n \" -f {}\" ';'"
}

gen_kubectl_common_options() {
  options=""
  if [[ -n "$g_context" ]]; then
    options="$options --context $g_context"
  fi
  if [[ -n "$g_namespace" ]]; then
    options="$options --namespace $g_namespace"
  fi
  echo "$options"
}

gen_helm_common_options() {
  options=""
  if [[ -n "$g_context" ]]; then
    options="$options --kube-context $g_context"
  fi
  if [[ -n "$g_namespace" ]]; then
    options="$options --namespace $g_namespace"
  fi
  echo "$options"
}

gen_helm_values_template_cmd() {
  f_args=""
  for file in "${g_value_files[@]}"; do
    f_args="$f_args -f \"$file\""
  done
  if [[ "$g_use_vlic_secrets" -eq 0 ]]; then
    echo "helm template $g_release_name values/ --output-dir values/rendered $f_args"
  else
    echo "helm secrets template $g_release_name values/ --output-dir values/rendered \$($(gen_find_helm_value_files values/virtual-labs)) $f_args"
  fi
}

gen_kubectl_create_namespace() {
  echo "kubectl $(gen_kubectl_common_options) create ns \"$g_namespace\" || echo 'continuing'"
}

gen_kubectl_install_keycloak_operator() {
  keycloak_version="26.4.2"
  cmd="kubectl $(gen_kubectl_common_options) apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/$keycloak_version/kubernetes/keycloaks.k8s.keycloak.org-v1.yml"
  cmd+=" && kubectl $(gen_kubectl_common_options) apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/$keycloak_version/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml"
  cmd+=" && kubectl $(gen_kubectl_common_options) apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/$keycloak_version/kubernetes/kubernetes.yml"
  echo "$cmd"
}

gen_helm_repo_add() {
  cmd="helm repo add $1 argo https://argoproj.github.io/argo-helm"
  cmd+=" && helm repo add $1 jupyterhub https://jupyterhub.github.io/helm-chart/"
  cmd+=" && helm repo add $1 bitnami https://charts.bitnami.com/bitnami"
  echo "$cmd"
}

gen_helm_dependency_build() {
  echo "helm dependency build $1 naavre"
}

gen_helm_dependency_update() {
  echo "helm dependency update $1 naavre"
}

gen_helm_naavre_install_cmd() {
  echo "helm $(gen_helm_common_options) install $1 $g_release_name naavre/ \$($(gen_find_helm_value_files values/rendered/values/templates))"
}

gen_helm_naavre_upgrade_cmd() {
  echo "helm $(gen_helm_common_options) upgrade $1 $g_release_name naavre/ \$($(gen_find_helm_value_files values/rendered/values/templates))"
}

gen_helm_naavre_template_cmd() {
  echo "helm $(gen_helm_common_options) template $1 $g_release_name naavre/ \$($(gen_find_helm_value_files values/rendered/values/templates)) --output-dir naavre/rendered"
}

gen_helm_rollback_cmd() {
  echo "helm $(gen_helm_common_options) rollback $g_release_name $1"
}

gen_helm_uninstall_cmd() {
  echo "helm $(gen_helm_common_options) uninstall $1 $g_release_name"
}

gen_rm_values_cmd() {
  echo "rm -r values/rendered/"
}

check_k8s() {
  cmd="$(gen_kubectl_cmd) version"
  msg="Could run command \`$cmd\`, check your Kubernetes configuration"
  run_cmd "$cmd" > /dev/null || exit_error "$msg"
}

check_sops() {
  if [[ "$g_use_vlic_secrets" -eq 1 ]]; then
    cmd="sops decrypt values/values-deploy-k8s-test-1.secrets.yaml"
    msg="Could run command \`$cmd\`, check your SOPS configuration"
    run_cmd "$cmd" > /dev/null || exit_error "$msg"
  fi
}

set_default_value_files() {
  if [[ ${#g_value_files[@]} -eq 0 ]]; then
    if [[ "$g_use_vlic_secrets" -eq 0 ]]; then
      g_value_files=(
        "./values/values-deploy-$g_context.yaml"
      )
    else
      g_value_files=(
        "./values/values-deploy-$g_context.public.yaml"
        "./values/values-deploy-$g_context.secrets.yaml"
      )
    fi
  fi
}

check_value_files() {
  error=0
  for value_file in "${g_value_files[@]}"; do
    if [[ ! -f "$value_file" ]]; then
      error=1
    fi
  done
  if [[ "$error" -ne 0 ]]; then
    exit_error "File(s) ${g_value_files[*]} not found, check context configuration and --use-vlic-secrets option"
  fi
}

check_all() {
  check_k8s
  check_value_files
  check_sops
}

main() {

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        echo "$g_usage"
        exit 0
        ;;
      --kube-context)
        g_context="$2"
        shift 2
        ;;
      -n|--namespace)
        g_namespace="$2"
        shift 2
        ;;
      -r|--release-name)
        g_release_name="$2"
        shift 2
        ;;
      -f|--values)
        g_value_files+=("$2")
        shift 2
        ;;
      -s|--use-vlic-secrets)
        g_use_vlic_secrets=1
        shift
        ;;
      --dry-run)
        g_dry_run=1
        shift
        ;;
      -*)
        echo "Unknown option $1"
        exit 1
        ;;
      *)
        g_action="$1"
        if [[ ! " ${g_allowed_actions[*]} " =~ $g_action ]]; then
          echo "Invalid action '$g_action'"
        exit 1
        fi
        shift
        break
        ;;
    esac
  done

  action_options="$*"

  set_default_value_files

  case "$g_action" in
    repo-add)
      run_cmd "$(gen_helm_repo_add "$action_options")"
      ;;
    install-keycloak-operator)
      run_cmd "$(gen_kubectl_create_namespace)"
      run_cmd "$(gen_kubectl_install_keycloak_operator)"
      ;;
    dependency-build)
      run_cmd "$(gen_helm_dependency_build "$action_options")"
      ;;
    dependency-update)
      run_cmd "$(gen_helm_dependency_update "$action_options")"
      ;;
    install)
      check_all
      run_cmd "$(gen_helm_dependency_build)"
      run_cmd "$(gen_helm_values_template_cmd)"
      run_cmd "$(gen_helm_naavre_install_cmd "$action_options") ; $(gen_rm_values_cmd)"
      ;;
    upgrade)
      check_all
      run_cmd "$(gen_helm_dependency_build)"
      run_cmd "$(gen_helm_values_template_cmd)"
      run_cmd "$(gen_helm_naavre_upgrade_cmd "$action_options") ; $(gen_rm_values_cmd)"
      ;;
    rollback)
      check_k8s
      run_cmd "$(gen_helm_rollback_cmd "$action_options")"
      ;;
    uninstall)
      check_k8s
      run_cmd "$(gen_helm_uninstall_cmd "$action_options")"
      ;;
    template)
      run_cmd "$(gen_helm_values_template_cmd)"
      run_cmd "$(gen_helm_naavre_template_cmd "$action_options")"
      if [[ "$g_use_vlic_secrets" -eq 1 ]]; then
        echo
        echo "@@@@@@@@@@@@@@@@@    The files rendered to values/rendered/ and"
        echo "@@@ IMPORTANT @@@    naavre/rendered/ may contain unencrypted"
        echo "@@@@@@@@@@@@@@@@@    secrets. Clean them up after use!"
      fi
      ;;
  esac

}

main "$@"
