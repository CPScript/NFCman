#!/bin/bash

LOG_FILE="nfc_clone.log"
PACKAGE_NAME="com.nfcclone.app"
CONFIG_FILE="config.json"

ANDROID_VERSION=""
TERMUX_CARDS_DIR=""
ANDROID_DATA_DIR=""
PRIMARY_CARDS_DIR=""
USE_FALLBACK_DETECTION=""
REQUIRE_APP_INITIALIZATION=""
USE_INTERNAL_STORAGE=""

load_configuration() {
    if [ -f "$CONFIG_FILE" ]; then
        ANDROID_VERSION=$(jq -r '.android_version // 0' "$CONFIG_FILE" 2>/dev/null)
        TERMUX_CARDS_DIR=$(jq -r '.termux_cards_dir // ""' "$CONFIG_FILE" 2>/dev/null)
        ANDROID_DATA_DIR=$(jq -r '.android_data_dir // ""' "$CONFIG_FILE" 2>/dev/null)
        PRIMARY_CARDS_DIR=$(jq -r '.primary_cards_dir // ""' "$CONFIG_FILE" 2>/dev/null)
        USE_FALLBACK_DETECTION=$(jq -r '.compatibility.use_fallback_detection // false' "$CONFIG_FILE" 2>/dev/null)
        REQUIRE_APP_INITIALIZATION=$(jq -r '.compatibility.require_app_initialization // false' "$CONFIG_FILE" 2>/dev/null)
        USE_INTERNAL_STORAGE=$(jq -r '.compatibility.use_internal_storage // false' "$CONFIG_FILE" 2>/dev/null)
    fi
    
    if [ -z "$ANDROID_VERSION" ] || [ "$ANDROID_VERSION" = "0" ]; then
        ANDROID_VERSION=$(detect_android_version)
        update_configuration
    fi
    
    if [ -z "$TERMUX_CARDS_DIR" ]; then
        TERMUX_CARDS_DIR="$HOME/nfc_cards"
    fi
    
    if [ -z "$ANDROID_DATA_DIR" ]; then
        ANDROID_DATA_DIR="/storage/emulated/0/Android/data/com.nfcclone.app/files"
    fi
    
    if [ -z "$PRIMARY_CARDS_DIR" ]; then
        if [ "$ANDROID_VERSION" -ge 11 ]; then
            PRIMARY_CARDS_DIR="$TERMUX_CARDS_DIR"
        else
            PRIMARY_CARDS_DIR="$ANDROID_DATA_DIR/cards"
        fi
    fi
}

detect_android_version() {
    local version
    version=$(getprop ro.build.version.release 2>/dev/null | cut -d. -f1)
    if [ -z "$version" ]; then
        version=$(getprop ro.build.version.sdk 2>/dev/null)
        if [ "$version" -ge 33 ]; then
            version=13
        elif [ "$version" -ge 30 ]; then
            version=11
        elif [ "$version" -ge 28 ]; then
            version=9
        elif [ "$version" -ge 26 ]; then
            version=8
        elif [ "$version" -ge 23 ]; then
            version=6
        else
            version=5
        fi
    fi
    echo "$version"
}

