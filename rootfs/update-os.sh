#!/bin/bash
set -euo pipefail
# MT-OS Self-Update Script
# Enhanced for reliable updates from GitHub

REPO_URL="https://github.com/helpmegod07/mt-os.git"
TEMP_DIR="/tmp/mt-os-update"

echo "=========================================="
echo "      MT-OS System Update Utility"
echo "=========================================="
echo ""

# 1. Clone the latest code
echo "Fetching latest changes from GitHub..."
sudo rm -rf $TEMP_DIR
if ! git clone --depth 1 $REPO_URL $TEMP_DIR; then
    echo "Error: Could not connect to GitHub. Please check your internet connection."
    read -r -p "Press Enter to exit..."
    exit 1
fi

# Get the latest commit hash
REMOTE_HASH=$(cd $TEMP_DIR && git rev-parse HEAD)

# 2. Sync files to the live system
echo "Applying updates..."

# Install missing dependencies and perform a full upgrade
echo "Checking for system updates and missing dependencies..."
sudo apt-get update -qq --allow-releaseinfo-change || true
sudo apt-get install -y -qq --no-install-recommends \
    feh picom python3-pil tzdata ntpdate parted rsync \
    dosfstools e2fsprogs util-linux wipefs NetworkManager \
    grub-pc-bin 2>/dev/null || true

# Ensure /sbin and /usr/sbin are in the PATH for disk tools
export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin

# Update Apps and Scripts
echo "Updating applications and system scripts..."
sudo mkdir -p /opt/mt-os
if [ -d "$TEMP_DIR/rootfs/mt-os-apps" ]; then
    sudo cp -rf $TEMP_DIR/rootfs/mt-os-apps/* /opt/mt-os/
fi

# Update the update-os script itself
if [ -f "$TEMP_DIR/rootfs/update-os.sh" ]; then
    sudo cp "$TEMP_DIR/rootfs/update-os.sh" /opt/mt-os/update-os.sh
fi

# Update Configs
echo "Updating system configurations..."
sudo mkdir -p /home/ghost/.config/openbox
[ -f $TEMP_DIR/rootfs/mt-os-config/autostart ] && sudo cp $TEMP_DIR/rootfs/mt-os-config/autostart /home/ghost/.config/openbox/
[ -f $TEMP_DIR/rootfs/mt-os-config/rc.xml ] && sudo cp $TEMP_DIR/rootfs/mt-os-config/rc.xml /home/ghost/.config/openbox/
[ -f $TEMP_DIR/rootfs/mt-os-config/menu.xml ] && sudo cp $TEMP_DIR/rootfs/mt-os-config/menu.xml /home/ghost/.config/openbox/
[ -f $TEMP_DIR/rootfs/mt-os-config/.bashrc ] && sudo cp $TEMP_DIR/rootfs/mt-os-config/.bashrc /home/ghost/.bashrc
[ -f $TEMP_DIR/rootfs/mt-os-config/set-wallpaper.sh ] && sudo cp $TEMP_DIR/rootfs/mt-os-config/set-wallpaper.sh /opt/mt-os/

# Update Services
if [ -d "$TEMP_DIR/rootfs/mt-os-services" ]; then
    echo "Updating system services..."
    sudo cp $TEMP_DIR/rootfs/mt-os-services/*.service /etc/systemd/system/ 2>/dev/null
    sudo systemctl daemon-reload
fi

# Update version file
sudo mkdir -p /etc/mt-os
echo "$REMOTE_HASH" | sudo tee /etc/mt-os/version > /dev/null

# Ensure systemd services are enabled and restarted
if systemctl list-unit-files | grep -q mt-ai-daemon.service; then
    sudo systemctl enable mt-ai-daemon.service 2>/dev/null || true
    sudo systemctl restart mt-ai-daemon.service 2>/dev/null || true
fi

# 3. Cleanup and Permissions
sudo rm -rf $TEMP_DIR
echo "Finalizing permissions..."
sudo chmod +x /opt/mt-os/*.sh /opt/mt-os/*.py /home/ghost/.config/openbox/autostart 2>/dev/null

# Ensure update-os and mt-install are correctly linked and executable
sudo mkdir -p /usr/local/bin
sudo ln -sf /opt/mt-os/update-os.sh /usr/local/bin/update-os
sudo ln -sf /opt/mt-os/mt-install.sh /usr/local/bin/mt-install
sudo chmod +x /usr/local/bin/update-os /usr/local/bin/mt-install

# Fix ownership
sudo chown -R ghost:ghost /home/ghost /opt/mt-os 2>/dev/null || true

# Reload Openbox to apply new configuration immediately
echo "Reloading window manager..."
DISPLAY=:0 openbox --reconfigure 2>/dev/null || true

echo ""
echo "=========================================="
echo "✓ Update Complete!"
echo "=========================================="
echo "The latest fixes for the installer and system"
echo "have been applied. You can now run 'mt-install'"
echo "to begin the installation to your laptop."
echo "=========================================="
read -r -p "Press Enter to exit..."
