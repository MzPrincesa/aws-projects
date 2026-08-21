#!/usr/bin/env bash
set -e

echo ">>> Starting post-create setup"

sudo apt-get update
sudo apt-get install -y tree

echo ">>> Loading NVM"
export NVM_DIR="/home/codespace/nvm"
source "$NVM_DIR/nvm.sh"

echo ">>> Installing Node 24.14.0"
nvm install 24.14.0
nvm alias default 24.14.0
nvm use 24.14.0

echo ">>> post-create setup complete"
