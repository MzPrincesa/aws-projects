#!/usr/bin/env bash
set -e

sudo apt-get update
sudo apt-get install -y tree

nvm install 24.14.0
nvm alias default 24.14.0