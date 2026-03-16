#!/bin/bash
while true; do
  git fetch origin
  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse @{u})
  if [ "$LOCAL" != "$REMOTE" ]; then
    notify-send "MT-OS Update" "A new update is available on GitHub! Run 'update-os' to apply." -i software-update-available
  fi
  sleep 600 # Checks every 10 minutes
done
