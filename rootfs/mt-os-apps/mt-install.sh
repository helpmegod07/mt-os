#!/bin/bash
set -e

# Ensure disk tools in /sbin and /usr/sbin are in the PATH
export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin

# Error handling to keep window open
error_handler() {
    echo ""
    echo "!!! ERROR: Installation failed at line $1 !!!"
    echo "Check the messages above for details."
    read -p "Press Enter to exit..."
    exit 1
}
trap 'error_handler $LINENO' ERR

echo "MT-OS Persistent Install"

# Check for required tools
MISSING=()
for tool in parted mkfs.ext4 rsync blkid; do
    if ! command -v $tool &> /dev/null; then
        MISSING+=($tool)
    fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
    echo "Error: The following required tools are missing: ${MISSING[*]}"
    echo "Please run 'sudo apt-get update && sudo apt-get install -y ${MISSING[*]}' first."
    read -p "Press Enter to exit..."
    exit 1
fi

lsblk -d -o NAME,SIZE,MODEL
read -p "Target disk (e.g. sda): " DISK_INPUT
DISK="/dev/$DISK_INPUT"
if [ ! -b "$DISK" ]; then
    echo "Error: Disk $DISK not found."
    read -p "Press Enter to exit..."
    exit 1
fi

read -p "ERASE $DISK? Type YES: " CONFIRM
# Make confirmation case-insensitive
CONFIRM_UPPER=$(echo "$CONFIRM" | tr '[:lower:]' '[:upper:]')
if [ "$CONFIRM_UPPER" != "YES" ]; then
    echo "Aborted by user."
    read -p "Press Enter to exit..."
    exit 0
fi
parted -s "$DISK" mklabel msdos
parted -s "$DISK" mkpart primary ext4 1MiB 512MiB
parted -s "$DISK" mkpart primary ext4 512MiB 5000MiB
parted -s "$DISK" mkpart primary ext4 5000MiB 100%
parted -s "$DISK" set 1 boot on
# Wait for partitions to be recognized
sleep 2
# Robust partition naming
if [[ "$DISK" == *nvme* ]] || [[ "$DISK" == *mmcblk* ]]; then
    P1="${DISK}p1"; P2="${DISK}p2"; P3="${DISK}p3"
else
    P1="${DISK}1"; P2="${DISK}2"; P3="${DISK}3"
fi

echo "Formatting partitions..."
mkfs.ext4 -F -L boot "$P1" || { echo "Failed to format $P1"; exit 1; }
mkfs.ext4 -F -L MT-OS "$P2" || { echo "Failed to format $P2"; exit 1; }
mkfs.ext4 -F -L persistence "$P3" || { echo "Failed to format $P3"; exit 1; }
mkdir -p /mnt/mt-live /mnt/mt-persist
mount "$P2" /mnt/mt-live || { echo "Failed to mount $P2"; exit 1; }
echo "Copying files (this may take a while)..."
rsync -ax --progress \
  --exclude=/proc --exclude=/sys --exclude=/dev \
  --exclude=/run --exclude=/mnt --exclude=/media \
  --exclude=/tmp/* --exclude=/var/tmp/* \
  / /mnt/mt-live/

mkdir -p /mnt/mt-live/{proc,sys,dev,run,mnt,media,boot}
for d in dev dev/pts proc sys; do mount --bind /$d /mnt/mt-live/$d; done

# Ensure /boot is mounted before grub-install
mount "$P1" /mnt/mt-live/boot || { echo "Failed to mount $P1 to /boot"; exit 1; }

# Ensure the kernel is present in the new system BEFORE installing GRUB
if [ ! -f /mnt/mt-live/boot/vmlinuz* ]; then
    echo "Warning: No kernel found in /boot. Reinstalling kernel..."
    chroot /mnt/mt-live apt-get update
    chroot /mnt/mt-live apt-get install -y linux-image-686
fi

echo "Installing bootloader..."
# Generate a proper fstab before GRUB setup
BOOT_UUID=$(blkid -s UUID -o value "$P1")
ROOT_UUID=$(blkid -s UUID -o value "$P2")
PERSIST_UUID=$(blkid -s UUID -o value "$P3")

cat > /mnt/mt-live/etc/fstab << FSTAB
UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1
UUID=$BOOT_UUID /boot ext4 defaults 0 2
FSTAB

# Force i386-pc for older 32-bit BIOS systems
chroot /mnt/mt-live grub-install --target=i386-pc --force "$DISK"
# Create a manual grub.cfg if update-grub fails or produces live-only config
KERNEL_FILE=$(basename $(ls /mnt/mt-live/boot/vmlinuz* | head -1))
INITRD_FILE=$(basename $(ls /mnt/mt-live/boot/initrd.img* | head -1))

cat > /mnt/mt-live/boot/grub/grub.cfg << GRUBCFG
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
GRUBCFG

umount /mnt/mt-live/boot
for d in sys proc dev/pts dev; do umount /mnt/mt-live/$d 2>/dev/null||true; done
mount "$P3" /mnt/mt-persist
echo "/ union" > /mnt/mt-persist/persistence.conf
umount /mnt/mt-persist
umount /mnt/mt-live
echo "--------------------------------------"
echo "Done! MT-OS has been installed to $DISK."
echo "Please remove your installation media and reboot."
echo "--------------------------------------"
read -p "Press Enter to exit..."
