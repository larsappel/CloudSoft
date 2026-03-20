#!/bin/bash
set -euo pipefail

# ============================================================
# CloudSoft One-Click Deployment Script
# ============================================================

SUBSCRIPTION="ca0a7799-8e2e-4237-8616-8cc0e947ecd5"
RESOURCE_GROUP="rg-cloudsoft"
LOCATION="swedencentral"
GITHUB_OWNER="larsappel"
GITHUB_REPO_NAME="CloudSoft"
GITHUB_REPO="${GITHUB_OWNER}/${GITHUB_REPO_NAME}"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"

echo "============================================"
echo "  CloudSoft One-Click Deployment"
echo "============================================"

# ----------------------------------------------------------
# Step 1: Create GitHub repository
# ----------------------------------------------------------
echo ""
echo "[1/11] Creating GitHub repository..."
gh repo create "${GITHUB_REPO}" --public --description "CloudSoft Newsletter App" 2>/dev/null || echo "  Repository already exists."

# ----------------------------------------------------------
# Step 2: Initialize git and push code
# ----------------------------------------------------------
echo ""
echo "[2/11] Pushing code to GitHub..."
if ! git remote get-url origin &>/dev/null; then
    git remote add origin "https://github.com/${GITHUB_REPO}.git"
fi
git remote set-url origin "https://github.com/${GITHUB_REPO}.git"
git add -A
git commit -m "Deploy CloudSoft application" 2>/dev/null || echo "  No new changes to commit."
git branch -M main
git push -u origin main --force

# ----------------------------------------------------------
# Step 3: Generate runner registration token
# ----------------------------------------------------------
echo ""
echo "[3/11] Generating GitHub Actions runner token..."
RUNNER_TOKEN=$(gh api -X POST "repos/${GITHUB_REPO}/actions/runners/registration-token" --jq '.token')
echo "  Runner token obtained (expires in 1 hour)."

# ----------------------------------------------------------
# Step 4: Get latest runner version
# ----------------------------------------------------------
echo ""
echo "[4/11] Fetching latest GitHub Actions runner version..."
RUNNER_VERSION=$(gh api "repos/actions/runner/releases/latest" --jq '.tag_name' | sed 's/^v//')
echo "  Runner version: ${RUNNER_VERSION}"

# ----------------------------------------------------------
# Step 5: Set Azure subscription
# ----------------------------------------------------------
echo ""
echo "[5/11] Setting Azure subscription..."
az account set --subscription "${SUBSCRIPTION}"

# ----------------------------------------------------------
# Step 6: Create resource group
# ----------------------------------------------------------
echo ""
echo "[6/11] Creating resource group..."
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output none

# ----------------------------------------------------------
# Step 7: Deploy Bicep template
# ----------------------------------------------------------
echo ""
echo "[7/11] Deploying Azure infrastructure (this takes several minutes)..."
az deployment group create \
    --resource-group "${RESOURCE_GROUP}" \
    --template-file infra/main.bicep \
    --parameters \
        adminPublicKey="$(cat ${SSH_KEY_PATH})" \
        runnerToken="${RUNNER_TOKEN}" \
        githubRepo="${GITHUB_REPO}" \
        runnerVersion="${RUNNER_VERSION}" \
    --output none

# Retrieve outputs separately to avoid streaming issues
PROXY_IP=$(az deployment group show --resource-group "${RESOURCE_GROUP}" --name main --query 'properties.outputs.proxyPublicIp.value' -o tsv)
BASTION_IP=$(az deployment group show --resource-group "${RESOURCE_GROUP}" --name main --query 'properties.outputs.bastionPublicIp.value' -o tsv)
STORAGE_ACCOUNT=$(az deployment group show --resource-group "${RESOURCE_GROUP}" --name main --query 'properties.outputs.storageAccountName.value' -o tsv)

echo "  Proxy IP:        ${PROXY_IP}"
echo "  Bastion IP:      ${BASTION_IP}"
echo "  Storage Account: ${STORAGE_ACCOUNT}"

