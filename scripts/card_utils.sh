#!/bin/bash
# Utility functions for NFC card operations

# Load configuration
function load_config() {
    if [ -f "config.json" ]; then
        CARD_DATA_DIR=$(jq -r '.card_data_dir // "./cards"' config.json)
        NFC_READER=$(jq -r '.nfc_reader // "usb"' config.json)
    else
        CARD_DATA_DIR="./cards"
        NFC_READER="usb"
    fi
    
    # Create cards directory if it doesn't exist
    mkdir -p "$CARD_DATA_DIR"
}

# Get path for a card file
function get_card_path() {
    local uid="$1"
    load_config
    echo "${CARD_DATA_DIR}/card_${uid}.json"
}

# List all saved cards
function list_saved_cards() {
    load_config
    
    echo "[*] Saved cards:"
    echo "----------------------------------------"
    echo "| UID                | Type            |"
    echo "----------------------------------------"
    
    # Find all card files
    find "$CARD_DATA_DIR" -name "card_*.json" | while read -r card_file; do
        if [ -f "$card_file" ]; then
            local uid=$(jq -r '.UID // "Unknown"' "$card_file")
            local type=$(jq -r '.Type // "Unknown"' "$card_file")
            local type_short=${type:0:15}
            printf "| %-18s | %-15s |\n" "$uid" "$type_short"
        fi
    done
    echo "----------------------------------------"
}

# Delete a saved card
function delete_card() {
    local uid="$1"
    local card_file=$(get_card_path "$uid")
    
    if [ -f "$card_file" ]; then
        rm "$card_file"
        echo "[+] Card deleted: $uid"
        return 0
    else
        echo "[!] Card not found: $uid"
        return 1
    fi
}

# Export a card to a portable format
function export_card() {
    local uid="$1"
    local output_file="$2"
    local card_file=$(get_card_path "$uid")
    
    if [ -z "$output_file" ]; then
        output_file="card_${uid}_export.json"
    fi
    
    if [ -f "$card_file" ]; then
        # Create a simplified export with essential data
        jq '{
            UID: .UID,
            Type: .Type,
            ExportTime: now | tostring,
            RawData: .RawData,
            custom_response: .custom_response
        }' "$card_file" > "$output_file"
        
        echo "[+] Card exported to: $output_file"
        return 0
    else
        echo "[!] Card not found: $uid"
        return 1
    fi
}

# Import a card from exported format
function import_card() {
    local import_file="$1"
    
    if [ ! -f "$import_file" ]; then
        echo "[!] Import file not found: $import_file"
        return 1
    fi
    
    # Validate the import file
    if ! jq -e '.UID' "$import_file" > /dev/null; then
        echo "[!] Invalid card format. Missing UID."
        return 1
    fi
    
    local uid=$(jq -r '.UID' "$import_file")
    local card_file=$(get_card_path "$uid")
    
    # Check if card already exists
    if [ -f "$card_file" ]; then
        echo -n "[?] Card already exists. Override? (y/n): "
        read -r answer
        if [[ ! $answer =~ ^[Yy]$ ]]; then
            echo "[*] Import cancelled"
            return 0
        fi
    fi
    
    # Copy the import file
    cp "$import_file" "$card_file"
    echo "[+] Card imported: $uid"
    return 0
}