update_configuration() {
    if [ -f "$CONFIG_FILE" ]; then
        local temp_config=$(mktemp)
        jq --arg version "$ANDROID_VERSION" '.android_version = ($version | tonumber)' "$CONFIG_FILE" > "$temp_config"
        mv "$temp_config" "$CONFIG_FILE"
    fi
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_android_app_legacy() {
    if command -v pm >/dev/null 2>&1; then
        if pm list packages 2>/dev/null | grep -q "$PACKAGE_NAME"; then
            return 0
        fi
    fi
    return 1
}

check_android_app_modern() {
    if am start -n "$PACKAGE_NAME/.MainActivity" --activity-clear-task >/dev/null 2>&1; then
        sleep 2
        return 0
    fi
    
    if [ -d "$ANDROID_DATA_DIR" ] || [ -d "/data/data/$PACKAGE_NAME" ]; then
        return 0
    fi
    
    if dumpsys package "$PACKAGE_NAME" 2>/dev/null | grep -q "versionName"; then
        return 0
    fi
    
    if dumpsys activity "$PACKAGE_NAME" 2>/dev/null | grep -q "$PACKAGE_NAME"; then
        return 0
    fi
    
    return 1
}

check_android_app() {
    log "[*] Checking if NFC Clone app is installed (Android $ANDROID_VERSION)..."
    
    local app_detected=false
    
    if [ "$USE_FALLBACK_DETECTION" = "true" ] || [ "$ANDROID_VERSION" -ge 11 ]; then
        if check_android_app_modern; then
            app_detected=true
        fi
    else
        if check_android_app_legacy; then
            app_detected=true
        else
            if check_android_app_modern; then
                app_detected=true
            fi
        fi
    fi
    
    if [ "$app_detected" = true ]; then
        log "[+] App detected"
        setup_directories
        return 0
    else
        log "[!] NFC Clone app not found"
        if [ "$REQUIRE_APP_INITIALIZATION" = "true" ]; then
            log "[!] Please install and launch the APK first (required for Android $ANDROID_VERSION)"
        else
            log "[!] Please install the APK"
        fi
        return 1
    fi
}

setup_directories() {
    log "[*] Setting up directory structure for Android $ANDROID_VERSION..."
    
    mkdir -p "$TERMUX_CARDS_DIR"
    
    if [ "$USE_INTERNAL_STORAGE" = "false" ] && [ "$ANDROID_VERSION" -lt 11 ]; then
        mkdir -p "$ANDROID_DATA_DIR" 2>/dev/null || true
        mkdir -p "$ANDROID_DATA_DIR/cards" 2>/dev/null || true
    fi
    
    if [ ! -d "$PRIMARY_CARDS_DIR" ]; then
        mkdir -p "$PRIMARY_CARDS_DIR" 2>/dev/null || {
            log "[*] Cannot create primary directory, using Termux fallback"
            PRIMARY_CARDS_DIR="$TERMUX_CARDS_DIR"
        }
    fi
    
    log "[+] Using cards directory: $PRIMARY_CARDS_DIR"
}

check_nfc_enabled_legacy() {
    local nfc_status=$(settings get secure nfc_enabled 2>/dev/null)
    if [ "$nfc_status" = "1" ]; then
        return 0
    elif [ "$nfc_status" = "0" ]; then
        return 1
    fi
    
    nfc_status=$(getprop ro.nfc.enabled 2>/dev/null)
    if [ "$nfc_status" = "1" ]; then
        return 0
    fi
    
    return 2
}

check_nfc_enabled_modern() {
    if dumpsys nfc 2>/dev/null | grep -q "mIsNfcEnabled.*true"; then
        return 0
    fi
    
    if [ -d "/sys/class/nfc" ]; then
        for nfc_device in /sys/class/nfc/nfc*; do
            if [ -f "$nfc_device/rf_mode" ]; then
                local rf_mode=$(cat "$nfc_device/rf_mode" 2>/dev/null)
                if [ "$rf_mode" != "0" ]; then
                    return 0
                fi
            fi
        done
    fi
    
    return 1
}

check_nfc_enabled() {
    local nfc_result
    
    if [ "$ANDROID_VERSION" -ge 11 ]; then
        check_nfc_enabled_modern
        nfc_result=$?
    else
        check_nfc_enabled_legacy
        nfc_result=$?
    fi
    
    case $nfc_result in
        0)
            log "[+] NFC is enabled"
            return 0
            ;;
        1)
            log "[!] NFC is disabled. Enable in Settings > Connected devices > NFC"
            return 1
            ;;
        *)
            log "[*] NFC status unknown - proceeding anyway"
            return 0
            ;;
    esac
}

start_reader_activity_legacy() {
    am start -n "$PACKAGE_NAME/.NFCReaderActivity" --activity-clear-top
}

start_reader_activity_modern() {
    if am start -n "$PACKAGE_NAME/.NFCReaderActivity" --activity-clear-top 2>/dev/null; then
        return 0
    fi
    
    if am start -n "$PACKAGE_NAME/.MainActivity" --activity-clear-top 2>/dev/null; then
        sleep 1
        am start -n "$PACKAGE_NAME/.NFCReaderActivity" 2>/dev/null || return 1
        return 0
    fi
    
    return 1
}

read_card() {
    log "[*] Starting NFC card reading..."
    
    if ! check_android_app; then
        if [ "$REQUIRE_APP_INITIALIZATION" = "true" ]; then
            log "[!] Please install and launch the NFC Clone app first"
            return 1
        else
            log "[!] Please install the NFC Clone app"
            return 1
        fi
    fi
    
    if ! check_nfc_enabled; then
        echo -n "[?] Continue anyway? (y/N): "
        read -r continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    log "[*] Launching NFC reader application..."
    
    local reader_started=false
    
    if [ "$ANDROID_VERSION" -ge 11 ]; then
        if start_reader_activity_modern; then
            reader_started=true
        fi
    else
        if start_reader_activity_legacy; then
            reader_started=true
        fi
    fi
    
    if [ "$reader_started" = true ]; then
        log "[+] NFC reader started successfully"
        
        if command -v termux-notification >/dev/null 2>&1; then
            termux-notification --title "NFC Reader Active" \
                               --content "Use the NFC Clone app to read cards" 2>/dev/null || true
        fi
        
        log "[*] Cards will be saved to: $PRIMARY_CARDS_DIR"
        log "[*] Return to this menu after reading cards"
    else
        log "[!] Failed to start app - try launching manually"
        return 1
    fi
}

