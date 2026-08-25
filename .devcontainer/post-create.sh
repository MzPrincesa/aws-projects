#!/usr/bin/env bash
set -e

echo ">>> Starting post-create setup"

sudo apt-get update || true
sudo apt-get install -y tree

echo ">>> Loading NVM"
export NVM_DIR="/home/codespace/nvm"
source "$NVM_DIR/nvm.sh"

echo ">>> Installing Node 24.19.0"
nvm install 24.19.0
nvm alias default 24.19.0
nvm use 24.19.0

echo ">>> Installing Terraform"
export TF_VERSION=1.15.8
curl -LO "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
unzip -o "terraform_${TF_VERSION}_linux_amd64.zip" -d /tmp
sudo mv /tmp/terraform /usr/local/bin/
rm "terraform_${TF_VERSION}_linux_amd64.zip"

echo ">>> post-create setup complete"