# ----------------------------------------------------------
# Step 8: Upload hero image to blob storage
# ----------------------------------------------------------
echo ""
echo "[8/11] Uploading hero image to blob storage..."
az storage blob upload \
    --account-name "${STORAGE_ACCOUNT}" \
    --container-name "images" \
    --name "hero.jpg" \
    --file "wwwroot/images/hero.jpg" \
    --auth-mode key \
    --overwrite \
    --output none

# ----------------------------------------------------------
# Step 9: Wait for cloud-init to complete on all VMs
# ----------------------------------------------------------
echo ""
echo "[9/11] Waiting for cloud-init to complete on all VMs..."

for VM_NAME in vm-bastion vm-proxy vm-app; do
    echo "  Waiting for ${VM_NAME}..."
    az vm run-command invoke \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${VM_NAME}" \
        --command-id RunShellScript \
        --scripts "cloud-init status --wait" \
        --output none
    echo "  ${VM_NAME}: cloud-init complete."
done

# ----------------------------------------------------------
# Step 10: Wait for self-hosted runner to come online
# ----------------------------------------------------------
echo ""
echo "[10/11] Waiting for self-hosted runner to come online..."

RUNNER_ONLINE=false
for i in $(seq 1 30); do
    RUNNER_COUNT=$(gh api "repos/${GITHUB_REPO}/actions/runners" --jq '.runners | map(select(.status == "online")) | length')
    if [ "${RUNNER_COUNT}" -gt 0 ]; then
        RUNNER_ONLINE=true
        echo "  Self-hosted runner is online!"
        break
    fi
    echo "  Attempt ${i}/30: Runner not yet online, waiting 10 seconds..."
    sleep 10
done

if [ "${RUNNER_ONLINE}" = false ]; then
    echo "  WARNING: Runner did not come online within 5 minutes."
    echo "  The deployment will continue — GitHub Actions will queue until the runner appears."
fi

# ----------------------------------------------------------
# Step 11: Trigger workflow and wait for completion
# ----------------------------------------------------------
echo ""
echo "[11/11] Triggering CI/CD workflow..."

# Push a small change to trigger the workflow (or use workflow_dispatch)
gh workflow run cicd.yaml --repo "${GITHUB_REPO}" 2>/dev/null || echo "  Triggering via push instead..."

# Wait for workflow to appear and complete
echo "  Waiting for workflow run to start..."
sleep 15

WORKFLOW_COMPLETE=false
for i in $(seq 1 40); do
    RUN_STATUS=$(gh run list --repo "${GITHUB_REPO}" --limit 1 --json status --jq '.[0].status' 2>/dev/null || echo "unknown")
    RUN_CONCLUSION=$(gh run list --repo "${GITHUB_REPO}" --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo "")

    if [ "${RUN_STATUS}" = "completed" ]; then
        WORKFLOW_COMPLETE=true
        echo "  Workflow completed with conclusion: ${RUN_CONCLUSION}"
        break
    fi
    echo "  Attempt ${i}/40: Workflow status: ${RUN_STATUS}, waiting 15 seconds..."
    sleep 15
done

if [ "${WORKFLOW_COMPLETE}" = false ]; then
    echo "  WARNING: Workflow did not complete within 10 minutes. Check GitHub Actions manually."
fi

# ----------------------------------------------------------
# Final verification
# ----------------------------------------------------------
echo ""
echo "============================================"
echo "  Deployment Summary"
echo "============================================"
echo ""
echo "  Proxy (HTTPS):  https://${PROXY_IP}/"
echo "  Bastion (SSH):   ssh azureuser@${BASTION_IP}"
echo "  GitHub Repo:     https://github.com/${GITHUB_REPO}"
echo ""

echo "Verifying application..."
HTTP_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "https://${PROXY_IP}/" 2>/dev/null || echo "000")
echo "  HTTPS Response: ${HTTP_STATUS}"

if [ "${HTTP_STATUS}" = "200" ]; then
    echo ""
    echo "  CloudSoft is up and running!"
else
    echo ""
    echo "  Application returned HTTP ${HTTP_STATUS}."
    echo "  Check the logs: ssh azureuser@${BASTION_IP} then ssh to app/proxy."
fi

echo ""
echo "Done."
