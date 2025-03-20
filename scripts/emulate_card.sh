#!/bin/bash
# Script to emulate an NFC card

source ./scripts/card_utils.sh

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

# Create a temporary JSON settings file for the Android app
TEMP_SETTINGS=$(mktemp)
cat > "$TEMP_SETTINGS" << EOF
{
    "uid": "$CARD_UID",
    "card_path": "$CARD_FILE",
    "auto_response": true
}
EOF

# Copy settings to a location accessible by the app
ANDROID_STORAGE_PATH="/storage/emulated/0/Android/data/com.nfcclone.app/files"
mkdir -p "$ANDROID_STORAGE_PATH"
cp "$TEMP_SETTINGS" "$ANDROID_STORAGE_PATH/current_card.json"
rm "$TEMP_SETTINGS"

# Start the NFC Emulator app
if am start -n com.nfcclone.app/.MainActivity --ez "start_emulation" true; then
    echo "[+] NFC emulation service started"
    # Notify user
    termux-notification --title "NFC Emulation Active" --content "Emulating card: $CARD_UID" --priority high --ongoing
    termux-toast "Card emulation started for UID: $CARD_UID"
else
    echo "[!] Failed to start NFC emulation service"
    echo "[!] Check if the NFC Clone app is installed correctly"
    exit 1
fi

echo "[*] Press Ctrl+C to stop emulation"
# Wait for user to cancel
trap 'echo "[*] Stopping emulation"; am broadcast -a com.nfcclone.app.STOP_EMULATION; termux-notification-remove nfc_emulation; echo "[+] Emulation stopped"' INT TERM
read -r -d '' _ </dev/tty