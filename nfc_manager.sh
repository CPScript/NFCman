#!/bin/bash
# Updated NFCman Manager - Android Native Version. This gets rid of all Python/nfcpy dependencies and make the system work purely through Android NFC APIs instead. Fixed?

LOG_FILE="nfc_clone.log"
ANDROID_DATA_DIR="/storage/emulated/0/Android/data/com.nfcclone.app/files"
CARDS_DIR="$ANDROID_DATA_DIR/cards"
PACKAGE_NAME="com.nfcclone.app"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_android_app() {
    if ! pm list packages | grep -q "$PACKAGE_NAME"; then
        log "[!] NFC Clone app not installed"
        log "[!] Please install the APK first"
        return 1
    fi
    
    if [ ! -d "$ANDROID_DATA_DIR" ]; then
        mkdir -p "$ANDROID_DATA_DIR"
        mkdir -p "$CARDS_DIR"
    fi
    
    return 0
}

check_nfc_enabled() {
    local nfc_status=$(settings get secure nfc_enabled 2>/dev/null)
    if [ "$nfc_status" != "1" ]; then
        log "[!] NFC is disabled. Enable in Settings > Connected devices > NFC"
        return 1
    fi
    return 0
}

read_card() {
    log "[*] Starting NFC card reading through Android app..."
    
    if ! check_android_app || ! check_nfc_enabled; then
        return 1
    fi
    
    log "[*] Launching NFC reader application..."
    am start -n "$PACKAGE_NAME/.NFCReaderActivity" --activity-clear-top
    
    if [ $? -eq 0 ]; then
        log "[+] NFC reader started. Use the Android app to read cards."
        termux-notification --title "NFC Reader Active" --content "Use the NFC Clone app to read cards"
        log "[*] Cards will be saved automatically to $CARDS_DIR"
        log "[*] Return to this menu after reading cards"
    else
        log "[!] Failed to start NFC reader"
        return 1
    fi
}

list_saved_cards() {
    if [ ! -d "$CARDS_DIR" ]; then
        log "[!] No cards directory found"
        return 1
    fi
    
    log "[*] Saved cards:"
    echo "----------------------------------------"
    printf "| %-18s | %-15s |\n" "UID" "Type"
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

emulate_card() {
    log "[*] Starting card emulation..."
    
    if ! check_android_app || ! check_nfc_enabled; then
        return 1
    fi
    
    list_saved_cards
    echo
    echo -n "[?] Enter card UID to emulate: "
    read -r card_uid
    
    if [ -z "$card_uid" ]; then
        log "[!] No UID provided"
        return 1
    fi
    
    local card_file="$CARDS_DIR/card_${card_uid}.json"
    if [ ! -f "$card_file" ]; then
        log "[!] Card not found: $card_uid"
        return 1
    fi
    
    local config_file="$ANDROID_DATA_DIR/emulation_config.json"
    cat > "$config_file" << EOF
{
    "active": true,
    "card_uid": "$card_uid",
    "card_file": "$card_file",
    "timestamp": $(date +%s)
}
EOF
    
    am startservice -n "$PACKAGE_NAME/.NfcEmulatorService" \
        --es "action" "start_emulation" \
        --es "card_uid" "$card_uid"
    
    if [ $? -eq 0 ]; then
        log "[+] Emulation started for card: $card_uid"
        termux-notification --title "NFC Emulation Active" \
                           --content "Emulating: $card_uid" \
                           --priority high --ongoing
        
        echo "[*] Card emulation active. Press Ctrl+C to stop."
        trap 'stop_emulation' INT TERM
        
        while true; do
            sleep 1
            if [ ! -f "$config_file" ]; then
                break
            fi
        done
    else
        log "[!] Failed to start emulation"
        return 1
    fi
}

stop_emulation() {
    log "[*] Stopping emulation..."
    
    local config_file="$ANDROID_DATA_DIR/emulation_config.json"
    rm -f "$config_file"
    
    am broadcast -a "$PACKAGE_NAME.STOP_EMULATION"
    termux-notification-remove nfc_emulation
    
    log "[+] Emulation stopped"
    exit 0
}

modify_card() {
    list_saved_cards
    echo
    echo -n "[?] Enter card UID to modify: "
    read -r card_uid
    
    if [ -z "$card_uid" ]; then
        log "[!] No UID provided"
        return 1
    fi
    
    local card_file="$CARDS_DIR/card_${card_uid}.json"
    if [ ! -f "$card_file" ]; then
        log "[!] Card not found: $card_uid"
        return 1
    fi
    
    echo
    echo "Modification options:"
    echo "1. Set custom response"
    echo "2. Add/edit label"
    echo "3. Edit raw JSON"
    echo "4. Back to main menu"
    echo
    echo -n "[?] Choose option: "
    read -r option
    
    case $option in
        1)
            echo -n "[?] Enter custom response (hex, e.g., 9000): "
            read -r response
            if [ -n "$response" ]; then
                jq --arg resp "$response" '.custom_response = $resp' "$card_file" > "${card_file}.tmp" &&
                mv "${card_file}.tmp" "$card_file"
                log "[+] Custom response updated"
            fi
            ;;
        2)
            echo -n "[?] Enter label for card: "
            read -r label
            if [ -n "$label" ]; then
                jq --arg lbl "$label" '.label = $lbl' "$card_file" > "${card_file}.tmp" &&
                mv "${card_file}.tmp" "$card_file"
                log "[+] Label updated"
            fi
            ;;
        3)
            ${EDITOR:-nano} "$card_file"
            log "[+] Card file edited"
            ;;
        4)
            return 0
            ;;
        *)
            log "[!] Invalid option"
            ;;
    esac
}

