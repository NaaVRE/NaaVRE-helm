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
  -f,--values           value file(s) for the values/ chart
  -s,--use-vlic-secrets use VLIC secrets (default: false)
  --include-labs        include values/virtual-labs/* (implied by --use-vlic-secrets)
  --no-dependency-build skip helm dependency build (WARNING: used improperly, this can
                        break deployments by deploying the wrong subchart versions)
  --dry-run             print the commands without running them
  -h,--help             print help and exit

Actions:
  repo-add              add repositories for subcharts of naavre/
  install-keycloak-operator   install the keycloak operator in the current namespace
  dependency-build      rebuild the naavre/charts/ directory based on the naavre/Chart.lock file
  dependency-update     update naavre/charts/ based on the contents of naavre/Chart.yaml
  lint                  lint values/ and naavre/ helm charts
  install               render values/ and create a new deployment of naavre/
  upgrade               render values/ and upgrade an existing deployment of naavre/
  rollback              rollback an existing deployment
  uninstall             uninstall an existing deployment
  template              render charts to values/rendered/ and naavre/rendered, for debug purposes
  diff [opts] BASE [HEAD]   show the difference between the rendered charts at both refs
      BASE, [HEAD]          git ref (HEAD defaults to the current working tree)
      --format text|md      output format (default: text)
      --keep                keep diff-tmp/
      --reuse               reuse diff-tmp/ if present

Action options:
  Passed to \`helm <action>\`
"

g_context=""
g_namespace=""
g_release_name="naavre"
g_value_files=()
g_use_vlic_secrets=0
g_include_labs=0
g_no_dependency_build=0
g_dry_run=0

g_diff_format="text"
g_diff_keep=0
g_diff_reuse=0
g_diff_base=""
g_diff_head=""
g_diff_tmp=""

g_allowed_actions=(
  "repo-add"
  "install-keycloak-operator"
  "dependency-build"
  "dependency-update"
  "lint"
  "install"
  "upgrade"
  "rollback"
  "uninstall"
  "template"
  "diff"
)
g_action=""


exit_error() {
  echo "$1"
  exit 1
}

run_cmd() {
  cmd="$1"
  echo "$cmd" >&2
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

gen_f_args() {
  f_args=""
  for file in "${g_value_files[@]}"; do
    f_args="$f_args -f \"$file\""
  done
  if [[ "$g_include_labs" -eq 1 || "$g_use_vlic_secrets" -eq 1 ]]; then
    f_args="\$($(gen_find_helm_value_files values/virtual-labs)) $f_args"
  fi
  echo "$f_args"
}

gen_helm_values_lint_cmd() {
  if [[ "$g_use_vlic_secrets" -eq 0 ]]; then
    echo "helm lint values/ $(gen_f_args)"
  else
    echo "helm secrets lint values/ $(gen_f_args)"
  fi
}

gen_helm_values_template_cmd() {
  local output_dir="${1:-"values/rendered"}"
  if [[ "$g_use_vlic_secrets" -eq 0 ]]; then
    echo "helm template $g_release_name values/ --output-dir "$output_dir" $(gen_f_args)"
  else
    echo "helm secrets template $g_release_name values/ --output-dir "$output_dir" $(gen_f_args)"
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
  cmd+=" && helm repo add $1 seaweedfs https://seaweedfs.github.io/seaweedfs/helm"
  echo "$cmd"
}

gen_helm_dependency_build() {
  if [[ $g_no_dependency_build -eq 0 ]]; then
    echo "helm dependency build $1 naavre"
  else
    echo "echo \"Skipping helm dependency build\""
  fi
}

gen_helm_dependency_update() {
  echo "helm dependency update $1 naavre"
}

gen_helm_naavre_lint_cmd() {
  echo "helm $(gen_helm_common_options) lint $1 naavre/ \$($(gen_find_helm_value_files values/rendered/values/templates))"
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

check_value_files() {
  if [[ ${#g_value_files[@]} -eq 0 ]]; then
    exit_error "No value file(s) provided. Provide them with -f <file.yaml>"
  fi
  error=0
  for value_file in "${g_value_files[@]}"; do
    if [[ ! -f "$value_file" ]]; then
      error=1
    fi
  done
  if [[ "$error" -ne 0 ]]; then
    exit_error "File(s) ${g_value_files[*]} not found."
  fi
}

check_all() {
  check_k8s
  check_value_files
  check_sops
}

diff_is_md() {
  [[ "$g_diff_format" == "md" ]]
}

diff_print_heading() {
  level="$1"
  msg="$2"
  if diff_is_md; then
    printf "\n%.*s %s\n\n" "$level" "######" "$msg"
  else
    printf "\n--%.*s %s\n\n" "$level" "------" "$msg"
  fi
}

diff_print_fence() {
  if diff_is_md; then
    echo "\`\`\`$1"
  fi
}

# git diff between two paths relative to $g_diff_tmp
diff_yaml() {
  local color="off"
  if ! diff_is_md && [[ -t 1 ]]; then
    color="on"
  fi
  (
    cd "$g_diff_tmp" &&
    dyff --color "$color" between "$@" --omit-header --output github
  )
}

# Prepare $g_diff_tmp/rendered/<side>
diff_prepare_side() {
  local side="$1" # base or head
  local ref="$2" # git ref, or "" for the working tree
  local src="$g_diff_tmp/src/$side"
  if [[ -z "$ref" ]]; then
    ln -s "$(git rev-parse --show-toplevel)" "$src"
  else
    git rev-parse --verify --quiet "$ref^{commit}" > /dev/null || exit_error "Invalid git ref: $ref"
    mkdir -p "$src"
    git archive "$ref" | tar -x -C "$src"
  fi
  (cd "$src" && run_cmd "$(gen_helm_dependency_build)") >&2 || exit_error "Could not build dependencies for $1"
}

# Render the charts of one side
diff_render_side() {
  local src_side="$1" # base or head
  local render_side="${2:-$src_side}"
  echo "Rendering $src_side" >&2
  (
    cd "$g_diff_tmp/src/$src_side" || exit 1
    for file in "${g_value_files[@]}"; do
      if [[ ! -f "$file" ]]; then
        echo "$file does not exist on $src_side ($(pwd))"
        exit 0
      fi
    done
    local render_dir="$g_diff_tmp/rendered/$render_side"
    run_cmd "rm -rf \"$render_dir\""
    run_cmd "mkdir -p \"$render_dir\""
    run_cmd "$(gen_helm_values_template_cmd)"
    run_cmd "$(gen_helm_naavre_template_cmd)"
    run_cmd "mv values/rendered/values \"$render_dir\""
    run_cmd "mv naavre/rendered/naavre \"$render_dir\""
  ) >&2 || exit_error "Could not render $side"
}

# Show diff dependencies diff for the naavre/ chart
diff_dependencies() {
  local side output
  for side in base head; do
    yq '.dependencies' "$g_diff_tmp/src/$side/naavre/Chart.yaml" > "$g_diff_tmp/$side-dependencies.yaml"
  done
  diff_print_heading 3 "naavre/ chart dependencies"
  output="$(diff_yaml base-dependencies.yaml head-dependencies.yaml)" || true
  if [[ -z "$output" ]]; then
    echo "Unchanged"
  else
    diff_print_fence "diff"
    echo "$output"
    diff_print_fence
  fi
}

# diff_yaml for a file of a rendered directory, excluding unstable keys
diff_yaml_stable() {
  local dir="$1" path="$2" from="$3" to="$4"
  local unstable="$g_diff_tmp/unstable/$dir/$path"
  local exclude_args=()
  if [[ -f "$unstable" ]]; then
    while read -r key; do
      exclude_args+=(--exclude "$key")
    done < "$unstable"
  fi
  diff_yaml "${exclude_args[@]}" "$from" "$to"
}

# Show or record the difference between rendered directories
diff_rendered_dir() {
  local mode="$1" # show or record_unstable
  local from_side="$2"
  local to_side="$3"
  local dir="${4%/}" # rendered directory
  local title="${5:-}"

  # Find changed files (format "<A|D|M>\t<path>")
  changes="$(cd "$g_diff_tmp/rendered" && git diff --no-index --no-renames --name-status "$from_side/$dir" "$to_side/$dir" | sed -E "s#($from_side|$to_side)/$dir/##")"

  # Record keys that differ between sides
  if [[ "$mode" == "record_unstable" ]]; then
    while IFS=$'\t' read -r status path; do
      if [[ "$status" != "M" ]]; then
        continue
      fi
      mkdir -p "$(dirname "$g_diff_tmp/unstable/$dir/$path")"
      # record the go-patch paths of unstable keys
      diff_yaml --use-go-patch-style "rendered/$from_side/$dir/$path" "rendered/$to_side/$dir/$path" |
        grep -oP '(?<=^@@ ).*(?= @@$)' > "$g_diff_tmp/unstable/$dir/$path" || true
    done <<< "$changes"
    return
  fi

  # Drop files whose only changes are unstable keys
  changes="$(while IFS=$'\t' read -r status path; do
    if [[ -z "$status" ]]; then
      continue
    elif [[ "$status" != "M" ]] || [[ ! -f "$g_diff_tmp/unstable/$dir/$path" ]] ||
      [[ -n "$(diff_yaml_stable "$dir" "$path" "rendered/base/$dir/$path" "rendered/head/$dir/$path")" ]]; then
      printf '%s\t%s\n' "$status" "$path"
    fi
  done <<< "$changes")"

  diff_print_heading 3 "$title"
  if [[ -z "$changes" ]]; then
    echo "Unchanged"
    return
  fi

  # Summary tree
  echo "$(grep -c . <<< "$changes") files changed:" \
    "$(grep -c ^A <<< "$changes") added," \
    "$(grep -c ^D <<< "$changes") deleted," \
    "$(grep -c ^M <<< "$changes") modified"
  echo
  diff_print_fence text
  awk -F '\t' '{ print $2 " [" $1"]" }' <<< "$changes" | tree --noreport --fromfile .
  diff_print_fence
  echo

  # Diff for each file
  while IFS=$'\t' read -r status path; do
    from="rendered/base/$dir/$path"
    to="rendered/head/$dir/$path"
    if [[ "$status" == "A" ]]; then
      from="/dev/null"
    fi
    if [[ "$status" == "D" ]]; then
      to="/dev/null"
    fi
    if diff_is_md; then
      echo "<details><summary><code>[$status] $path</code></summary>"
      echo
    else
      diff_print_heading 4 "[$status] $path"
    fi
    diff_print_fence diff
    diff_yaml_stable "$dir" "$path" "$from" "$to" || true
    diff_print_fence
    if diff_is_md; then
      echo
      echo "</details>"
    fi
    echo
  done <<< "$changes"
}

diff_cleanup() {
  if [ ! -n "$g_diff_tmp" ]; then
    rm -rf "$g_diff_tmp"
  fi
}

diff_main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --keep)
        g_diff_keep=1
        ;;
      --reuse)
        g_diff_reuse=1
        ;;
      --format)
        g_diff_format="$2"
        shift
        ;;
      -*)
        exit_error "Unknown diff option $1"
        ;;
      *)
        if [[ -n "$g_diff_head" ]]; then
          exit_error "Too many arguments for diff: $1"
        elif [[ -n "$g_diff_base" ]]; then
          g_diff_head="$1"
        else
          g_diff_base="$1"
        fi
        ;;
    esac
    shift
  done
  if [[ -z "$g_diff_base" ]]; then
    exit_error "Missing argument for diff: <base>"
  fi
  if [[ ! "$g_diff_format" =~ ^(text|md)$ ]]; then
    exit_error "Invalid format '$g_diff_format'"
  fi
  if [[ "$g_use_vlic_secrets" -eq 1 ]]; then
    exit_error "--use-vlic-secrets cannot be used with diff"
  fi
  if ! command -v tree > /dev/null; then
    exit_error "diff requires tree"
  fi
  if ! command -v dyff > /dev/null; then
    exit_error "diff requires dyff (https://github.com/homeport/dyff)"
  fi
  check_value_files

  g_diff_tmp="$(git rev-parse --show-toplevel)/diff-tmp/${g_diff_base//\//%2F}..${g_diff_head//\//%2F}"
  if [[ "$g_diff_reuse" -ne 1 ]]; then
    diff_cleanup
  fi
  if [[ ! -d "$g_diff_tmp" ]]; then
    mkdir -p "$g_diff_tmp/src"
    diff_prepare_side base "$g_diff_base"
    diff_prepare_side head "$g_diff_head"
  fi
  diff_render_side base
  diff_render_side head
  diff_render_side head head-rerender

  rm -rf "$g_diff_tmp/unstable"
  diff_rendered_dir record_unstable head head-rerender values/
  diff_rendered_dir record_unstable head head-rerender naavre/

  diff_print_heading 1 "Diff $g_diff_base..${g_diff_head:-(working tree)} with ${g_value_files[*]}"
  diff_dependencies
  diff_rendered_dir show base head values/ "naavre/ chart rendered manifests"
  diff_rendered_dir show base head naavre/ "values/ chart rendered manifests"

  if [[ "$g_diff_keep" -ne 1 ]]; then
    diff_cleanup
  fi
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
      --include-labs)
        g_include_labs=1
        shift
        ;;
      --no-dependency-build)
        g_no_dependency_build=1
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
    lint)
      check_value_files
      check_sops
      run_cmd "$(gen_helm_dependency_build)"
      run_cmd "$(gen_helm_values_lint_cmd)"
      run_cmd "$(gen_helm_values_template_cmd)"
      trap 'run_cmd "$(gen_rm_values_cmd)"' exit
      run_cmd "$(gen_helm_naavre_lint_cmd "$action_options")"
      ;;
    install)
      check_all
      run_cmd "$(gen_helm_dependency_build)"
      run_cmd "$(gen_helm_values_template_cmd)"
      trap 'run_cmd "$(gen_rm_values_cmd)"' exit
      run_cmd "$(gen_helm_naavre_install_cmd "$action_options")"
      ;;
    upgrade)
      check_all
      run_cmd "$(gen_helm_dependency_build)"
      run_cmd "$(gen_helm_values_template_cmd)"
      trap 'run_cmd "$(gen_rm_values_cmd)"' exit
      run_cmd "$(gen_helm_naavre_upgrade_cmd "$action_options")"
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
      check_value_files
      check_sops
      run_cmd "$(gen_helm_values_template_cmd)"
      run_cmd "$(gen_helm_naavre_template_cmd "$action_options")"
      if [[ "$g_use_vlic_secrets" -eq 1 ]]; then
        echo
        echo "@@@@@@@@@@@@@@@@@    The files rendered to values/rendered/ and"
        echo "@@@ IMPORTANT @@@    naavre/rendered/ may contain unencrypted"
        echo "@@@@@@@@@@@@@@@@@    secrets. Clean them up after use!"
      fi
      ;;
    diff)
      diff_main "$@"
      ;;
  esac

}

main "$@"
