#!/bin/bash
# Main NFC Manager Script

# Import utility functions
source ./scripts/card_utils.sh

# Configure paths and logging
LOG_FILE="nfc_clone.log"
touch "$LOG_FILE"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Check for required tools
check_dependencies() {
    local missing_deps=0
    
    # Required packages
    for cmd in python jq termux-notification am; do
        if ! command -v "$cmd" &> /dev/null; then
            log "[!] Missing dependency: $cmd"
            missing_deps=1
        fi
    done
    
    # Check for Python libraries
    if ! python3 -c "import nfc" &> /dev/null; then
        log "[!] Missing Python library: nfcpy"
        log "[!] Install with: pip install nfcpy"
        missing_deps=1
    fi
    
    if [ $missing_deps -eq 1 ]; then
        log "[!] Run ./install.sh to install dependencies"
        return 1
    fi
    
    return 0
}

# Read a new card
read_card() {
    log "[*] Reading NFC card..."
    python3 ./scripts/read_card.py
    if [ $? -eq 0 ]; then
        log "[+] Card read successfully"
    else
        log "[!] Failed to read card"
    fi
}

# Emulate a card
emulate_card() {
    log "[*] Emulate NFC card..."
    list_saved_cards
    
    echo -n "[?] Enter card UID to emulate: "
    read -r card_uid
    
    if [ -z "$card_uid" ]; then
        log "[!] No card UID provided"
        return 1
    fi
    
    # Start emulation in a new process
    ./scripts/emulate_card.sh "$card_uid"
}

# Modify card data
modify_card() {
    list_saved_cards
    
    echo -n "[?] Enter card UID to modify: "
    read -r card_uid
    
    if [ -z "$card_uid" ]; then
        log "[!] No card UID provided"
        return 1
    fi
    
    card_file=$(get_card_path "$card_uid")
    
    if [ ! -f "$card_file" ]; then
        log "[!] Card not found: $card_uid"
        return 1
    fi
    
    # Show modification options
    echo "[*] Modification options:"
    echo "  1. Edit custom response"
    echo "  2. Add label/name"
    echo "  3. Edit raw data"
    echo "  4. Back to main menu"
    
    echo -n "[?] Choose option: "
    read -r option
    
    case $option in
        1)
            echo -n "[?] Enter new custom response (hex, e.g. 9000): "
            read -r new_response
            jq ".custom_response = \"$new_response\"" "$card_file" > "${card_file}.tmp" && mv "${card_file}.tmp" "$card_file"
            log "[+] Custom response updated"
            ;;
        2)
            echo -n "[?] Enter label for this card: "
            read -r label
            jq ".label = \"$label\"" "$card_file" > "${card_file}.tmp" && mv "${card_file}.tmp" "$card_file"
            log "[+] Card label updated"
            ;;
        3)
            # Use your preferred editor
            if [ -n "$EDITOR" ]; then
                $EDITOR "$card_file"
            else
                nano "$card_file" 2>/dev/null || vi "$card_file"
            fi
            log "[+] Card data updated"
            ;;
        4)
            return 0
            ;;
        *)
            log "[!] Invalid option"
            ;;
    esac
}

# Analyze a card
analyze_card() {
    list_saved_cards
    
    echo -n "[?] Enter card UID to analyze: "
    read -r card_uid
    
    if [ -z "$card_uid" ]; then
        log "[!] No card UID provided"
        return 1
    fi
    
    python3 -c "from utils import analyze_card; analyze_card('$card_uid')"
}

# Main menu
show_menu() {
    echo ""
    echo "════════════════════════════════════"
    echo "║           MANAGER v1.0           ║"
    echo "════════════════════════════════════"
    echo "║ 1. Read NFC Card                ║"
    echo "║ 2. List Saved Cards             ║"
    echo "║ 3. Emulate NFC Card             ║"
    echo "║ 4. Modify Card Data             ║"
    echo "║ 5. Analyze Card                 ║"
    echo "║ 6. Export/Import Card           ║"
    echo "║ 7. Delete Card                  ║"
    echo "║ 8. Exit                         ║"
    echo "════════════════════════════════════"
    echo -n "[?] Choose option: "
}

# Export/import menu
export_import_menu() {
    echo ""
    echo "════════════════════════════════════"
    echo "║       EXPORT/IMPORT MENU        ║"
    echo "════════════════════════════════════"
    echo "║ 1. Export Card                  ║"
    echo "║ 2. Import Card                  ║"
    echo "║ 3. Back to Main Menu            ║"
    echo "════════════════════════════════════"
    echo -n "[?] Choose option: "
    
    read -r option
    case $option in
        1)
            list_saved_cards
            echo -n "[?] Enter card UID to export: "
            read -r card_uid
            echo -n "[?] Enter output file name (or press Enter for default): "
            read -r output_file
            export_card "$card_uid" "$output_file"
            ;;
        2)
            echo -n "[?] Enter import file path: "
            read -r import_file
            import_card "$import_file"
            ;;
        3)
            return 0
            ;;
        *)
            log "[!] Invalid option"
            ;;
    esac
}

# Delete card menu
delete_card_menu() {
    list_saved_cards
    
    echo -n "[?] Enter card UID to delete: "
    read -r card_uid
    
    if [ -z "$card_uid" ]; then
        log "[!] No card UID provided"
        return 1
    fi
    
    echo -n "[?] Are you sure you want to delete this card? (y/n): "
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        delete_card "$card_uid"
    else
        log "[*] Deletion cancelled"
    fi
}

# Main function
main() {
    # Check dependencies
    check_dependencies
    
    # Load configuration
    load_config
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1) read_card ;;
            2) list_saved_cards ;;
            3) emulate_card ;;
            4) modify_card ;;
            5) analyze_card ;;
            6) export_import_menu ;;
            7) delete_card_menu ;;
            8) exit 0 ;;
            *) echo "[!] Invalid option. Please try again." ;;
        esac
    done
}

# Run main function
main