list_saved_cards() {
    if [ ! -d "$PRIMARY_CARDS_DIR" ]; then
        log "[!] No cards directory found at: $PRIMARY_CARDS_DIR"
        log "[*] Read a card first to create the directory"
        return 1
    fi
    
    log "[*] Saved cards in: $PRIMARY_CARDS_DIR"
    echo "----------------------------------------"
    printf "| %-18s | %-15s |\n" "UID" "Type"
    echo "----------------------------------------"
    
    local found_cards=false
    for card_file in "$PRIMARY_CARDS_DIR"/card_*.json; do
        if [ -f "$card_file" ]; then
            local uid=$(jq -r '.UID // "Unknown"' "$card_file" 2>/dev/null)
            local type=$(jq -r '.Technologies[0] // "Unknown"' "$card_file" 2>/dev/null | sed 's/.*\.//')
            printf "| %-18s | %-15s |\n" "$uid" "${type:0:15}"
            found_cards=true
        fi
    done
    
    if [ "$ANDROID_VERSION" -ge 11 ] && [ "$PRIMARY_CARDS_DIR" != "$TERMUX_CARDS_DIR" ]; then
        for card_file in "$TERMUX_CARDS_DIR"/card_*.json; do
            if [ -f "$card_file" ]; then
                local uid=$(jq -r '.UID // "Unknown"' "$card_file" 2>/dev/null)
                local type=$(jq -r '.Technologies[0] // "Unknown"' "$card_file" 2>/dev/null | sed 's/.*\.//')
                printf "| %-18s | %-15s |\n" "$uid" "${type:0:15}"
                found_cards=true
            fi
        done
    fi
    
    if [ "$found_cards" = false ]; then
        echo "| No cards found    |                 |"
    fi
    
    echo "----------------------------------------"
}

find_card_file() {
    local card_uid="$1"
    
    if [ -f "$PRIMARY_CARDS_DIR/card_${card_uid}.json" ]; then
        echo "$PRIMARY_CARDS_DIR/card_${card_uid}.json"
        return 0
    fi
    
    if [ "$PRIMARY_CARDS_DIR" != "$TERMUX_CARDS_DIR" ] && [ -f "$TERMUX_CARDS_DIR/card_${card_uid}.json" ]; then
        echo "$TERMUX_CARDS_DIR/card_${card_uid}.json"
        return 0
    fi
    
    if [ "$PRIMARY_CARDS_DIR" != "$ANDROID_DATA_DIR/cards" ] && [ -f "$ANDROID_DATA_DIR/cards/card_${card_uid}.json" ]; then
        echo "$ANDROID_DATA_DIR/cards/card_${card_uid}.json"
        return 0
    fi
    
    return 1
}

create_emulation_config() {
    local card_uid="$1"
    local card_file="$2"
    
    local config_created=false
    local config_file=""
    
    if [ "$ANDROID_VERSION" -lt 11 ] && [ -d "$ANDROID_DATA_DIR" ]; then
        config_file="$ANDROID_DATA_DIR/emulation_config.json"
        cat > "$config_file" 2>/dev/null << EOF && config_created=true
{
    "active": true,
    "card_uid": "$card_uid",
    "card_file": "$card_file",
    "timestamp": $(date +%s)
}
EOF
    fi
    
    if [ "$config_created" = false ]; then
        config_file="$TERMUX_CARDS_DIR/emulation_config.json"
        cat > "$config_file" << EOF
{
    "active": true,
    "card_uid": "$card_uid",
    "card_file": "$card_file",
    "timestamp": $(date +%s)
}
EOF
        config_created=true
    fi
    
    echo "$config_file"
}

start_emulation_service() {
    local card_uid="$1"
    
    if [ "$ANDROID_VERSION" -ge 11 ]; then
        if am startservice -n "$PACKAGE_NAME/.NfcEmulatorService" \
            --es "action" "start_emulation" \
            --es "card_uid" "$card_uid" 2>/dev/null; then
            return 0
        fi
        
        if am start -n "$PACKAGE_NAME/.MainActivity" \
            --es "emulate_uid" "$card_uid" 2>/dev/null; then
            return 0
        fi
    else
        if am startservice -n "$PACKAGE_NAME/.NfcEmulatorService" \
            --es "action" "start_emulation" \
            --es "card_uid" "$card_uid"; then
            return 0
        fi
    fi
    
    return 1
}