analyze_card() {
    list_saved_cards
    echo
    echo -n "[?] Enter card UID to analyze: "
    read -r card_uid
    
    if [ -z "$card_uid" ]; then
        log "[!] No UID provided"
        return 1
    fi
    
    local card_file="$CARDS_DIR/card_${card_uid}.json"
    if [ ! -f "$card_file" ]; then
        log "[!] Card not found: $card_uid"
        return 1
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════"
    echo "                      CARD ANALYSIS: $card_uid"
    echo "═══════════════════════════════════════════════════════════════"
    
    local type=$(jq -r '.Technologies[0] // "Unknown"' "$card_file" | sed 's/.*\.//')
    local timestamp=$(jq -r '.Timestamp // 0' "$card_file")
    local date=$(date -d "@$timestamp" 2>/dev/null || echo "Unknown")
    
    echo "Primary Technology: $type"
    echo "Read Date: $date"
    echo
    
    echo "Supported Technologies:"
    jq -r '.Technologies[]? // empty' "$card_file" | sed 's/.*\./  - /'
    echo
    
    if jq -e '.NDEF' "$card_file" >/dev/null 2>&1; then
        echo "NDEF Data:"
        jq -r '.NDEF | to_entries[] | "  \(.key): \(.value)"' "$card_file"
        echo
    fi
    
    if jq -e '.MIFARE' "$card_file" >/dev/null 2>&1; then
        echo "MIFARE Information:"
        local sector_count=$(jq -r '.MIFARE.SectorCount // "Unknown"' "$card_file")
        local block_count=$(jq -r '.MIFARE.BlockCount // "Unknown"' "$card_file")
        echo "  Sectors: $sector_count"
        echo "  Blocks: $block_count"
        echo
        
        echo "Sector Data (first 32 bytes):"
        jq -r '.MIFARE.Sectors | to_entries[] | "  \(.key): \(.value | if type == "array" then .[0][:64] + "..." else . end)"' "$card_file"
        echo
    fi
    
    if jq -e '.ISO_DEP' "$card_file" >/dev/null 2>&1; then
        echo "ISO-DEP Information:"
        jq -r '.ISO_DEP | to_entries[] | select(.key != "AID_Responses") | "  \(.key): \(.value)"' "$card_file"
        
        if jq -e '.ISO_DEP.AID_Responses' "$card_file" >/dev/null 2>&1; then
            echo "  AID Responses:"
            jq -r '.ISO_DEP.AID_Responses | to_entries[] | "    \(.key): \(.value[:20])..."' "$card_file"
        fi
        echo
    fi
    
    echo "Custom Response: $(jq -r '.custom_response // "None"' "$card_file")"
    echo "Label: $(jq -r '.label // "None"' "$card_file")"
    echo "═══════════════════════════════════════════════════════════════"
}

