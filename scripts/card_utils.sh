#!/bin/bash

function load_config() {
    if [ -f "config.json" ]; then
        TERMUX_CARDS_DIR=$(jq -r '.termux_cards_dir // ""' config.json)
        PUBLIC_CARDS_DIR=$(jq -r '.public_cards_dir // ""' config.json)
        PRIMARY_CARDS_DIR=$(jq -r '.primary_cards_dir // ""' config.json)
    fi
    
    if [ -z "$TERMUX_CARDS_DIR" ]; then
        TERMUX_CARDS_DIR="$HOME/nfc_cards"
    fi
    
    if [ -z "$PUBLIC_CARDS_DIR" ]; then
        PUBLIC_CARDS_DIR="/storage/emulated/0/Documents/NFCClone/cards"
    fi
    
    if [ -z "$PRIMARY_CARDS_DIR" ]; then
        PRIMARY_CARDS_DIR="$PUBLIC_CARDS_DIR"
    fi
    
    mkdir -p "$TERMUX_CARDS_DIR"
    mkdir -p "$PRIMARY_CARDS_DIR" 2>/dev/null || true
}

function get_card_path() {
    local uid="$1"
    local all_locations=(
        "$PRIMARY_CARDS_DIR"
        "$TERMUX_CARDS_DIR"
        "$PUBLIC_CARDS_DIR"
        "/storage/emulated/0/NFCClone/cards"
        "/storage/emulated/0/Documents/NFCClone/cards"
    )
    
    for location in "${all_locations[@]}"; do
        if [ -f "$location/card_${uid}.json" ]; then
            echo "$location/card_${uid}.json"
            return 0
        fi
    done
    
    echo "${PRIMARY_CARDS_DIR}/card_${uid}.json"
    return 1
}

function list_saved_cards() {
    load_config
    
    echo "[*] Saved cards:"
    echo "----------------------------------------"
    echo "| UID                | Type            |"
    echo "----------------------------------------"
    
    local all_locations=(
        "$PRIMARY_CARDS_DIR"
        "$TERMUX_CARDS_DIR"
        "$PUBLIC_CARDS_DIR"
        "/storage/emulated/0/NFCClone/cards"
        "/storage/emulated/0/Documents/NFCClone/cards"
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

function delete_card() {
    local uid="$1"
    load_config
    
    local all_locations=(
        "$PRIMARY_CARDS_DIR"
        "$TERMUX_CARDS_DIR"
        "$PUBLIC_CARDS_DIR"
        "/storage/emulated/0/NFCClone/cards"
        "/storage/emulated/0/Documents/NFCClone/cards"
    )
    
    local deleted=false
    for location in "${all_locations[@]}"; do
        local card_file="$location/card_${uid}.json"
        if [ -f "$card_file" ]; then
            rm "$card_file"
            deleted=true
        fi
    done
    
    if [ "$deleted" = true ]; then
        echo "[+] Card deleted: $uid"
        return 0
    else
        echo "[!] Card not found: $uid"
        return 1
    fi
}

function export_card() {
    local uid="$1"
    local output_file="$2"
    load_config
    
    if [ -z "$output_file" ]; then
        output_file="card_${uid}_export.json"
    fi
    
    local card_file=$(get_card_path "$uid")
    if [ $? -eq 0 ] && [ -f "$card_file" ]; then
        jq '{
            UID: .UID,
            Type: (.Technologies[0] // "Unknown"),
            ExportTime: now | tostring,
            RawData: .,
            custom_response: .custom_response
        }' "$card_file" > "$output_file"
        
        echo "[+] Card exported to: $output_file"
        return 0
    else
        echo "[!] Card not found: $uid"
        return 1
    fi
}

function import_card() {
    local import_file="$1"
    load_config
    
    if [ ! -f "$import_file" ]; then
        echo "[!] Import file not found: $import_file"
        return 1
    fi
    
    if ! jq -e '.UID' "$import_file" > /dev/null 2>&1; then
        echo "[!] Invalid card format. Missing UID."
        return 1
    fi
    
    local uid=$(jq -r '.UID' "$import_file")
    local card_file="${PRIMARY_CARDS_DIR}/card_${uid}.json"
    
    if [ -f "$card_file" ]; then
        echo -n "[?] Card already exists. Override? (y/n): "
        read -r answer
        if [[ ! $answer =~ ^[Yy]$ ]]; then
            echo "[*] Import cancelled"
            return 0
        fi
    fi
    
    cp "$import_file" "$card_file"
    echo "[+] Card imported: $uid"
    return 0
}
