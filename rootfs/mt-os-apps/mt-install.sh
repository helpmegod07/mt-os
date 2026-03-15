#!/bin/bash
set -e
echo "MT-OS Persistent Install"
lsblk -d -o NAME,SIZE,MODEL
read -p "Target disk (e.g. sda): " DISK
DISK="/dev/$DISK"
[ ! -b "$DISK" ] && { echo "Not found."; exit 1; }
read -p "ERASE $DISK? Type YES: " C
[ "$C" != "YES" ] && { echo "Aborted."; exit 0; }
parted -s "$DISK" mklabel msdos
parted -s "$DISK" mkpart primary ext4 1MiB 512MiB
parted -s "$DISK" mkpart primary ext4 512MiB 5000MiB
parted -s "$DISK" mkpart primary ext4 5000MiB 100%
parted -s "$DISK" set 1 boot on
P1="${DISK}1"; P2="${DISK}2"; P3="${DISK}3"
echo "$DISK" | grep -q nvme && P1="${DISK}p1" && P2="${DISK}p2" && P3="${DISK}p3"
mkfs.ext4 -F -L boot "$P1"
mkfs.ext4 -F -L MT-OS "$P2"
mkfs.ext4 -F -L persistence "$P3"
mkdir -p /mnt/mt-live /mnt/mt-persist
mount "$P2" /mnt/mt-live
rsync -ax --progress \
  --exclude=/proc --exclude=/sys --exclude=/dev \
  --exclude=/run --exclude=/mnt --exclude=/media \
  / /mnt/mt-live/
mkdir -p /mnt/mt-live/{proc,sys,dev,run,mnt,media}
for d in dev dev/pts proc sys; do mount --bind /$d /mnt/mt-live/$d; done
chroot /mnt/mt-live grub-install --target=i386-pc "$DISK"
chroot /mnt/mt-live update-grub
UUID=$(blkid -s UUID -o value "$P2")
echo "UUID=$UUID / ext4 errors=remount-ro 0 1" > /mnt/mt-live/etc/fstab
for d in sys proc dev/pts dev; do umount /mnt/mt-live/$d 2>/dev/null||true; done
mount "$P3" /mnt/mt-persist
echo "/ union" > /mnt/mt-persist/persistence.conf
umount /mnt/mt-persist
umount /mnt/mt-live
echo "Done! Remove media and reboot."
read -p "Press Enter..."
