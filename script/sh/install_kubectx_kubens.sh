#!/bin/bash
set -x

# Determine OS and Architecture
OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')

# Install krew
cd "$(mktemp -d)"
KREW="krew-${OS}_${ARCH}"
curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"
tar zxvf "${KREW}.tar.gz"
./"${KREW}" install krew

# Install ctx and ns plugins
export PATH="${HOME}/.krew/bin:${PATH}"
kubectl krew install ctx
kubectl krew install ns

# Install kubectx
sudo snap install kubectx --classic