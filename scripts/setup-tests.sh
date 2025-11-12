#!/bin/bash

# The purpose of this script is to be used in a GitHub Actions workflow to set up a Minikube cluster for testing the individual NaaVRE service such as the /NaaVRE-workflow-servic, /NaaVRE-containerizer-service, etc.
# It assumes that Minikube is already installed and running, and that kubectl and helm are also installed.
# It adds minikube IP to /etc/hosts, adds the necessary Helm repositories, installs the NaaVRE Helm chart, and sets up the necessary environment variables for testing.

# Usage: ./setup-tests.sh -f <values-file>
# Example: ./setup-tests.sh -f values/minikube-values.yaml

# For example values file, see values/ in this repository.


set -e # Fail on any error

VALUES_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--values)
      VALUES_FILE="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -n "$VALUES_FILE" ]]; then
  echo "Using values file: $VALUES_FILE"
fi


# Get only the last part of the current directory
CURRENT_DIR=$(basename "$(pwd)")

# Variables
export MINIKUBE_HOST="naavre-dev.minikube.test"
export AUTH_TOKEN=""
export ARGO_TOKEN=""
export CLIENT_ID=naavre
echo "CLIENT_ID=naavre" >> $GITHUB_ENV
export USERNAME=my-user
echo "USERNAME=my-user" >> $GITHUB_ENV
export PASSWORD=USER_PASSWORD
echo "PASSWORD=USER_PASSWORD" >> $GITHUB_ENV
export DISABLE_OAUTH=False
echo "DISABLE_OAUTH=False" >> $GITHUB_ENV
export OIDC_CONFIGURATION_URL="https://$MINIKUBE_HOST/auth/realms/vre/.well-known/openid-configuration"
echo "OIDC_CONFIGURATION_URL=https://$MINIKUBE_HOST/auth/realms/vre/.well-known/openid-configuration" >> $GITHUB_ENV
export VERIFY_SSL="False"
echo "VERIFY_SSL=False" >> $GITHUB_ENV
export DISABLE_AUTH="False"
echo "DISABLE_AUTH=False" >> $GITHUB_ENV
export CONFIG_FILE_URL="$CURRENT_DIR/minkube_configuration.json"
echo "CONFIG_FILE_URL=$CURRENT_DIR/minkube_configuration.json" >> $GITHUB_ENV
export SECRETS_CREATOR_API_ENDPOINT="https://$MINIKUBE_HOST/k8s-secret-creator/1.0.0"
echo "SECRETS_CREATOR_API_ENDPOINT=https://$MINIKUBE_HOST/k8s-secret-creator/1.0.0" >> $GITHUB_ENV
export SECRETS_CREATOR_API_TOKEN="SECRETS_CREATOR_API_TOKEN"
echo "SECRETS_CREATOR_API_TOKEN=SECRETS_CREATOR_API_TOKEN" >> $GITHUB_ENV
export ARGO_SERVICE_ACCOUNT_EXECUTOR="argo-executor"
echo "ARGO_SERVICE_ACCOUNT_EXECUTOR=argo-executor" >> $GITHUB_ENV
export ARGO_VRE_API_SERVICE_ACCOUNT="argo-vreapi"
echo "ARGO_VRE_API_SERVICE_ACCOUNT=argo-vreapi" >> $GITHUB_ENV
export ARGO_SERCERT_TOKEN_NAME=argo-vreapi.service-account-token
echo "ARGO_SERCERT_TOKEN_NAME=argo-vreapi.service-account-token" >> $GITHUB_ENV

#Get the minikube IP and add it to /etc/hosts if not already present
MINIKUBE_IP=$(minikube ip)
export MINIKUBE_IP
if ! grep -q "$MINIKUBE_IP" /etc/hosts; then
    echo "Adding minikube IP to /etc/hosts"
    echo "$MINIKUBE_IP $MINIKUBE_HOST" | sudo tee -a /etc/hosts > /dev/null
else
    echo "Minikube IP already present in /etc/hosts"
fi

# Test $MINIKUBE_HOST
if ! curl -k https://$MINIKUBE_HOST | grep '<head><title>404 Not Found</title></head>'; then
    echo "Minikube local test failed"
    exit 1
else
    echo "Minikube local test passed"
fi


#Install argo workflows from NaaVRE-helm
git clone https://github.com/NaaVRE/NaaVRE-helm.git
cd NaaVRE-helm
# Add the third-party Helm repos
./deploy.sh repo-add
context="minikube"
namespace="naavre"
./deploy.sh --kube-context "$context" -n "$namespace" install-keycloak-operator
./deploy.sh --kube-context "$context" -n "$namespace" -f "$VALUES_FILE" install
# Exit if the installation fails
if [ $? -ne 0 ]; then
    echo "Helm installation failed"
    exit 1
else
    echo "Helm installation succeeded"
fi
cd ../

#Get user access token for the workflow service and set the environment variable AUTH_TOKEN
# Wait for https://$MINIKUBE_HOST/auth/realms/ vre/.well-known/openid-configuration to be available and fail if it is not available
echo "Waiting for OIDC configuration URL to be available"
timeout=200
start_time=$(date +%s)
while true; do
    if curl -k --silent --fail https://$MINIKUBE_HOST/auth/realms/vre/; then
        echo "OIDC configuration URL is available"
        break
    fi
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ $elapsed_time -ge $timeout ]; then
        echo "OIDC configuration URL is not available after 5 minutes"
        exit 1
    fi
    sleep 5
done

