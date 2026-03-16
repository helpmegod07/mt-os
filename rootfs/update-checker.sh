#!/bin/bash
# MT-OS Update Checker
# This script checks for updates to the MT-OS repository on GitHub

REPO_URL="https://github.com/helpmegod07/mt-os.git"
CHECK_INTERVAL=600 # 10 minutes

while true; do
  # Check if we have internet
  if ping -c 1 8.8.8.8 &> /dev/null; then
    # Get the latest commit hash from the remote repository
    REMOTE_HASH=$(git ls-remote "$REPO_URL" HEAD | awk '{print $1}')
    
    # Store the current version hash if it doesn't exist
    if [ ! -f /etc/mt-os/version ]; then
      echo "$REMOTE_HASH" > /etc/mt-os/version
    fi
    
    LOCAL_HASH=$(cat /etc/mt-os/version)
    
    if [ "$REMOTE_HASH" != "$LOCAL_HASH" ]; then
      # Only notify if we are in a graphical session
      if [ -n "$DISPLAY" ]; then
        notify-send "MT-OS Update" "A new update is available on GitHub! Run 'update-os' to apply." -i software-update-available
      fi
    fi
  fi
  sleep "$CHECK_INTERVAL"
done
