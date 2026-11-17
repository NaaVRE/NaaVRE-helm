set -euo pipefail


VALUES_DIR="values"

run_diff() {
  name="$1"
  shift
  rc=0
  ./deploy.sh "$@" diff "origin/$BASE_REF" --keep --reuse --format md > "diffs/$name.md" 2> "diffs/$name.log" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    if grep -q '^@@ ' "diffs/$name.md"; then
      echo "$name changed" | tee -a diffs/status
    else
      echo "$name unchanged" | tee -a diffs/status
    fi
  else
    echo "$name failed" | tee -a diffs/status
    cat diffs/$name.log
  fi
}

mkdir -p diffs
: > diffs/status
./deploy.sh repo-add

# Paired values-{public,secrets}.yaml files
find "${VALUES_DIR}" -maxdepth 1 -name "values-*.public.yaml" \
| while read -r public_file; do
  secrets_file="${public_file%.public.yaml}.secrets.yaml"
  if [[ ! -f "$secrets_file" ]]; then
    echo "Public file has no matching secrets file:"
    echo "  public file: $public_file"
    echo "  missing secrets file: $secrets_file"
    echo "Create file $secrets_file, or rename $public_file to ${public_file%.public.yaml}.yaml"
    exit 1
  fi
  echo "--- Comparing charts with values: $public_file $secrets_file"
  name="$(basename "${public_file%.public.yaml}")"
  run_diff "$name" --include-labs -f "$secrets_file" -f "$public_file"
done

# Standalone files
find "${VALUES_DIR}" -maxdepth 1 -name "values-*.yaml" ! -name "*.public.yaml" ! -name "*.secrets.yaml" \
| while read -r values_file; do
  echo "--- Comparing charts with values: $values_file"
  name="$(basename "${values_file%.yaml}")"
  run_diff "$name" -f "$values_file"
done
