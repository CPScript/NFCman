#!/bin/bash
LOG_FILE="nfc_clone.log"
ANDROID_DATA_DIR="/storage/emulated/0/Android/data/com.nfcclone.app/files"
CARDS_DIR="$ANDROID_DATA_DIR/cards"
PACKAGE_NAME="com.nfcclone.app"
FIRMWARE_DIR="./firm"
FRAMEWORK_DIR="./framework"

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

check_firmware_framework() {
    if [ ! -f "$FRAMEWORK_DIR/framework_controller.py" ]; then
        log "[!] Security research framework not found"
        log "[*] Initializing framework components..."
        
        # Create framework directory and components
        mkdir -p "$FRAMEWORK_DIR"
        
        # Generate framework controller script
        cat > "$FRAMEWORK_DIR/framework_controller.py" << 'EOF'
#!/usr/bin/env python3
import sys
import json
import subprocess
import os
import time

class NFCFrameworkController:
    def __init__(self):
        self.device_id = None
        self.framework_initialized = False
    
    def initialize_framework(self):
        """Initialize the security research framework"""
        try:
            # Check for ADB connectivity
            result = subprocess.run(['adb', 'devices'], capture_output=True, text=True)
            if 'device' not in result.stdout:
                return False, "No ADB device connected"
            
            # Get device ID
            lines = result.stdout.strip().split('\n')[1:]
            for line in lines:
                if 'device' in line:
                    self.device_id = line.split()[0]
                    break
            
            if not self.device_id:
                return False, "Could not identify device"
            
            self.framework_initialized = True
            return True, f"Framework initialized for device: {self.device_id}"
            
        except Exception as e:
            return False, f"Framework initialization failed: {e}"
    
    def detect_nfc_chipset(self):
        """Detect NFC chipset type"""
        if not self.framework_initialized:
            return None, "Framework not initialized"
        
        try:
            # Query NFC hardware information
            cmd = ['adb', '-s', self.device_id, 'shell', 'cat /sys/class/nfc/nfc*/device/chip_id 2>/dev/null || echo "unknown"']
            result = subprocess.run(cmd, capture_output=True, text=True)
            chip_info = result.stdout.strip()
            
            # Detect chipset based on chip ID
            chipset_mappings = {
                '0x544C': 'NXP_PN544',
                '0x547C': 'NXP_PN547', 
                '0x548C': 'NXP_PN548',
                '0x2079': 'Broadcom_BCM20791',
                '0x2080': 'Broadcom_BCM20795',
                '0x6595': 'Qualcomm_QCA6595'
            }
            
            for chip_id, chipset in chipset_mappings.items():
                if chip_id in chip_info:
                    return chipset, f"Detected: {chipset}"
            
            # Fallback detection via hardware path analysis
            cmd = ['adb', '-s', self.device_id, 'shell', 'find /sys -name "*nfc*" -type d 2>/dev/null']
            result = subprocess.run(cmd, capture_output=True, text=True)
            paths = result.stdout.strip()
            
            if 'pn5' in paths.lower():
                return 'NXP_PN5XX_SERIES', 'Detected: NXP PN5XX Series'
            elif 'bcm' in paths.lower():
                return 'BROADCOM_BCM_SERIES', 'Detected: Broadcom BCM Series'
            elif 'qca' in paths.lower():
                return 'QUALCOMM_QCA_SERIES', 'Detected: Qualcomm QCA Series'
            
            return 'UNKNOWN', f'Unknown chipset, chip_info: {chip_info}'
            
        except Exception as e:
            return None, f"Chipset detection failed: {e}"
    
    def check_firmware_status(self):
        """Check if custom firmware is deployed"""
        try:
            cmd = ['adb', '-s', self.device_id, 'shell', 'cat /sys/class/nfc/nfc*/device/firmware_version 2>/dev/null || echo "unknown"']
            result = subprocess.run(cmd, capture_output=True, text=True)
            firmware_info = result.stdout.strip()
            
            # Check for custom firmware signatures
            custom_signatures = ['nfcman_custom', 'bypass_enabled', 'unrestricted', 'custom_fw']
            
            for signature in custom_signatures:
                if signature in firmware_info.lower():
                    return True, f"Custom firmware detected: {firmware_info}"
            
            return False, f"Stock firmware detected: {firmware_info}"
            
        except Exception as e:
            return False, f"Firmware status check failed: {e}"
    
    def deploy_firmware(self, chipset_type):
        """Deploy custom firmware for detected chipset"""
        try:
            firmware_file = f"../firm/NFCcsF_{chipset_type.lower()}.bin"
            
            if not os.path.exists(firmware_file):
                # Use generic firmware if specific variant not available
                firmware_file = "../firm/NFCcsF"
            
            if not os.path.exists(firmware_file):
                return False, f"Firmware file not found: {firmware_file}"
            
            # Execute security bypass sequence
            bypass_success = self._execute_security_bypass()
            if not bypass_success:
                return False, "Security bypass failed"
            
            # Deploy firmware
            deployment_success = self._deploy_firmware_binary(firmware_file)
            if not deployment_success:
                return False, "Firmware deployment failed"
            
            # Verify deployment
            time.sleep(3)  # Allow firmware to initialize
            deployed, status = self.check_firmware_status()
            
            if deployed:
                return True, f"Firmware deployment successful: {status}"
            else:
                return False, f"Firmware verification failed: {status}"
                
        except Exception as e:
            return False, f"Firmware deployment error: {e}"
    
    def _execute_security_bypass(self):
        """Execute security bypass sequence"""
        bypass_commands = [
            # Disable Android security mechanisms
            'su -c "setprop persist.vendor.nfc.secure_mode 0" 2>/dev/null || true',
            'su -c "setprop persist.nfc.secure_element 0" 2>/dev/null || true',
            
            # Disable dm-verity if possible
            'su -c "echo 0 > /sys/module/dm_verity/parameters/enabled" 2>/dev/null || true',
            
            # Set NFC controller to unrestricted mode
            'su -c "echo unrestricted > /sys/class/nfc/nfc*/device/mode" 2>/dev/null || true'
        ]
        
        for cmd in bypass_commands:
            adb_cmd = ['adb', '-s', self.device_id, 'shell', cmd]
            subprocess.run(adb_cmd, capture_output=True)
        
        return True
    
    def _deploy_firmware_binary(self, firmware_file):
        """Deploy firmware binary to device"""
        try:
            # Transfer firmware to device
            transfer_cmd = ['adb', '-s', self.device_id, 'push', firmware_file, '/data/local/tmp/custom_firmware.bin']
            result = subprocess.run(transfer_cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                return False
            
            # Flash firmware (this is a simplified representation)
            flash_commands = [
                'su -c "chmod 644 /data/local/tmp/custom_firmware.bin"',
                'su -c "cat /data/local/tmp/custom_firmware.bin > /sys/class/nfc/nfc*/device/firmware_update" 2>/dev/null || true',
                'su -c "echo 1 > /sys/class/nfc/nfc*/device/reset" 2>/dev/null || true'
            ]
            
            for cmd in flash_commands:
                adb_cmd = ['adb', '-s', self.device_id, 'shell', cmd]
                subprocess.run(adb_cmd, capture_output=True)
            
            return True
            
        except Exception as e:
            print(f"Firmware deployment error: {e}")
            return False

if __name__ == "__main__":
    controller = NFCFrameworkController()
    
    if len(sys.argv) < 2:
        print("Usage: framework_controller.py <command> [args]")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "init":
        success, message = controller.initialize_framework()
        print(json.dumps({"success": success, "message": message}))
    
    elif command == "detect_chipset":
        success, message = controller.initialize_framework()
        if success:
            chipset, status = controller.detect_nfc_chipset()
            print(json.dumps({"chipset": chipset, "status": status}))
        else:
            print(json.dumps({"error": message}))
    
    elif command == "check_firmware":
        success, message = controller.initialize_framework()
        if success:
            deployed, status = controller.check_firmware_status()
            print(json.dumps({"deployed": deployed, "status": status}))
        else:
            print(json.dumps({"error": message}))
    
    elif command == "deploy_firmware":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "Chipset type required"}))
            sys.exit(1)
        
        chipset_type = sys.argv[2]
        success, message = controller.initialize_framework()
        if success:
            deployed, status = controller.deploy_firmware(chipset_type)
            print(json.dumps({"success": deployed, "message": status}))
        else:
            print(json.dumps({"error": message}))
    
    else:
        print(json.dumps({"error": f"Unknown command: {command}"}))
