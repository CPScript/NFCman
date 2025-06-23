#!/bin/bash

PACKAGE_NAME="com.nfcclone.app"

get_card_path() {
    local uid="$1"
    local all_locations=(
        "$HOME/nfc_cards"
        "/storage/emulated/0/Documents/NFCClone/cards"
        "/storage/emulated/0/NFCClone/cards"
    )
    
    for location in "${all_locations[@]}"; do
        if [ -f "$location/card_${uid}.json" ]; then
            echo "$location/card_${uid}.json"
            return 0
        fi
    done
    
    return 1
}

list_saved_cards() {
    echo "[*] Saved cards:"
    echo "----------------------------------------"
    echo "| UID                | Type            |"
    echo "----------------------------------------"
    
    local all_locations=(
        "$HOME/nfc_cards"
        "/storage/emulated/0/Documents/NFCClone/cards"
        "/storage/emulated/0/NFCClone/cards"
    )
    
    local found_cards=false
    local processed_uids=""
    
    for location in "${all_locations[@]}"; do
        if [ -d "$location" ]; then
            for card_file in "$location"/card_*.json; do
                if [ -f "$card_file" ]; then
                    local uid=$(jq -r '.UID // "Unknown"' "$card_file" 2>/dev/null)
                    
                    if [[ ! "$processed_uids" =~ $uid ]]; then
                        local type=$(jq -r '.Technologies[0] // "Unknown"' "$card_file" 2>/dev/null | sed 's/.*\.//')
                        printf "| %-18s | %-15s |\n" "$uid" "${type:0:15}"
                        found_cards=true
                        processed_uids="$processed_uids $uid"
                    fi
                fi
            done
        fi
    done
    
    if [ "$found_cards" = false ]; then
        echo "| No cards found    |                 |"
    fi
    
    echo "----------------------------------------"
}

if [ $# -lt 1 ]; then
    echo "[!] Usage: $0 <card_uid>"
    exit 1
fi

CARD_UID="$1"
CARD_FILE=$(get_card_path "$CARD_UID")

if [ $? -ne 0 ]; then
    echo "[!] Card not found: $CARD_UID"
    echo "[!] Available cards:"
    list_saved_cards
    exit 1
fi

echo "[*] Preparing to emulate card: $CARD_UID"
echo "[*] Card file: $CARD_FILE"

CONFIG_FILE="$HOME/nfc_cards/emulation_config.json"
cat > "$CONFIG_FILE" << EOF
{
    "active": true,
    "card_uid": "$CARD_UID",
    "card_file": "$CARD_FILE",
    "timestamp": $(date +%s)
}
EOF

if am startservice -n "$PACKAGE_NAME/.NfcEmulatorService" \
    --es "action" "start_emulation" \
    --es "card_uid" "$CARD_UID" >/dev/null 2>&1; then
    
    echo "[+] NFC emulation service started"
    
    if command -v termux-notification >/dev/null 2>&1; then
        termux-notification --title "NFC Emulation Active" \
                           --content "Emulating card: $CARD_UID" \
                           --priority high --ongoing 2>/dev/null || true
    fi
    
    if command -v termux-toast >/dev/null 2>&1; then
        termux-toast "Card emulation started for UID: $CARD_UID" 2>/dev/null || true
    fi
else
    echo "[!] Failed to start NFC emulation service"
    echo "[!] Check if the NFC Clone app is installed correctly"
    exit 1
fi

echo "[*] Press Ctrl+C to stop emulation"
trap 'echo "[*] Stopping emulation"; rm -f "$CONFIG_FILE"; am broadcast -a "$PACKAGE_NAME.STOP_EMULATION" >/dev/null 2>&1; if command -v termux-notification-remove >/dev/null 2>&1; then termux-notification-remove nfc_emulation 2>/dev/null || true; fi; echo "[+] Emulation stopped"' INT TERM

while [ -f "$CONFIG_FILE" ]; do
    sleep 1
done
