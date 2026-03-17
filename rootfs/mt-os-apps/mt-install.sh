#!/bin/bash
set -euo pipefail

# Ensure disk tools in /sbin and /usr/sbin are in the PATH
export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
export DEBIAN_FRONTEND=noninteractive

# Error handling to keep window open
error_handler() {
    echo ""
    echo "!!! ERROR: Installation failed at line $1 !!!"
    echo "Check the messages above for details."
    read -r -p "Press Enter to exit..."
    exit 1
}
trap 'error_handler $LINENO' ERR

echo "=========================================="
echo "  MT-OS Persistent Laptop Installation"
echo "=========================================="
echo ""

# Check for required tools and attempt to install them if missing
MISSING_TOOLS=()
for tool in parted mkfs.ext4 rsync blkid wipefs; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "The following required tools are missing: ${MISSING_TOOLS[*]}"
    echo "Attempting to resolve automatically..."
    
    # Step 1: Resolve apt-get Permission Errors
    echo "Cleaning up package manager locks..."
    sudo rm -f /var/lib/apt/lists/lock
    sudo rm -f /var/cache/apt/archives/lock
    sudo rm -f /var/lib/dpkg/lock
    sudo rm -f /var/lib/dpkg/lock-frontend
    
    echo "Reconfiguring dpkg..."
    sudo dpkg --configure -a
    
    echo "Updating package lists and installing missing tools..."
    sudo apt-get update -qq --allow-releaseinfo-change || true
    
    if sudo apt-get install -y -qq --no-install-recommends parted rsync e2fsprogs util-linux; then
        echo "Successfully installed missing tools."
    else
        echo "Error: Failed to install missing tools automatically."
        echo "Please ensure you have an internet connection and run: sudo apt-get update && sudo apt-get install -y parted rsync e2fsprogs util-linux"
        read -r -p "Press Enter to exit..."
        exit 1
    fi
fi

echo ""
echo "Available disks:"
lsblk -d -o NAME,SIZE,MODEL
echo ""
read -r -p "Target disk (e.g. sda, nvme0n1): " DISK_INPUT
DISK="/dev/$DISK_INPUT"
if [ ! -b "$DISK" ]; then
    echo "Error: Disk $DISK not found."
    read -r -p "Press Enter to exit..."
    exit 1
fi

echo ""
echo "WARNING: This will ERASE all data on $DISK"
read -r -p "ERASE $DISK? Type YES to confirm: " CONFIRM
CONFIRM_UPPER=$(echo "$CONFIRM" | tr '[:lower:]' '[:upper:]')
if [ "$CONFIRM_UPPER" != "YES" ]; then
    echo "Aborted by user."
    read -r -p "Press Enter to exit..."
    exit 0
fi

echo ""
echo "=========================================="
echo "Step 1: Clearing existing partitions..."
echo "=========================================="
echo "Unmounting any active partitions on $DISK..."
for part in $(lsblk -ln -o NAME "$DISK" 2>/dev/null | tail -n +2); do
    PART_PATH="/dev/$part"
    if mountpoint -q "$PART_PATH" 2>/dev/null || grep -q "$PART_PATH" /proc/mounts 2>/dev/null; then
        echo "Unmounting $PART_PATH..."
        sudo umount -l "$PART_PATH" || true
    fi
done

echo "Wiping existing filesystems..."
sudo wipefs -a "$DISK" || true

echo ""
echo "=========================================="
echo "Step 2: Creating partitions..."
echo "=========================================="
echo "Creating partition table (MBR)..."
sudo parted -s "$DISK" mklabel msdos

echo "Creating boot partition (512 MB)..."
sudo parted -s "$DISK" mkpart primary ext4 1MiB 512MiB

echo "Creating root partition (5 GB)..."
sudo parted -s "$DISK" mkpart primary ext4 512MiB 5000MiB