EOF
        
        chmod +x "$FRAMEWORK_DIR/framework_controller.py"
        log "[+] Framework components initialized"
    fi
    
    return 0
}

initialize_firmware_framework() {
    log "[*] Initializing firmware deployment framework..."
    
    if ! check_firmware_framework; then
        log "[!] Framework initialization failed"
        return 1
    fi
    
    # Initialize the framework
    local result=$(python3 "$FRAMEWORK_DIR/framework_controller.py" init 2>/dev/null)
    local success=$(echo "$result" | jq -r '.success // false' 2>/dev/null)
    
    if [ "$success" = "true" ]; then
        log "[+] Framework initialized successfully"
        return 0
    else
        local message=$(echo "$result" | jq -r '.message // "Unknown error"' 2>/dev/null)
        log "[!] Framework initialization failed: $message"
        return 1
    fi
}

detect_nfc_chipset() {
    log "[*] Detecting NFC chipset..."
    
    local result=$(python3 "$FRAMEWORK_DIR/framework_controller.py" detect_chipset 2>/dev/null)
    local chipset=$(echo "$result" | jq -r '.chipset // "UNKNOWN"' 2>/dev/null)
    local status=$(echo "$result" | jq -r '.status // "Detection failed"' 2>/dev/null)
    
    log "[*] $status"
    echo "$chipset"
}

