#!/bin/bash
# Installation script for NFC Clone Framework

echo "╔════════════════════════════════════╗"
echo "║     NFC CLONE INSTALLER v1.0       ║"
echo "╚════════════════════════════════════╝"

# Verify Termux
if [ ! -d "/data/data/com.termux" ] && [ ! -d "/data/data/com.termux.fdroid" ]; then
    echo "[!] Error: This script must be run in Termux"
    exit 1
fi

# Check for root (optional)
if command -v su &> /dev/null; then
    echo "[*] Root access available (optional)"
    HAS_ROOT=1
else
    echo "[*] No root access detected (some features may be limited)"
    HAS_ROOT=0
fi

# Request storage permission
echo "[*] Requesting storage permissions..."
termux-setup-storage

# Install required packages
echo "[*] Installing required packages..."
pkg update -y
pkg install -y python jq termux-api

# Install Python dependencies
echo "[*] Installing Python dependencies..."
pip install -y nfcpy

# Create directory structure
echo "[*] Setting up directory structure..."
mkdir -p cards
mkdir -p logs

# Check for Android app
echo "[*] Checking for NFC Emulator app..."
if ! am start -a android.intent.action.VIEW -d "https://example.com" com.nfcclone.app > /dev/null 2>&1; then
    echo "[!] NFC Emulator app not installed"
    echo "[*] Building Android app..."
    
    # Check if Android SDK is available
    if command -v aapt &> /dev/null; then
        echo "[*] Android SDK available, building app..."
        # This would normally compile the Android app
        # Since we can't actually do that in this script, we'll just show instructions
        echo "[!] Please build and install the Android app manually:"
        echo "    1. Navigate to the android/ directory"
        echo "    2. Run './gradlew installDebug' or build with Android Studio"
    else
        echo "[!] Android SDK not available"
        echo "[*] Please install the NFC Emulator app manually"
        echo "    Download link: https://github.com/nfcclone/app/releases"
    fi
else
    echo "[+] NFC Emulator app is installed"
fi

# Create default config if it doesn't exist
if [ ! -f "config.json" ]; then
    echo "[*] Creating default configuration..."
    cat > config.json << EOF
{
    "card_data_dir": "./cards",
    "nfc_reader": "usb",
    "enable_logging": true,
    "log_file": "./logs/nfc_clone.log"
}
EOF
fi

# Set executable permissions
echo "[*] Setting executable permissions..."
chmod +x nfc_manager.sh
chmod +x scripts/*.sh
chmod +x scripts/*.py

echo "[+] Installation completed successfully!"
echo "[*] Run ./nfc_manager.sh to start using the framework"