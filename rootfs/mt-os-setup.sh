#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Fix hostname and sudo resolution
echo "MT-OS" > /etc/hostname
echo "127.0.1.1 MT-OS" >> /etc/hosts

cat > /etc/apt/sources.list << 'SOURCES'
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://security.debian.org/debian-security bullseye-security main
SOURCES

# Robust apt-get update with retries
for i in {1..5}; do
    apt-get update -qq && break || { echo "Update failed, retrying in 5s..."; sleep 5; }
done

# Install all required packages with robust error handling
echo "Installing packages (this may take a while, handling network errors)..."
apt-get install -y --no-install-recommends --fix-missing \
    linux-image-686 live-boot systemd systemd-sysv \
    udev dbus network-manager sudo passwd \
    bash vim nano less \
    xorg openbox lxpanel feh \
    lightdm lightdm-gtk-greeter \
    xterm python3 python3-pip python3-tk \
    espeak espeak-ng \
    pulseaudio pulseaudio-utils alsa-utils \
    firefox-esr picom fonts-noto \
    grub-pc grub-common parted dosfstools \
    x11-xserver-utils arandr wget curl git \
    iproute2 net-tools htop ca-certificates \
    portaudio19-dev python3-pyaudio \
    dunst libnotify-bin \
    python3-pil zlib1g-dev libjpeg-dev || {
    echo "First attempt failed, retrying with --fix-missing..."
    sleep 10
    apt-get install -y --no-install-recommends --fix-missing \
        linux-image-686 live-boot systemd systemd-sysv \
        udev dbus network-manager sudo passwd \
        bash vim nano less \
        xorg openbox lxpanel \
        lightdm lightdm-gtk-greeter \
        xterm python3 python3-pip python3-tk \
        espeak espeak-ng \
        pulseaudio pulseaudio-utils alsa-utils \
        firefox-esr picom fonts-noto \
        grub-pc grub-common parted dosfstools \
        x11-xserver-utils arandr wget curl git \
        iproute2 net-tools htop ca-certificates \
        portaudio19-dev python3-pyaudio \
        dunst libnotify-bin \
        python3-pil zlib1g-dev libjpeg-dev
}

pip3 install --no-cache-dir requests speechrecognition pyttsx3

# User setup
useradd -m -s /bin/bash -G sudo,audio,video,input ghost 2>/dev/null || true
echo "ghost:ghost" | chpasswd
echo "ghost ALL=(ALL ) NOPASSWD:ALL" >> /etc/sudoers

# LightDM setup
mkdir -p /etc/lightdm
cat > /etc/lightdm/lightdm.conf << 'LGDM'
[Seat:*]
autologin-user=ghost
autologin-user-timeout=0
user-session=openbox
LGDM

# Copy apps and services
mkdir -p /opt/mt-os /etc/mt-os
# Use -r to copy everything and ensure scripts are executable
# Check both /rootfs and local rootfs directory
if [ -d "/rootfs/mt-os-apps" ]; then
    cp -rf /rootfs/mt-os-apps/* /opt/mt-os/
elif [ -d "./rootfs/mt-os-apps" ]; then
    cp -rf ./rootfs/mt-os-apps/* /opt/mt-os/
fi
chmod +x /opt/mt-os/*.sh /opt/mt-os/*.py 2>/dev/null || true

for f in /mt-os-services/*.service; do test -f "$f" && cp "$f" "/etc/systemd/system/"; done
systemctl enable mt-ai-daemon.service 2>/dev/null || true

# Corrected configuration file copying
mkdir -p /home/ghost/.config/openbox
CONFIG_DIR="$ROOTFS_DIR/mt-os-config"
test -f "$CONFIG_DIR/autostart" && cp "$CONFIG_DIR/autostart" /home/ghost/.config/openbox/
test -f "$CONFIG_DIR/rc.xml" && cp "$CONFIG_DIR/rc.xml" /home/ghost/.config/openbox/
test -f "$CONFIG_DIR/menu.xml" && cp "$CONFIG_DIR/menu.xml" /home/ghost/.config/openbox/
test -f "$CONFIG_DIR/.bashrc" && cp "$CONFIG_DIR/.bashrc" /home/ghost/.bashrc
test -f "$CONFIG_DIR/set-wallpaper.sh" && cp "$CONFIG_DIR/set-wallpaper.sh" /opt/mt-os/
chmod +x /home/ghost/.config/openbox/autostart 2>/dev/null || true

chmod +x /opt/mt-os/set-wallpaper.sh 2>/dev/null || true
chown -R ghost:ghost /home/ghost

echo "{}" > /etc/mt-os/ghost-commands.json
chmod 666 /etc/mt-os/ghost-commands.json

# Install update tools
# Robustly find the rootfs directory relative to the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOTFS_DIR="/rootfs"
[ ! -d "$ROOTFS_DIR" ] && ROOTFS_DIR="$SCRIPT_DIR/rootfs"
[ ! -d "$ROOTFS_DIR" ] && ROOTFS_DIR="$SCRIPT_DIR" # If script is inside rootfs

echo "Using rootfs directory: $ROOTFS_DIR"

test -f "$ROOTFS_DIR/update-checker.sh" && cp "$ROOTFS_DIR/update-checker.sh" /opt/mt-os/
chmod +x /opt/mt-os/update-checker.sh 2>/dev/null || true

test -f "$ROOTFS_DIR/update-os.sh" && cp "$ROOTFS_DIR/update-os.sh" /usr/local/bin/update-os
chmod +x /usr/local/bin/update-os 2>/dev/null || true
# Ensure update-os is also in /opt/mt-os for consistency
test -f "$ROOTFS_DIR/update-os.sh" && cp "$ROOTFS_DIR/update-os.sh" /opt/mt-os/update-os.sh
chmod +x /opt/mt-os/update-os.sh 2>/dev/null || true

echo "Setup complete."
