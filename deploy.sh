#!/usr/bin/env bash
# Deploys the replica domain controller template with the Azure CLI.
# Works locally (after `az login`) or in Azure Cloud Shell (Bash).
#
# The DSC archive is pulled from _artifactsLocation in the parameters file (the GitHub repo).
# To test local DSC changes before pushing them, use Deploy-AzureResourceGroup.ps1 -UploadArtifacts.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") -g <resource-group> -l <location> [options]

  -g  Resource group name (created if it doesn't exist)
  -l  Location, e.g. eastus
  -s  Subscription name or ID (defaults to the current az account)
  -f  Template file (default: azuredeploy.bicep)
  -p  Parameters file (default: azuredeploy.parameters.json)
  -v  Validate only
  -w  What-if: preview changes without deploying
  -h  Show this help
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
resource_group=""
location=""
subscription=""
template_file="$script_dir/azuredeploy.bicep"
parameters_file="$script_dir/azuredeploy.parameters.json"
mode="create"

while getopts "g:l:s:f:p:vwh" opt; do
  case "$opt" in
    g) resource_group="$OPTARG" ;;
    l) location="$OPTARG" ;;
    s) subscription="$OPTARG" ;;
    f) template_file="$OPTARG" ;;
    p) parameters_file="$OPTARG" ;;
    v) mode="validate" ;;
    w) mode="what-if" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

if [[ -z "$resource_group" || -z "$location" ]]; then
  usage
  exit 1
fi

if ! az account show --output none 2>/dev/null; then
  echo "Not signed in to Azure. Run 'az login' first." >&2
  exit 1
fi

if [[ -n "$subscription" ]]; then
  az account set --subscription "$subscription"
fi
echo "Subscription: $(az account show --query name --output tsv)"

if [[ "$(az group exists --name "$resource_group")" != "true" ]]; then
  echo "Creating resource group $resource_group in $location"
  az group create --name "$resource_group" --location "$location" --output none
fi

deployment_name="azuredeploy-$(date -u +%m%d-%H%M)"

case "$mode" in
  validate)
    az deployment group validate \
      --resource-group "$resource_group" \
      --template-file "$template_file" \
      --parameters "@$parameters_file" \
      --output none
    echo "Template is valid."
    ;;
  what-if)
    az deployment group what-if \
      --resource-group "$resource_group" \
      --template-file "$template_file" \
      --parameters "@$parameters_file"
    ;;
  create)
    echo "Starting deployment $deployment_name (domain controller promotion can take 30+ minutes)"
    az deployment group create \
      --name "$deployment_name" \
      --resource-group "$resource_group" \
      --template-file "$template_file" \
      --parameters "@$parameters_file" \
      --query "properties.outputs.domainControllers.value" \
      --output table
    ;;
esac
