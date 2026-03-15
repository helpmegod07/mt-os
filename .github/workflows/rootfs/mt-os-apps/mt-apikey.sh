#!/bin/bash
echo "MT-OS Ghost AI — API Key Setup"
read -p "Paste your Anthropic API key: " K
[ -z "$K" ] && { echo "Skipped."; exit 0; }
echo "export ANTHROPIC_API_KEY=\"$K\"" >> ~/.bashrc
mkdir -p /etc/mt-os
echo "ANTHROPIC_API_KEY=$K" > /etc/mt-os/api.env
chmod 600 /etc/mt-os/api.env
echo "Saved. Restart apps to activate."
read -p "Press Enter..."
