#!/bin/bash
echo "MT-OS Ghost AI — API Key Setup"
read -p "Paste your GitHub Personal Access Token (PAT): " K
[ -z "$K" ] && { echo "Skipped."; exit 0; }
echo "export GITHUB_PAT=\"$K\"" >> ~/.bashrc
mkdir -p /etc/mt-os
echo "GITHUB_PAT=$K" > /etc/mt-os/api.env
chmod 600 /etc/mt-os/api.env
echo "Saved. Restart apps to activate."
read -p "Press Enter..."