emulate_card() {
    log "[*] Starting card emulation..."
    
    if ! check_android_app; then
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
    
    local card_file
    card_file=$(find_card_file "$card_uid")
    if [ $? -ne 0 ]; then
        log "[!] Card not found: $card_uid"
        return 1
    fi
    
    local config_file
    config_file=$(create_emulation_config "$card_uid" "$card_file")
    
    if start_emulation_service "$card_uid"; then
        log "[+] Emulation started for card: $card_uid"
        
        if command -v termux-notification >/dev/null 2>&1; then
            termux-notification --title "NFC Emulation Active" \
                               --content "Emulating: $card_uid" \
                               --priority high --ongoing 2>/dev/null || true
        fi
        
        echo "[*] Card emulation active. Press Ctrl+C to stop."
        trap 'stop_emulation "$config_file"' INT TERM
        
        while [ -f "$config_file" ]; do
            sleep 1
        done
    else
        log "[!] Failed to start emulation"
        log "[!] Try starting the app manually and using the emulation feature"
        return 1
    fi
}

stop_emulation() {
    local config_file="$1"
    
    log "[*] Stopping emulation..."
    
    rm -f "$config_file" 2>/dev/null
    rm -f "$ANDROID_DATA_DIR/emulation_config.json" 2>/dev/null
    rm -f "$TERMUX_CARDS_DIR/emulation_config.json" 2>/dev/null
    
    am broadcast -a "$PACKAGE_NAME.STOP_EMULATION" 2>/dev/null || true
    
    if command -v termux-notification-remove >/dev/null 2>&1; then
        termux-notification-remove nfc_emulation 2>/dev/null || true
    fi
    
    log "[+] Emulation stopped"
    exit 0
}

