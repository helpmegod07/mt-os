#!/bin/bash
# MT-OS Wi-Fi Connection Utility

echo "--- MT-OS Wi-Fi Setup ---"
echo "Scanning for networks..."

# Check if Wi-Fi is enabled
nmcli radio wifi on

# List available networks
nmcli -f SSID,BARS,SECURITY dev wifi list

echo ""
read -p "Enter the SSID (Network Name) you want to connect to: " ssid
read -s -p "Enter the Password (leave blank for open networks): " password
echo ""

if [ -z "$password" ]; then
    echo "Connecting to open network: $ssid..."
    sudo nmcli dev wifi connect "$ssid"
else
    echo "Connecting to secured network: $ssid..."
    sudo nmcli dev wifi connect "$ssid" password "$password"
fi

if [ $? -eq 0 ]; then
    echo "Successfully connected to $ssid!"
    # Sync time immediately after connecting
    sudo ntpdate -u pool.ntp.org || true
else
    echo "Failed to connect to $ssid. Please check your credentials and try again."
fi

echo "Press Enter to exit."
read
