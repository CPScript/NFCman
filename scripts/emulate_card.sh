#!/bin/bash
# Script to emulate an NFC card - Android Native Version

ANDROID_DATA_DIR="/storage/emulated/0/Android/data/com.nfcclone.app/files"
CARDS_DIR="$ANDROID_DATA_DIR/cards"
PACKAGE_NAME="com.nfcclone.app"

get_card_path() {
    local uid="$1"
    echo "${CARDS_DIR}/card_${uid}.json"
}

list_saved_cards() {
    echo "[*] Saved cards:"
    echo "----------------------------------------"
    echo "| UID                | Type            |"
    echo "----------------------------------------"
    
    for card_file in "$CARDS_DIR"/card_*.json; do
        if [ -f "$card_file" ]; then
            local uid=$(jq -r '.UID // "Unknown"' "$card_file" 2>/dev/null)
            local type=$(jq -r '.Technologies[0] // "Unknown"' "$card_file" 2>/dev/null | sed 's/.*\.//')
            printf "| %-18s | %-15s |\n" "$uid" "${type:0:15}"
        fi
    done
    echo "----------------------------------------"
}

# Check if UID was passed
if [ $# -lt 1 ]; then
    echo "[!] Usage: $0 <card_uid>"
    exit 1
fi

CARD_UID="$1"
CARD_FILE=$(get_card_path "$CARD_UID")

# Verify card exists
if [ ! -f "$CARD_FILE" ]; then
    echo "[!] Card not found: $CARD_UID"
    echo "[!] Available cards:"
    list_saved_cards
    exit 1
fi

echo "[*] Preparing to emulate card: $CARD_UID"
echo "[*] Card file: $CARD_FILE"

# Create emulation configuration
CONFIG_FILE="$ANDROID_DATA_DIR/emulation_config.json"
cat > "$CONFIG_FILE" << EOF
{
    "active": true,
    "card_uid": "$CARD_UID",
    "card_file": "$CARD_FILE",
    "timestamp": $(date +%s)
}
EOF

# Start the NFC Emulator service
if am startservice -n "$PACKAGE_NAME/.NfcEmulatorService" \
    --es "action" "start_emulation" \
    --es "card_uid" "$CARD_UID"; then
    
    echo "[+] NFC emulation service started"
    termux-notification --title "NFC Emulation Active" \
                       --content "Emulating card: $CARD_UID" \
                       --priority high --ongoing
    termux-toast "Card emulation started for UID: $CARD_UID"
else
    echo "[!] Failed to start NFC emulation service"
    echo "[!] Check if the NFC Clone app is installed correctly"
    exit 1
fi

echo "[*] Press Ctrl+C to stop emulation"
trap 'echo "[*] Stopping emulation"; rm -f "$CONFIG_FILE"; am broadcast -a "$PACKAGE_NAME.STOP_EMULATION"; termux-notification-remove nfc_emulation; echo "[+] Emulation stopped"' INT TERM

# Keep script running while emulation is active
while [ -f "$CONFIG_FILE" ]; do
    sleep 1
done
