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

# 2. Sync files to the live system
echo "Applying updates..."

# Update Apps
sudo cp -r $TEMP_DIR/rootfs/mt-os-apps/* /opt/mt-os/ 2>/dev/null

# Update Configs (Home directory )
sudo cp $TEMP_DIR/rootfs/mt-os-config/autostart /home/ghost/.config/openbox/
sudo cp $TEMP_DIR/rootfs/mt-os-config/rc.xml /home/ghost/.config/openbox/
sudo cp $TEMP_DIR/rootfs/mt-os-config/menu.xml /home/ghost/.config/openbox/
sudo cp $TEMP_DIR/rootfs/mt-os-config/.bashrc /home/ghost/.bashrc
sudo cp $TEMP_DIR/rootfs/mt-os-config/set-wallpaper.sh /opt/mt-os/

# Update Services
sudo cp $TEMP_DIR/rootfs/mt-os-services/*.service /etc/systemd/system/
sudo systemctl daemon-reload

# 3. Cleanup
rm -rf $TEMP_DIR
sudo chmod +x /opt/mt-os/*.sh 2>/dev/null
sudo chown -R ghost:ghost /home/ghost

echo "--- Update Complete! ---"
echo "Please restart your session or reboot to see all changes."
