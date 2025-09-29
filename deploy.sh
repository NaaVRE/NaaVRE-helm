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
  -s,--use-vlic-secrets use VLIC secrets (default: false)
  --dry-run             print the commands without running them
  -h,--help             print help and exit

Actions:
  repo-add              add repositories for subcharts of naavre/
  dependency-build      rebuild the naavre/charts/ directory based on the naavre/Chart.lock file
  dependency-update     update naavre/charts/ based on the contents of naavre/Chart.yaml
  install               render values/ and create a new deployment of naavre/
  upgrade               render values/ and upgrade an existing deployment of naavre/
  rollback              rollback an existing deployment
  uninstall             uninstall an existing deployment
  template              render values/ to values/rendered/, for debug purposes

Action options:
  Passed to \`helm <action>\`
"

g_context=""
g_namespace=""
g_release_name="naavre"
g_use_vlic_secrets=0
g_dry_run=0

g_allowed_actions=(
  "repo-add"
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

gen_helm_template_cmd() {
  if [[ "$g_use_vlic_secrets" -eq 0 ]]; then
    echo "helm template $g_release_name values/ --output-dir values/rendered -f \"./values/values-deploy-$g_context.yaml\""
  else
    echo "helm secrets template $g_release_name values/ --output-dir values/rendered \$($(gen_find_helm_value_files values/virtual-labs)) -f \"./values/values-deploy-$g_context.public.yaml\" -f \"./values/values-deploy-$g_context.secrets.yaml\""
  fi
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

gen_helm_install_cmd() {
  echo "helm $(gen_helm_common_options) install $1 $g_release_name naavre/ \$($(gen_find_helm_value_files values/rendered/values/templates))"
}

gen_helm_upgrade_cmd() {
  echo "helm $(gen_helm_common_options) upgrade $1 $g_release_name naavre/ \$($(gen_find_helm_value_files values/rendered/values/templates))"
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

check_values_file() {
  if [[ "$g_use_vlic_secrets" -eq 0 ]]; then
    value_files=(
      "./values/values-deploy-$g_context.yaml"
    )
  else
    value_files=(
      "./values/values-deploy-$g_context.public.yaml"
      "./values/values-deploy-$g_context.secrets.yaml"
    )
  fi
  error=0
  for value_file in "${value_files[@]}"; do
    if [[ ! -f "$value_file" ]]; then
      error=1
    fi
  done
  if [[ "$error" -ne 0 ]]; then
    exit_error "File(s) ${value_files[*]} not found, check context configuration and --use-vlic-secrets option"
  fi
}

check_all() {
  check_k8s
  check_values_file
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

  case "$g_action" in
    repo-add)
      run_cmd "$(gen_helm_repo_add "$action_options")"
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
      run_cmd "$(gen_helm_template_cmd)"
      run_cmd "$(gen_helm_install_cmd "$action_options") ; $(gen_rm_values_cmd)"
      ;;
    upgrade)
      check_all
      run_cmd "$(gen_helm_dependency_build)"
      run_cmd "$(gen_helm_template_cmd)"
      run_cmd "$(gen_helm_upgrade_cmd "$action_options") ; $(gen_rm_values_cmd)"
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
      run_cmd "$(gen_helm_template_cmd)"
      if [[ "$g_use_vlic_secrets" -eq 1 ]]; then
        echo
        echo "@@@@@@@@@@@@@@@@@    The files rendered to values/rendered/"
        echo "@@@ IMPORTANT @@@    may contain unencrypted secrets."
        echo "@@@@@@@@@@@@@@@@@    Clean them up after use!"
      fi
      ;;
  esac

}

main "$@"
