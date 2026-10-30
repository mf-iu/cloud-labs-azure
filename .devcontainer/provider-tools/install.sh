#!/usr/bin/env bash

# Install the Azure Functions Core Tools (func) for t09 from the package
# repository of Microsoft. Runs as root while the dev container is built;
# the image is the Dockerfile of cloud-labs-local.

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

set -o errexit -o nounset -o pipefail
# apt-get must not ask questions while the image is built
export DEBIAN_FRONTEND=noninteractive

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# The signing key of the package repository, converted into the binary format
# that apt expects
curl --fail --silent --show-error --location https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg
# A list file in sources.list.d adds the package repository; signed-by names the
# key for its packages
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg]" \
    "https://packages.microsoft.com/repos/microsoft-ubuntu-noble-prod noble main" \
    >/etc/apt/sources.list.d/microsoft-prod.list
apt-get update
# --no-install-recommends: only what the package really needs. Removing the
# package lists afterwards keeps the image small.
apt-get install --yes --no-install-recommends azure-functions-core-tools-4
rm --recursive --force /var/lib/apt/lists/*