check_system_status() {
    log "[*] Checking system status..."
    echo
    echo "════════════════════════════════════════════════════════════════"
    echo "                         SYSTEM STATUS"
    echo "════════════════════════════════════════════════════════════════"
    
    echo "[*] Android Version: $ANDROID_VERSION"
    
    if check_android_app >/dev/null 2>&1; then
        echo "[+] Android NFC Clone app: INSTALLED"
    else
        echo "[!] Android NFC Clone app: NOT FOUND"
    fi
    
    if check_nfc_enabled >/dev/null 2>&1; then
        echo "[+] NFC: ENABLED"
    else
        echo "[!] NFC: DISABLED OR UNKNOWN"
    fi
    
    if [ -d "$PRIMARY_CARDS_DIR" ]; then
        echo "[+] Primary cards directory: ACCESSIBLE"
        echo "[*] Location: $PRIMARY_CARDS_DIR"
    else
        echo "[!] Primary cards directory: NOT ACCESSIBLE"
    fi
    
    local card_count=0
    if [ -d "$PRIMARY_CARDS_DIR" ]; then
        card_count=$(find "$PRIMARY_CARDS_DIR" -name "card_*.json" 2>/dev/null | wc -l)
    fi
    
    if [ "$PRIMARY_CARDS_DIR" != "$TERMUX_CARDS_DIR" ] && [ -d "$TERMUX_CARDS_DIR" ]; then
        local termux_count=$(find "$TERMUX_CARDS_DIR" -name "card_*.json" 2>/dev/null | wc -l)
        card_count=$((card_count + termux_count))
    fi
    
    echo "[*] Total saved cards: $card_count"
    
    if [ -w "/storage/emulated/0" ]; then
        echo "[+] Storage permissions: GRANTED"
    else
        echo "[!] Storage permissions: LIMITED"
    fi
    
    echo "[*] Configuration:"
    echo "    - Use fallback detection: $USE_FALLBACK_DETECTION"
    echo "    - Require app initialization: $REQUIRE_APP_INITIALIZATION"
    echo "    - Use internal storage: $USE_INTERNAL_STORAGE"
    
    echo "════════════════════════════════════════════════════════════════"
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
    
    local card_file
    card_file=$(find_card_file "$card_uid")
    if [ $? -ne 0 ]; then
        log "[!] Card not found: $card_uid"
        return 1
    fi
    
    echo
    echo "Modification options:"
    echo "1. Set custom response"
    echo "2. Add/edit label"
    echo "3. Edit raw JSON"
    echo "4. Copy to primary location"
    echo "5. Back to main menu"
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
            if command -v nano >/dev/null 2>&1; then
                nano "$card_file"
                log "[+] Card file edited"
            elif command -v vi >/dev/null 2>&1; then
                vi "$card_file"
                log "[+] Card file edited"
            else
                log "[!] No text editor available"
                echo "[*] Install nano: pkg install nano"
            fi
            ;;
        4)
            if [ "$card_file" != "$PRIMARY_CARDS_DIR/card_${card_uid}.json" ]; then
                cp "$card_file" "$PRIMARY_CARDS_DIR/card_${card_uid}.json"
                log "[+] Card copied to primary location"
            else
                log "[*] Card is already in primary location"
            fi
            ;;
        5)
            return 0
            ;;
        *)
            log "[!] Invalid option"
            ;;
    esac
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
    
    local card_file
    card_file=$(find_card_file "$card_uid")
    if [ $? -ne 0 ]; then
        log "[!] Card not found: $card_uid"
        return 1
    fi
    
    echo -n "[?] Delete card $card_uid? (y/N): "
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        rm "$card_file"
        
        if [ "$card_file" != "$PRIMARY_CARDS_DIR/card_${card_uid}.json" ]; then
            rm -f "$PRIMARY_CARDS_DIR/card_${card_uid}.json" 2>/dev/null
        fi
        if [ "$card_file" != "$TERMUX_CARDS_DIR/card_${card_uid}.json" ]; then
            rm -f "$TERMUX_CARDS_DIR/card_${card_uid}.json" 2>/dev/null
        fi
        
        log "[+] Card deleted: $card_uid"
    else
        log "[*] Deletion cancelled"
    fi
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
    
    local card_file
    card_file=$(find_card_file "$card_uid")
    if [ $? -ne 0 ]; then
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
            version: "2.0",
            android_version: env.ANDROID_VERSION
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
    
    local uid
    if jq -e '.card_data' "$import_file" >/dev/null 2>&1; then
        uid=$(jq -r '.card_data.UID' "$import_file")
        jq '.card_data' "$import_file" > "$PRIMARY_CARDS_DIR/card_${uid}.json"
    else
        uid=$(jq -r '.UID' "$import_file")
        cp "$import_file" "$PRIMARY_CARDS_DIR/card_${uid}.json"
    fi
    
    log "[+] Card imported: $uid"
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
    
    local card_file
    card_file=$(find_card_file "$card_uid")
    if [ $? -ne 0 ]; then
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
    echo "File Location: $card_file"
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
    fi
    
    if jq -e '.ISO_DEP' "$card_file" >/dev/null 2>&1; then
        echo "ISO-DEP Information:"
        jq -r '.ISO_DEP | to_entries[] | select(.key != "AID_Responses") | "  \(.key): \(.value)"' "$card_file"
        echo
    fi
    
    echo "Custom Response: $(jq -r '.custom_response // "None"' "$card_file")"
    echo "Label: $(jq -r '.label // "None"' "$card_file")"
    echo "═══════════════════════════════════════════════════════════════"
}

show_menu() {
    clear
    echo "════════════════════════════════════════════════════════════════"
    echo "║                   NFCman (Android $ANDROID_VERSION)                        ║"
    echo "════════════════════════════════════════════════════════════════"
    echo "║  1. Launch NFC Reader App  │  6. Analyze Card                ║"
    echo "║  2. List Saved Cards       │  7. Export Card                 ║"
    echo "║  3. Emulate NFC Card       │  8. Import Card                 ║"
    echo "║  4. Modify Card Data       │  9. Delete Card                 ║"
    echo "║  5. Check System Status    │  q. Exit                        ║"
    echo "════════════════════════════════════════════════════════════════"
    echo
    echo -n "[?] Choose option: "
}

main() {
    load_configuration
    
    if ! check_android_app; then
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        echo "                        SETUP REQUIRED"
        echo "════════════════════════════════════════════════════════════════"
        echo ""
        echo "Android $ANDROID_VERSION Setup Instructions:"
        if [ "$REQUIRE_APP_INITIALIZATION" = "true" ]; then
            echo "1. Build and install the NFC Clone APK"
            echo "2. Launch the app once to initialize directories"
            echo "3. Grant any requested permissions"
            echo "4. Return to this script"
            echo ""
            echo "The app must create its directories before this script can work."
        else
            echo "1. Build and install the NFC Clone APK"
            echo "2. Run this script again"
        fi
        echo "════════════════════════════════════════════════════════════════"
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
            5) check_system_status ;;
            6) analyze_card ;;
            7) export_card ;;
            8) import_card ;;
            9) delete_card ;;
            q|Q) exit 0 ;;
            *) log "[!] Invalid option" ;;
        esac
        
        echo
        echo "Press Enter to continue..."
        read -r
    done
}

main