export_card() {
    list_saved_cards
    echo
    echo -n "[?] Enter card UID to export: "
    read -r card_uid
    
    if [ -z "$card_uid" ]; then
        log "[!] No UID provided"
        return 1
    fi
    
    local card_file="$CARDS_DIR/card_${card_uid}.json"
    if [ ! -f "$card_file" ]; then
        log "[!] Card not found: $card_uid"
        return 1
    fi
    
    echo -n "[?] Export filename (or press Enter for default): "
    read -r export_name
    
    if [ -z "$export_name" ]; then
        export_name="card_${card_uid}_export.json"
    fi
    
    jq --arg export_time "$(date -Iseconds)" '{
        export_info: {
            exported_at: $export_time,
            exported_by: "NFCman",
            version: "2.0"
        },
        card_data: .
    }' "$card_file" > "$export_name"
    
    log "[+] Card exported to: $export_name"
}

import_card() {
    echo -n "[?] Enter import file path: "
    read -r import_file
    
    if [ ! -f "$import_file" ]; then
        log "[!] File not found: $import_file"
        return 1
    fi
    
    if jq -e '.card_data' "$import_file" >/dev/null 2>&1; then
        local uid=$(jq -r '.card_data.UID' "$import_file")
        jq '.card_data' "$import_file" > "$CARDS_DIR/card_${uid}.json"
    else
        local uid=$(jq -r '.UID' "$import_file")
        cp "$import_file" "$CARDS_DIR/card_${uid}.json"
    fi
    
    log "[+] Card imported: $uid"
}

delete_card() {
    list_saved_cards
    echo
    echo -n "[?] Enter card UID to delete: "
    read -r card_uid
    
    if [ -z "$card_uid" ]; then
        log "[!] No UID provided"
        return 1
    fi
    
    local card_file="$CARDS_DIR/card_${card_uid}.json"
    if [ ! -f "$card_file" ]; then
        log "[!] Card not found: $card_uid"
        return 1
    fi
    
    echo -n "[?] Delete card $card_uid? (y/N): "
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        rm "$card_file"
        log "[+] Card deleted: $card_uid"
    else
        log "[*] Deletion cancelled"
    fi
}

show_menu() {
    clear
    echo "════════════════════════════════════════════════════════════════"
    echo "║                          NFCman                              ║"
    echo "════════════════════════════════════════════════════════════════"
    echo "║  1. Launch NFC Reader App  │  5. Analyze Card                ║"
    echo "║  2. List Saved Cards       │  6. Export Card                 ║"
    echo "║  3. Emulate NFC Card       │  7. Import Card                 ║"
    echo "║  4. Modify Card Data       │  8. Delete Card                 ║"
    echo "║                            │  9. Exit                        ║"
    echo "════════════════════════════════════════════════════════════════"
    echo
    echo -n "[?] Choose option: "
}

main() {
    if ! check_android_app; then
        echo "Install the Android NFC Clone app first, then run this script."
        exit 1
    fi
    
    while true; do
        show_menu
        read -r choice
        echo
        
        case $choice in
            1) read_card ;;
            2) list_saved_cards ;;
            3) emulate_card ;;
            4) modify_card ;;
            5) analyze_card ;;
            6) export_card ;;
            7) import_card ;;
            8) delete_card ;;
            9) exit 0 ;;
            *) log "[!] Invalid option" ;;
        esac
        
        echo
        echo "Press Enter to continue..."
        read -r
    done
}

main
