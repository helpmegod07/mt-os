#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Fix hostname and sudo resolution
echo "MT-OS" > /etc/hostname
echo "127.0.1.1 MT-OS" >> /etc/hosts

cat > /etc/apt/sources.list << 'SOURCES'
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://security.debian.org/debian-security bullseye-security main
SOURCES

# Robust apt-get update with retries
UPDATE_SUCCESS=false
for _ in {1..5}; do
    if apt-get update -qq; then
        UPDATE_SUCCESS=true
        break
    else
        echo "Update failed, retrying in 5s..."
        sleep 5
    fi
done

if [ "$UPDATE_SUCCESS" = "false" ]; then
    echo "Error: Failed to update package lists after multiple attempts."
    exit 1
fi

# Install all required packages with robust error handling
echo "Installing packages (this may take a while, handling network errors)..."
apt-get install -y --no-install-recommends --fix-missing \
    linux-image-686 live-boot systemd systemd-sysv \
    udev dbus network-manager sudo passwd \
    bash vim nano less \
    xorg openbox lxpanel feh pcmanfm \
    lightdm lightdm-gtk-greeter \
    xterm python3 python3-pip python3-tk \
    espeak espeak-ng \
    pulseaudio pulseaudio-utils alsa-utils \
    firefox-esr picom fonts-noto \
    grub-pc grub-common parted dosfstools \
    x11-xserver-utils arandr wget curl git \
    firmware-linux firmware-linux-nonfree firmware-iwlwifi firmware-realtek firmware-atheros firmware-libertas firmware-brcm80211 firmware-misc-nonfree \
    wpasupplicant wireless-tools \
    iproute2 net-tools htop conky ca-certificates \
    portaudio19-dev python3-pyaudio \
    dunst libnotify-bin \
    tzdata ntpdate \
    build-essential python3-dev \
    gcc-i686-linux-gnu g++-i686-linux-gnu \
    python3-pil zlib1g-dev libjpeg-dev || {
    echo "First attempt failed, retrying with --fix-missing..."
    sleep 10
    if ! apt-get install -y --no-install-recommends --fix-missing \
        linux-image-686 live-boot systemd systemd-sysv \
        udev dbus network-manager sudo passwd \
        bash vim nano less \
        xorg openbox lxpanel pcmanfm \
        lightdm lightdm-gtk-greeter \
        xterm python3 python3-pip python3-tk \
        espeak espeak-ng \
        pulseaudio pulseaudio-utils alsa-utils \
        firefox-esr picom fonts-noto \
        grub-pc grub-common parted dosfstools \
        x11-xserver-utils arandr wget curl git \
        firmware-linux firmware-linux-nonfree firmware-iwlwifi firmware-realtek firmware-atheros firmware-libertas firmware-brcm80211 firmware-misc-nonfree \
        wpasupplicant wireless-tools \
        iproute2 net-tools htop conky ca-certificates \
        portaudio19-dev python3-pyaudio \
        dunst libnotify-bin \
        tzdata ntpdate \
        build-essential python3-dev \
        gcc-i686-linux-gnu g++-i686-linux-gnu \
        python3-pil zlib1g-dev libjpeg-dev; then
        echo "Error: Failed to install core packages."
        exit 1
    fi
}

# Ensure build tools are recognized and used before pip installation
export PATH=$PATH:/usr/bin
export CC=i686-linux-gnu-gcc
export CXX=i686-linux-gnu-g++
pip3 install --no-cache-dir requests speechrecognition pyttsx3 psutil

# Timezone and NTP setup
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo "UTC" > /etc/timezone