echo "Creating persistence partition (remaining space)..."
sudo parted -s "$DISK" mkpart primary ext4 5000MiB 100%

echo "Setting boot flag..."
sudo parted -s "$DISK" set 1 boot on

# Wait for partitions to be recognized
sleep 2

# Robust partition naming
if [[ "$DISK" == *nvme* ]] || [[ "$DISK" == *mmcblk* ]]; then
    P1="${DISK}p1"; P2="${DISK}p2"; P3="${DISK}p3"
else
    P1="${DISK}1"; P2="${DISK}2"; P3="${DISK}3"
fi

echo ""
echo "=========================================="
echo "Step 3: Formatting partitions..."
echo "=========================================="
echo "Formatting boot partition..."
sudo mkfs.ext4 -F -L boot "$P1"

echo "Formatting root partition..."
sudo mkfs.ext4 -F -L MT-OS "$P2"

echo "Formatting persistence partition..."
sudo mkfs.ext4 -F -L persistence "$P3"

echo ""
echo "=========================================="
echo "Step 4: Mounting and copying system files..."
echo "=========================================="
sudo mkdir -p /mnt/mt-live /mnt/mt-persist
sudo umount -l /mnt/mt-live 2>/dev/null || true
sudo umount -l /mnt/mt-persist 2>/dev/null || true

echo "Mounting root partition..."
sudo mount "$P2" /mnt/mt-live

echo "Copying system files (this may take 5-15 minutes)..."
# IMPORTANT: Removed --exclude=/boot to ensure the kernel is copied
sudo rsync -ax --progress \
  --exclude=/proc --exclude=/sys --exclude=/dev \
  --exclude=/run --exclude=/mnt --exclude=/media \
  --exclude=/tmp/* --exclude=/var/tmp/* \
  --exclude=/var/cache/apt/archives/* \
  --exclude=/var/log/* \
  / /mnt/mt-live/

echo ""
echo "Creating essential directories..."
sudo mkdir -p /mnt/mt-live/{proc,sys,dev,run,mnt,media,boot}

echo "Mounting virtual filesystems..."
for d in dev dev/pts proc sys; do sudo mount --bind /$d /mnt/mt-live/$d; done

echo "Mounting boot partition..."
sudo mount "$P1" /mnt/mt-live/boot

# If /boot was empty on the live system, we need to copy its contents to the new boot partition
if [ -d "/boot" ] && [ "$(ls -A /boot 2>/dev/null)" ]; then
    echo "Copying live boot files to new boot partition..."
    sudo rsync -ax /boot/ /mnt/mt-live/boot/
fi

echo ""
echo "=========================================="
echo "Step 5: Installing bootloader and kernel..."
echo "=========================================="

# Ensure the kernel is present
if ! ls /mnt/mt-live/boot/vmlinuz* >/dev/null 2>&1; then
    echo "Warning: No kernel found in /boot. Attempting to install kernel..."
    # Ensure we have the right sources for the kernel
    sudo chroot /mnt/mt-live apt-get update -qq --allow-releaseinfo-change || true
    sudo chroot /mnt/mt-live apt-get install -y -qq --no-install-recommends linux-image-686 || true
fi

# Final check for kernel
if ! ls /mnt/mt-live/boot/vmlinuz* >/dev/null 2>&1; then
    echo "!!! CRITICAL ERROR: No kernel found in /boot after installation attempts !!!"
    echo "The system will not be able to boot."
    read -r -p "Press Enter to exit..."
    exit 1
fi

# Generate a proper fstab
echo "Generating fstab..."
BOOT_UUID=$(blkid -s UUID -o value "$P1")
ROOT_UUID=$(blkid -s UUID -o value "$P2")
PERSIST_UUID=$(blkid -s UUID -o value "$P3")

sudo tee /mnt/mt-live/etc/fstab << FSTAB
# MT-OS Persistent Installation
UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1
UUID=$BOOT_UUID /boot ext4 defaults 0 2
UUID=$PERSIST_UUID /persistence ext4 defaults 0 2
FSTAB

echo "Installing GRUB bootloader..."
# Install GRUB to the MBR of the disk
sudo chroot /mnt/mt-live grub-install --target=i386-pc --force "$DISK"

# Create a manual grub.cfg that is robust
echo "Configuring GRUB..."
KERNEL_PATH=$(find /mnt/mt-live/boot -maxdepth 1 -name "vmlinuz*" 2>/dev/null | head -n 1)
INITRD_PATH=$(find /mnt/mt-live/boot -maxdepth 1 -name "initrd.img*" 2>/dev/null | head -n 1)

KERNEL_FILE=$(basename "$KERNEL_PATH")
INITRD_FILE=$(basename "$INITRD_PATH")

# Paths in grub.cfg are relative to the root of the boot partition
sudo tee /mnt/mt-live/boot/grub/grub.cfg << GRUBCFG
set default=0
set timeout=5
insmod all_video
insmod gfxterm
terminal_output gfxterm

menuentry "MT-OS (Installed)" {
    insmod ext2
    search --no-floppy --fs-uuid --set=root $BOOT_UUID
    linux /$KERNEL_FILE root=UUID=$ROOT_UUID quiet rw
    initrd /$INITRD_FILE
}

menuentry "MT-OS Safe Mode" {
    insmod ext2
    search --no-floppy --fs-uuid --set=root $BOOT_UUID
    linux /$KERNEL_FILE root=UUID=$ROOT_UUID nomodeset noapic nosplash
    initrd /$INITRD_FILE
}
GRUBCFG

echo ""
echo "=========================================="
echo "Step 6: Configuring system..."
echo "=========================================="

# Set hostname
echo "mt-os" | sudo tee /mnt/mt-live/etc/hostname
sudo sed -i 's/^127.0.1.1.*/127.0.1.1 mt-os/' /mnt/mt-live/etc/hosts || echo "127.0.1.1 mt-os" | sudo tee -a /mnt/mt-live/etc/hosts

