#!/bin/bash
# MT-OS Wi-Fi Connection Utility
# Enhanced for better reliability and error handling

echo "=========================================="
echo "      MT-OS Wi-Fi Setup Utility"
echo "=========================================="
echo ""

# Check if NetworkManager is running
if ! systemctl is-active --quiet NetworkManager; then
    echo "Starting NetworkManager..."
    sudo systemctl start NetworkManager
    sleep 2
fi

# Ensure Wi-Fi is enabled
echo "Enabling Wi-Fi radio..."
sudo nmcli radio wifi on

echo "Scanning for available networks..."
# Rescan to get fresh results
sudo nmcli dev wifi rescan 2>/dev/null || true
sleep 2

# List available networks with signal strength and security info
echo ""
nmcli -f SSID,BARS,SECURITY,SIGNAL dev wifi list | head -n 20
echo ""

read -p "Enter the SSID (Network Name) you want to connect to: " ssid
if [ -z "$ssid" ]; then
    echo "Error: SSID cannot be empty."
    read -p "Press Enter to exit..."
    exit 1
fi

# Check if the network is already known
if nmcli connection show "$ssid" &>/dev/null; then
    echo "Network '$ssid' is already known. Attempting to connect..."
    if sudo nmcli connection up "$ssid"; then
        echo "Successfully connected to $ssid!"
        sudo ntpdate -u pool.ntp.org || true
        read -p "Press Enter to exit..."
        exit 0
    else
        echo "Failed to connect to known network. Let's try re-entering credentials."
    fi
fi

read -s -p "Enter the Password (leave blank for open networks): " password
echo ""

if [ -z "$password" ]; then
    echo "Connecting to open network: $ssid..."
    sudo nmcli dev wifi connect "$ssid"
else
    echo "Connecting to secured network: $ssid..."
    # Use --ask if needed, but here we provide the password directly
    sudo nmcli dev wifi connect "$ssid" password "$password"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Successfully connected to $ssid!"
    # Sync time immediately after connecting
    echo "Syncing system time..."
    sudo ntpdate -u pool.ntp.org || true
else
    echo ""
    echo "✗ Failed to connect to $ssid."
    echo "Please check your credentials and ensure the network is in range."
    echo "Troubleshooting Tip: Run 'nmcli dev' to check your Wi-Fi hardware status."
fi

echo ""
read -p "Press Enter to exit..."