# Ensure ntpdate runs on boot if network is available
cat > /etc/network/if-up.d/ntpdate << 'NTP'
#!/bin/sh
/usr/sbin/ntpdate -u pool.ntp.org || true
NTP
chmod +x /etc/network/if-up.d/ntpdate

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
# In the chroot, files are at the root as per build.yml
if [ -d "/mt-os-apps" ]; then
    cp -rf /mt-os-apps/* /opt/mt-os/
fi
chmod +x /opt/mt-os/*.sh /opt/mt-os/*.py 2>/dev/null || true

if [ -d "/mt-os-services" ]; then
    for f in /mt-os-services/*.service; do 
        test -f "$f" && cp "$f" "/etc/systemd/system/"
    done
fi
# Fix potential systemctl issue in chroot
if [ -f "/etc/systemd/system/mt-ai-daemon.service" ]; then
    systemctl enable mt-ai-daemon.service 2>/dev/null || true
fi

# Configuration file copying
mkdir -p /home/ghost/.config/openbox
CONFIG_DIR="/mt-os-config"
if [ -d "$CONFIG_DIR" ]; then
    test -f "$CONFIG_DIR/autostart" && cp "$CONFIG_DIR/autostart" /home/ghost/.config/openbox/
    test -f "$CONFIG_DIR/rc.xml" && cp "$CONFIG_DIR/rc.xml" /home/ghost/.config/openbox/
    test -f "$CONFIG_DIR/menu.xml" && cp "$CONFIG_DIR/menu.xml" /home/ghost/.config/openbox/
    # lxpanel config
    mkdir -p /home/ghost/.config/lxpanel/mt-os/panels
    cat > /home/ghost/.config/lxpanel/mt-os/panels/panel << 'PANEL'
Global {
    edge=bottom
    allign=left
    margin=0
    widthtype=percent
    width=100
    height=24
    transparent=0
    tintcolor=#0A0A0F
    alpha=255
    autohide=0
    heightwhenhidden=2
    setdocktype=1
    setpartialstrut=1
    usefontcolor=1
    fontcolor=#00FF88
    background=1
    bgfile=/opt/mt-os/panel-bg.png
}

Plugin {
    type = menu
    Config {
        image=/opt/mt-os/ghost-icon.png
        system {
        }
        separator {
        }
        item {
            command=run
        }
    }
}

Plugin {
    type = taskbar
    Config {
        tooltips=1
        IconsOnly=0
        AcceptSkipPager=1
        ShowAllDesks=0
        UseCustomButton=1
        MaxButtonWidth=150
        FlatButton=1
    }
}

Plugin {
    type = pager
}

Plugin {
    type = dclock
    Config {
        ClockFmt=%R
        TooltipFmt=%A %x
        BoldFont=1
        IconOnly=0
        CenterText=0
    }
}
PANEL
    if [ -f "$CONFIG_DIR/themerc" ]; then
        mkdir -p /home/ghost/.themes/MT-OS/openbox-3
        cp "$CONFIG_DIR/themerc" /home/ghost/.themes/MT-OS/openbox-3/themerc
    fi
    test -f "$CONFIG_DIR/set-wallpaper.sh" && cp "$CONFIG_DIR/set-wallpaper.sh" /opt/mt-os/
fi
chmod +x /home/ghost/.config/openbox/autostart 2>/dev/null || true
chmod +x /opt/mt-os/set-wallpaper.sh 2>/dev/null || true
chown -R ghost:ghost /home/ghost

echo "{}" > /etc/mt-os/ghost-commands.json
chmod 666 /etc/mt-os/ghost-commands.json

# Install update tools
# In the chroot, update scripts are at the root
if [ -f "/update-checker.sh" ]; then
    cp "/update-checker.sh" /opt/mt-os/
    chmod +x /opt/mt-os/update-checker.sh
fi

if [ -f "/update-os.sh" ]; then
    cp "/update-os.sh" /opt/mt-os/update-os.sh
    chmod +x /opt/mt-os/update-os.sh
    # Ensure /usr/local/bin exists and is in PATH
    mkdir -p /usr/local/bin
    ln -sf /opt/mt-os/update-os.sh /usr/local/bin/update-os
    ln -sf /opt/mt-os/update-os.sh /usr/bin/update-os
    chmod +x /usr/local/bin/update-os /usr/bin/update-os
fi

echo "Setup complete."
