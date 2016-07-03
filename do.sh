#!/usr/bin/env bash

set -e
set -u

# requires:
#  - jq
#  - azure-xplat-cli
#  - user logged into correct subscription
#  - (the base64 command used might be linux specific)

function kill_any_registry_pods() {
	REGISTRY_POD_NAME=$(kubectl get pods --namespace=kube-system -o json | jq -r '.items | map(select(contains ({"metadata":{"labels":{"k8s-app":"kube-registry"}}}))) | .[0].metadata.name')
	if [[ "${REGISTRY_POD_NAME}" != "null" ]]; then
		kubectl delete pod --namespace="kube-system" "${REGISTRY_POD_NAME}"
	fi
}

function deploy_secret() {
	# prompt for resource group name if not set
	if [[ -z "${AZURE_RESOURCE_GROUP:-}" ]]; then
		echo -n "Resource Group name (AZURE_RESOURCE_GROUP): "
		read AZURE_RESOURCE_GROUP
	fi

	# prompt for storage account name if not set
	if [[ -z "${AZURE_STORAGE_ACCOUNT:-}" ]]; then
		echo -n "Storage account name (AZURE_STORAGE_ACCOUNT): "
		read AZURE_STORAGE_ACCOUNT
	fi

	AZURE_STORAGE_CONTAINER="${AZURE_STORAGE_CONTAINER:-registry}"

	KEYS="$(azure storage account keys list --json --resource-group "${AZURE_RESOURCE_GROUP}" "${AZURE_STORAGE_ACCOUNT}")"
	AZURE_STORAGE_KEY="$(echo "$KEYS" | jq -r '.[0].value')"

	AZURE_STORAGE_ACCOUNT_64="$(echo "${AZURE_STORAGE_ACCOUNT}" | base64 -w 0)"
	AZURE_STORAGE_CONTAINER_64="$(echo "${AZURE_STORAGE_CONTAINER}" | base64 -w 0)"
	AZURE_STORAGE_KEY_64="$(echo "${AZURE_STORAGE_KEY}" | base64 -w 0)"

	SECRET=$(mktemp)
	trap "rm -rf ${SECRET}" EXIT

	cp azure-storage-key-secret.yaml "${SECRET}"

	sed -i "s|{{AZURE_STORAGE_ACCOUNT}}|${AZURE_STORAGE_ACCOUNT_64}|g" "${SECRET}"
	sed -i "s|{{AZURE_STORAGE_CONTAINER}}|${AZURE_STORAGE_CONTAINER_64}|g" "${SECRET}"
	sed -i "s|{{AZURE_STORAGE_KEY}}|${AZURE_STORAGE_KEY_64}|g" "${SECRET}"

	kubectl apply -f "${SECRET}"

	kill_any_registry_pods
}

function deploy_registry() {
	kubectl apply -f "./kube-registry-deployment.yaml"
	kubectl apply -f "./kube-registry-service.yaml"
	kubectl apply -f "./kube-registry-proxy.yaml"
}

function deploy() {
	deploy_secret
	deploy_registry
}

function tunnel() {
	REGISTRY_POD_NAME=$(kubectl get pods --namespace=kube-system -o json | jq -r '.items | map(select(contains ({"metadata":{"labels":{"k8s-app":"kube-registry"}}}))) | .[0].metadata.name')
	kubectl port-forward --namespace="kube-system" "${REGISTRY_POD_NAME}" 5000
}

# tear down any pre-existing registry
function destroy() {
	kubectl delete --namespace="kube-system" secret azure-storage-key || true
	kubectl delete --namespace="kube-system" deployment kube-registry || true
	kubectl delete --namespace="kube-system" service kube-registry || true
	kubectl delete --namespace="kube-system" daemonset kube-registry-proxy || true
}

"$@"