echo "Getting access token for the workflow service"
AUTH_TOKEN="$(curl -k -X POST https://$MINIKUBE_HOST/auth/realms/vre/protocol/openid-connect/token -H 'Content-Type: application/x-www-form-urlencoded'   -d 'grant_type=password' -d 'client_id=naavre'   -d 'username=my-user'   -d 'password=USER_PASSWORD'   -d 'scope=openid' | jq -r '.access_token')"
echo "Setting the AUTH_TOKEN environment variable"
export AUTH_TOKEN
echo "AUTH_TOKEN=$AUTH_TOKEN" >> $GITHUB_ENV


#Get Argo workflow summation token and set it to configuration.json
echo "Getting Argo workflow submission token"
ARGO_TOKEN="$(kubectl get secret ${ARGO_SERCERT_TOKEN_NAME} -o=jsonpath='{.data.token}' -n naavre | base64 --decode)"
export ARGO_TOKEN
# Wait for the Argo workflow service to be available
timeout=200
start_time=$(date +%s)
while true; do
    if curl -k --silent --fail https://$MINIKUBE_HOST/argowf/; then
        break
    fi
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ $elapsed_time -ge $timeout ]; then
        echo "Argo workflow service at " https://$MINIKUBE_HOST/argowf/ "is not available"
        # Find the pods that are not running in the naavre namespace and contain the word argo. Then print their status logs and describe them
        kubectl get pods -n $namespace | grep argo | grep -v Running
        for pod in $(kubectl get pods -n $namespace | grep argo | grep -v Running | awk '{print $1}'); do
            echo "Logs for pod $pod:"
            kubectl logs $pod -n $namespace
            echo "Describe for pod $pod:"
            kubectl describe pod $pod -n $namespace
        done
        exit 1
    fi
    sleep 5
done

# Test if the ARGO_TOKEN works on https://$MINIKUBE_HOST/argowf
status_code=$(curl -o /dev/null -s -w "%{http_code}" -k https://$MINIKUBE_HOST/argowf/api/v1/workflows/naavre -H "Authorization: Bearer $ARGO_TOKEN")
echo "Argo API returned status code $status_code"
if [ "$status_code" -ne 200 ]; then
    echo "Argo API returned status code $status_code"
    exit 1
fi

# Wait for the executor service account to be created
timeout=200
start_time=$(date +%s)
while true; do
    if kubectl get serviceaccount $ARGO_SERVICE_ACCOUNT_EXECUTOR -n naavre > /dev/null 2>&1; then
        echo "Service account $ARGO_SERVICE_ACCOUNT_EXECUTOR is available"
        break
    fi
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ $elapsed_time -ge $timeout ]; then
        echo "Service account $ARGO_SERVICE_ACCOUNT_EXECUTOR is not available"
        exit 1
    fi
    sleep 5
done

# Wait for $ARGO_VRE_API_SERVICE_ACCOUNT service account to be created
timeout=200
start_time=$(date +%s)
while true; do
    if kubectl get serviceaccount $ARGO_VRE_API_SERVICE_ACCOUNT -n naavre > /dev/null 2>&1; then
        echo "Service account $ARGO_VRE_API_SERVICE_ACCOUNT is available"
        break
    fi
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ $elapsed_time -ge $timeout ]; then
        echo "Service account $ARGO_VRE_API_SERVICE_ACCOUNT is not available"
        exit 1
    fi
    sleep 5
done

# if configuration.json exists add the values, else skip
if [ -f "configuration.json" ]; then
  jq --arg token "$ARGO_TOKEN" '.vl_configurations |= map(if .name == "virtual_lab_1" then .wf_engine_config.access_token = $token else . end)' configuration.json > tmp.json && mv tmp.json minkube_configuration.json
  # Set namespace in minkube_configuration.json in the virtual_lab_1
  jq --arg namespace "naavre" '.vl_configurations |= map(if .name == "virtual_lab_1" then .wf_engine_config.namespace = $namespace else . end)' minkube_configuration.json > tmp.json && mv tmp.json minkube_configuration.json
  # Set service_account in minkube_configuration.json in the virtual_lab_1
  jq --arg service_account "$ARGO_SERVICE_ACCOUNT_EXECUTOR" '.vl_configurations |= map(if .name == "virtual_lab_1" then .wf_engine_config.service_account = $service_account else . end)' minkube_configuration.json > tmp.json && mv tmp.json minkube_configuration.json
  # Set the cell_github_token in minkube_configuration.json in the virtual_lab_1
  jq --arg cell_github_token "$CELL_GITHUB_TOKEN" '.vl_configurations |= map(if .name == "virtual_lab_1" then .cell_github_token = $cell_github_token else . end)' minkube_configuration.json > tmp.json && mv tmp.json minkube_configuration.json
else
    echo "configuration.json does not exist, skipping update"
fi




# Export environment variables to dev3.env
echo "Exporting environment variables to dev3.env"
{
  echo "AUTH_TOKEN=$AUTH_TOKEN"
  echo "ARGO_TOKEN=$ARGO_TOKEN"
  echo "OIDC_CONFIGURATION_URL=$OIDC_CONFIGURATION_URL"
  echo "VERIFY_SSL=$VERIFY_SSL"
  echo "DISABLE_AUTH=$DISABLE_AUTH"
  echo "CONFIG_FILE_URL=$CONFIG_FILE_URL"
  echo "SECRETS_CREATOR_API_ENDPOINT=$SECRETS_CREATOR_API_ENDPOINT"
  echo "SECRETS_CREATOR_API_TOKEN=$SECRETS_CREATOR_API_TOKEN"
  echo "DISABLE_OAUTH=False"
  echo "CLIENT_ID=$CLIENT_ID"
  echo "USERNAME=$USERNAME"
  echo "PASSWORD=$PASSWORD"
} > dev3.env



