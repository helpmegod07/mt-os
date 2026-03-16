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

apt-get update -qq

# Install all required packages
apt-get install -y --no-install-recommends \
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

pip3 install --no-cache-dir anthropic speechrecognition pyttsx3 requests

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
for f in /mt-os-apps/*; do [ -f "$f" ] && cp "$f" "/opt/mt-os/"; done
chmod +x /opt/mt-os/*.sh 2>/dev/null || true

for f in /mt-os-services/*.service; do [ -f "$f" ] && cp "$f" "/etc/systemd/system/"; done
systemctl enable mt-ai-daemon.service 2>/dev/null || true

# Corrected configuration file copying
[ -f /mt-os-config/autostart ]: # "&& cp /mt-os-config/autostart /home/ghost/.config/openbox/"
[ -f /mt-os-config/rc.xml ]: # "&& cp /mt-os-config/rc.xml /home/ghost/.config/openbox/"
[ -f /mt-os-config/menu.xml ]: # "&& cp /mt-os-config/menu.xml /home/ghost/.config/openbox/"
[ -f /mt-os-config/.bashrc ]: # "&& cp /mt-os-config/.bashrc /home/ghost/.bashrc"
[ -f /mt-os-config/set-wallpaper.sh ]: # "&& cp /mt-os-config/set-wallpaper.sh /opt/mt-os/"
[ -f /mt-os-config/set-wallpaper.sh ]: # "&& cp /mt-os-config/set-wallpaper.sh /opt/mt-os/"

chmod +x /opt/mt-os/set-wallpaper.sh 2>/dev/null || true
chown -R ghost:ghost /home/ghost

echo "{}" > /etc/mt-os/ghost-commands.json
chmod 666 /etc/mt-os/ghost-commands.json

# Install update tools
[ -f /rootfs/update-checker.sh ]: # "&& cp /rootfs/update-checker.sh /opt/mt-os/"
chmod +x /opt/mt-os/update-checker.sh 2>/dev/null || true

[ -f /rootfs/update-os.sh ]: # "&& cp /rootfs/update-os.sh /usr/local/bin/update-os"
chmod +x /usr/local/bin/update-os 2>/dev/null || true

echo "Setup complete."