# Configure timezone
echo "UTC" | sudo tee /mnt/mt-live/etc/timezone
sudo ln -sf /usr/share/zoneinfo/UTC /mnt/mt-live/etc/localtime

# Ensure ghost user exists
sudo chroot /mnt/mt-live useradd -m -s /bin/bash -G sudo,audio,video,input ghost 2>/dev/null || true
echo "ghost:ghost" | sudo chroot /mnt/mt-live chpasswd
echo "ghost ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /mnt/mt-live/etc/sudoers || true

# Configure LightDM autologin
sudo mkdir -p /mnt/mt-live/etc/lightdm
sudo tee /mnt/mt-live/etc/lightdm/lightdm.conf << LIGHTDM
[Seat:*]
autologin-user=ghost
autologin-user-timeout=0
user-session=openbox
LIGHTDM

echo ""
echo "=========================================="
echo "Step 7: Finalizing installation..."
echo "=========================================="

# Unmount boot partition
sudo umount /mnt/mt-live/boot || true

# Unmount virtual filesystems
for d in sys proc dev/pts dev; do sudo umount /mnt/mt-live/$d 2>/dev/null || true; done

# Mount and configure persistence
sudo mount "$P3" /mnt/mt-persist || true
echo "/ union" | sudo tee /mnt/mt-persist/persistence.conf
sudo umount /mnt/mt-persist || true

# Final unmount
sudo umount /mnt/mt-live || true

# Cleanup
sudo rmdir /mnt/mt-live /mnt/mt-persist 2>/dev/null || true

echo ""
echo "=========================================="
echo "✓ Installation Complete!"
echo "=========================================="
echo ""
echo "MT-OS has been successfully installed to $DISK"
echo "Please remove your installation media and reboot."
echo "=========================================="
read -r -p "Press Enter to exit..."
