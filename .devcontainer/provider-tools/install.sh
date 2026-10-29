#!/usr/bin/env bash
# Install the Azure Functions Core Tools (func) for t09 from the package
# repository of Microsoft. Runs as root while the dev container is built;
# the image is the Dockerfile of cloud-labs-local.
set -o errexit -o nounset -o pipefail
export DEBIAN_FRONTEND=noninteractive

curl --fail --silent --show-error --location https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg]" \
  "https://packages.microsoft.com/repos/microsoft-ubuntu-noble-prod noble main" \
  >/etc/apt/sources.list.d/microsoft-prod.list
apt-get update
apt-get install --yes --no-install-recommends azure-functions-core-tools-4
rm --recursive --force /var/lib/apt/lists/*
