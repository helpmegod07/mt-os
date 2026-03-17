#!/bin/bash
# MT-OS Automatic USB Backup Script
# This script detects a USB drive and backs up essential system files.

BACKUP_LOG="/var/log/mt-backup.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "[$TIMESTAMP] Starting automatic backup..." >> "$BACKUP_LOG"

# 1. Detect USB Drive
# We look for any mount point under /media/ or /mnt/ that is not the root filesystem
USB_MOUNT=$(lsblk -rn -o MOUNTPOINT | grep -E "^/(media|mnt)/" | head -n 1)

if [ -z "$USB_MOUNT" ]; then
    echo "[$TIMESTAMP] Error: No USB drive detected. Please ensure a USB drive is mounted." >> "$BACKUP_LOG"
    exit 1
fi

echo "[$TIMESTAMP] USB drive detected at: $USB_MOUNT" >> "$BACKUP_LOG"

# 2. Prepare Backup Directory
BACKUP_DIR="$USB_MOUNT/mt-os-backup"
mkdir -p "$BACKUP_DIR"

# 3. Perform Backup using rsync
# We back up /home/ghost, /etc/mt-os, and /opt/mt-os
echo "[$TIMESTAMP] Backing up /home/ghost, /etc/mt-os, and /opt/mt-os..." >> "$BACKUP_LOG"

rsync -avz --delete /home/ghost "$BACKUP_DIR/" >> "$BACKUP_LOG" 2>&1
rsync -avz --delete /etc/mt-os "$BACKUP_DIR/" >> "$BACKUP_LOG" 2>&1
rsync -avz --delete /opt/mt-os "$BACKUP_DIR/" >> "$BACKUP_LOG" 2>&1

if [ $? -eq 0 ]; then
    echo "[$TIMESTAMP] Backup completed successfully." >> "$BACKUP_LOG"
else
    echo "[$TIMESTAMP] Backup failed. Check log for details." >> "$BACKUP_LOG"
fi

echo "-------------------------------------------" >> "$BACKUP_LOG"
