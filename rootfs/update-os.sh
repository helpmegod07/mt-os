#!/bin/bash
# MT-OS Self-Update Script

REPO_URL="https://github.com/helpmegod07/mt-os.git"
TEMP_DIR="/tmp/mt-os-update"

echo "--- MT-OS Update Started ---"

# 1. Clone the latest code
echo "Fetching latest changes from GitHub..."
rm -rf $TEMP_DIR
git clone --depth 1 $REPO_URL $TEMP_DIR

if [ $? -ne 0 ]; then
    echo "Error: Could not connect to GitHub."
    exit 1
fi

# Get the latest commit hash
REMOTE_HASH=$(cd $TEMP_DIR && git rev-parse HEAD)

# 2. Sync files to the live system
echo "Applying updates..."

# Install missing dependencies (like feh and time tools)
echo "Checking for missing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends feh picom python3-pil tzdata ntpdate parted rsync dosfstools 2>/dev/null

# Update Apps
if [ -d "$TEMP_DIR/rootfs/mt-os-apps" ]; then
    # Use -r to copy directories and avoid errors with __pycache__ if present
    sudo cp -rf $TEMP_DIR/rootfs/mt-os-apps/* /opt/mt-os/ 2>/dev/null
fi

# Update Configs
mkdir -p /home/ghost/.config/openbox
[ -f $TEMP_DIR/rootfs/mt-os-config/autostart ] && sudo cp $TEMP_DIR/rootfs/mt-os-config/autostart /home/ghost/.config/openbox/
[ -f $TEMP_DIR/rootfs/mt-os-config/rc.xml ] && sudo cp $TEMP_DIR/rootfs/mt-os-config/rc.xml /home/ghost/.config/openbox/
[ -f $TEMP_DIR/rootfs/mt-os-config/menu.xml ] && sudo cp $TEMP_DIR/rootfs/mt-os-config/menu.xml /home/ghost/.config/openbox/
[ -f $TEMP_DIR/rootfs/mt-os-config/.bashrc ] && sudo cp $TEMP_DIR/rootfs/mt-os-config/.bashrc /home/ghost/.bashrc
[ -f $TEMP_DIR/rootfs/mt-os-config/set-wallpaper.sh ] && sudo cp $TEMP_DIR/rootfs/mt-os-config/set-wallpaper.sh /opt/mt-os/
sudo chmod +x /home/ghost/.config/openbox/autostart /opt/mt-os/set-wallpaper.sh 2>/dev/null

# Update Services
if [ -d "$TEMP_DIR/rootfs/mt-os-services" ]; then
    sudo cp $TEMP_DIR/rootfs/mt-os-services/*.service /etc/systemd/system/ 2>/dev/null
    sudo systemctl daemon-reload
fi

# Update version file
sudo mkdir -p /etc/mt-os
echo "$REMOTE_HASH" | sudo tee /etc/mt-os/version > /dev/null

# Ensure systemd services are enabled, reloaded, and restarted
if [ -d "/etc/systemd/system" ]; then
    sudo systemctl daemon-reload
    sudo systemctl enable mt-ai-daemon.service 2>/dev/null || true
    # Stop any existing instances before restarting service
    sudo pkill -f mt-face.py || true
    sudo systemctl restart mt-ai-daemon.service 2>/dev/null || true
fi

# 3. Cleanup
rm -rf $TEMP_DIR
# Ensure all scripts and python files are executable
sudo chmod +x /opt/mt-os/*.sh /opt/mt-os/*.py /home/ghost/.config/openbox/autostart 2>/dev/null
# Ensure update-os is correctly linked and executable in multiple locations
sudo mkdir -p /usr/local/bin
sudo ln -sf /opt/mt-os/update-os.sh /usr/local/bin/update-os
sudo ln -sf /opt/mt-os/update-os.sh /usr/bin/update-os
sudo chmod +x /usr/local/bin/update-os /usr/bin/update-os
sudo chown -R ghost:ghost /home/ghost /opt/mt-os

# Reload Openbox to apply new rc.xml immediately
echo "Reloading window manager..."
DISPLAY=:0 openbox --reconfigure 2>/dev/null || true
# Run wallpaper script immediately
sudo -u ghost DISPLAY=:0 bash /opt/mt-os/set-wallpaper.sh 2>/dev/null || true

echo "--- Update Complete! ---"
echo "Your desktop has been reloaded. If you still see issues, please reboot."