check_custom_firmware() {
    log "[*] Checking firmware status..."
    
    local result=$(python3 "$FRAMEWORK_DIR/framework_controller.py" check_firmware 2>/dev/null)
    local deployed=$(echo "$result" | jq -r '.deployed // false' 2>/dev/null)
    local status=$(echo "$result" | jq -r '.status // "Status unknown"' 2>/dev/null)
    
    log "[*] $status"
    
    if [ "$deployed" = "true" ]; then
        return 0
    else
        return 1
    fi
}

deploy_custom_firmware() {
    log "[*] Starting custom firmware deployment..."
    
    if ! check_android_app || ! check_nfc_enabled; then
        return 1
    fi
    
    # Initialize framework
    if ! initialize_firmware_framework; then
        log "[!] Cannot proceed without framework"
        return 1
    fi
    
    # Detect chipset
    local chipset=$(detect_nfc_chipset)
    if [ "$chipset" = "UNKNOWN" ]; then
        log "[!] Cannot deploy firmware for unknown chipset"
        log "[!] Manual firmware deployment may be required"
        return 1
    fi
    
    # Check if already deployed
    if check_custom_firmware; then
        log "[+] Custom firmware already deployed and active"
        return 0
    fi
    
    # Deploy firmware
    log "[*] Deploying firmware for chipset: $chipset"
    log "[!] This operation requires root access and may take several minutes"
    echo -n "[?] Continue with firmware deployment? (y/N): "
    read -r confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log "[*] Firmware deployment cancelled"
        return 0
    fi
    
    local result=$(python3 "$FRAMEWORK_DIR/framework_controller.py" deploy_firmware "$chipset" 2>/dev/null)
    local success=$(echo "$result" | jq -r '.success // false' 2>/dev/null)
    local message=$(echo "$result" | jq -r '.message // "Deployment failed"' 2>/dev/null)
    
    if [ "$success" = "true" ]; then
        log "[+] $message"
        log "[+] Hardware-level emulation now available"
        termux-notification --title "Firmware Deployed" --content "Custom NFC firmware active"
        return 0
    else
        log "[!] $message"
        log "[!] Falling back to software-based emulation"
        return 1
    fi
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
    
    # Check firmware status and offer deployment
    local hardware_emulation=false
    if check_custom_firmware; then
        log "[+] Custom firmware detected - hardware-level emulation available"
        hardware_emulation=true
    else
        log "[*] Custom firmware not detected - using software emulation"
        echo -n "[?] Deploy custom firmware for enhanced emulation? (y/N): "
        read -r deploy_fw
        
        if [[ $deploy_fw =~ ^[Yy]$ ]]; then
            if deploy_custom_firmware; then
                hardware_emulation=true
            fi
        fi
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
    
    # Create emulation configuration
    local config_file="$ANDROID_DATA_DIR/emulation_config.json"
    cat > "$config_file" << EOF
{
    "active": true,
    "card_uid": "$card_uid",
    "card_file": "$card_file",
    "hardware_emulation": $hardware_emulation,
    "timestamp": $(date +%s)
}
EOF
    
    # Start emulation service
    local emulation_mode="software-based HCE"
    if [ "$hardware_emulation" = "true" ]; then
        emulation_mode="hardware-level"
    fi
    
    am startservice -n "$PACKAGE_NAME/.NfcEmulatorService" \
        --es "action" "start_emulation" \
        --es "card_uid" "$card_uid" \
        --ez "hardware_mode" "$hardware_emulation"
    
    if [ $? -eq 0 ]; then
        log "[+] Emulation started for card: $card_uid ($emulation_mode)"
        termux-notification --title "NFC Emulation Active" \
                           --content "Emulating: $card_uid ($emulation_mode)" \
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

check_firmware_status() {
    log "[*] Checking system status..."
    echo
    echo "════════════════════════════════════════════════════════════════"
    echo "                         SYSTEM STATUS"
    echo "════════════════════════════════════════════════════════════════"
    
    # Check Android app
    if pm list packages | grep -q "$PACKAGE_NAME"; then
        echo "[+] Android NFC Clone app: INSTALLED"
    else
        echo "[!] Android NFC Clone app: NOT INSTALLED"
    fi
    
    # Check NFC status
    local nfc_status=$(settings get secure nfc_enabled 2>/dev/null)
    if [ "$nfc_status" = "1" ]; then
        echo "[+] NFC: ENABLED"
    else
        echo "[!] NFC: DISABLED"
    fi
    
    # Check framework
    if [ -f "$FRAMEWORK_DIR/framework_controller.py" ]; then
        echo "[+] Firmware framework: INITIALIZED"
        
        # Initialize and check firmware
        if initialize_firmware_framework >/dev/null 2>&1; then
            local chipset=$(detect_nfc_chipset)
            echo "[+] NFC Chipset: $chipset"
            
            if check_custom_firmware >/dev/null 2>&1; then
                echo "[+] Custom firmware: DEPLOYED"
                echo "[+] Emulation mode: HARDWARE-LEVEL"
            else
                echo "[*] Custom firmware: NOT DEPLOYED"
                echo "[*] Emulation mode: SOFTWARE (HCE)"
            fi
        else
            echo "[!] Framework: CONNECTION FAILED"
        fi
    else
        echo "[*] Firmware framework: NOT INITIALIZED"
    fi
    
    # Check saved cards
    local card_count=0
    if [ -d "$CARDS_DIR" ]; then
        card_count=$(find "$CARDS_DIR" -name "card_*.json" | wc -l)
    fi
    echo "[*] Saved cards: $card_count"
    
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
    echo "║  1. Launch NFC Reader App  │  6. Analyze Card                ║"
    echo "║  2. List Saved Cards       │  7. Export Card                 ║"
    echo "║  3. Emulate NFC Card       │  8. Import Card                 ║"
    echo "║  4. Deploy Custom Firmware │  9. Delete Card                 ║"
    echo "║  5. Modify Card Data       │  0. Check System Status         ║"
    echo "║                            │  q. Exit                        ║"
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
            4) deploy_custom_firmware ;;
            5) modify_card ;;
            6) analyze_card ;;
            7) export_card ;;
            8) import_card ;;
            9) delete_card ;;
            0) check_firmware_status ;;
            q|Q) exit 0 ;;
            *) log "[!] Invalid option" ;;
        esac
        
        echo
        echo "Press Enter to continue..."
        read -r
    done
}

main
