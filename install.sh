#!/bin/bash

set -e

echo """
Contributers;
-------------
@Lolig4 | Setup scripts and bug help
"""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                        NFCman Installer                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

detect_environment() {
    if [ -d "/data/data/com.termux" ] || [ -d "/data/data/com.termux.fdroid" ]; then
        echo "termux"
    elif [ -f "/proc/version" ] && grep -q "Linux" /proc/version && [ -z "$ANDROID_ROOT" ]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

detect_android_version() {
    local version
    version=$(getprop ro.build.version.release 2>/dev/null | cut -d. -f1)
    if [ -z "$version" ]; then
        version=$(getprop ro.build.version.sdk 2>/dev/null)
        if [ "$version" -ge 34 ]; then
            version=14
        elif [ "$version" -ge 33 ]; then
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

check_termux_environment() {
    if [ "$(id -u)" = "0" ]; then
        echo "[!] Do not run this script as root in Termux"
        echo "[!] Run as normal Termux user"
        exit 1
    fi
}

setup_termux_storage_permissions() {
    local android_version="$1"
    
    echo "[*] Setting up storage access for Android $android_version..."
    
    if command -v termux-setup-storage >/dev/null 2>&1; then
        termux-setup-storage
    fi
    
    local storage_accessible=false
    local attempts=0
    while [ $attempts -lt 10 ]; do
        if [ -d "/storage/emulated/0" ] && [ -w "/storage/emulated/0" ]; then
            storage_accessible=true
            break
        fi
        attempts=$((attempts + 1))
        sleep 1
    done
    
    if [ "$storage_accessible" = false ]; then
        echo "[!] Storage permission required. Grant permission and run again."
        exit 1
    fi
}

install_termux_packages() {
    local android_version="$1"
    
    echo "[*] Installing required packages for Android $android_version..."
    
    if ! command -v pkg >/dev/null 2>&1; then
        echo "[!] Termux package manager not available"
        exit 1
    fi
    
    pkg update -y 2>/dev/null || pkg update -y --force
    
    local packages="jq android-tools"
    
    if [ "$android_version" -ge 10 ]; then
        packages="$packages termux-api"
    fi
    
    for package in $packages; do
        if ! pkg install -y "$package" 2>/dev/null; then
            echo "[!] Failed to install $package, trying alternative..."
            pkg install -y --force "$package" 2>/dev/null || true
        fi
    done
}

create_termux_directory_structure() {
    local android_version="$1"
    
    echo "[*] Creating directory structure for Android $android_version..."
    
    mkdir -p "$HOME/nfc_cards"
    mkdir -p logs
    
    local public_dir="/storage/emulated/0/Documents/NFCClone"
    mkdir -p "$public_dir/cards" 2>/dev/null || true
    
    if [ "$android_version" -lt 11 ]; then
        local legacy_dir="/storage/emulated/0/NFCClone"
        mkdir -p "$legacy_dir/cards" 2>/dev/null || true
    fi
}

create_termux_configuration() {
    local android_version="$1"
    
    echo "[*] Creating configuration for Android $android_version..."
    
    local termux_cards_dir="$HOME/nfc_cards"
    local public_cards_dir="/storage/emulated/0/Documents/NFCClone/cards"
    local primary_cards_dir="$public_cards_dir"
    
    if [ "$android_version" -ge 14 ]; then
        primary_cards_dir="$termux_cards_dir"
    elif [ "$android_version" -lt 11 ]; then
        primary_cards_dir="/storage/emulated/0/NFCClone/cards"
    fi
    
    cat > config.json << EOF
{
    "android_version": $android_version,
    "termux_cards_dir": "$termux_cards_dir",
    "public_cards_dir": "$public_cards_dir",
    "primary_cards_dir": "$primary_cards_dir",
    "enable_logging": true,
    "log_file": "./logs/nfc_clone.log",
    "supported_card_types": [
        "MIFARE Classic",
        "MIFARE Ultralight", 
        "NTAG213",
        "NTAG215",
        "NTAG216",
        "ISO14443-4",
        "FeliCa"
    ],
    "emulation": {
        "default_response": "9000",
        "auto_start": false,
        "notification_enabled": true
    },
    "compatibility": {
        "use_fallback_detection": $([ "$android_version" -ge 11 ] && echo true || echo false),
        "require_app_initialization": $([ "$android_version" -ge 13 ] && echo true || echo false),
        "use_internal_storage": $([ "$android_version" -ge 14 ] && echo true || echo false),
        "require_manage_external_storage": $([ "$android_version" -ge 11 ] && echo true || echo false)
    }
}
EOF
}

check_nfc_capability() {
    local android_version="$1"
    
    echo "[*] Checking NFC capability..."
    
    local nfc_available=false
    
    if command -v pm >/dev/null 2>&1; then
        if pm list features 2>/dev/null | grep -q "android.hardware.nfc"; then
            nfc_available=true
        fi
    fi
    
    if [ "$nfc_available" = false ]; then
        if [ -d "/sys/class/nfc" ] || [ -f "/proc/bus/input/devices" ] && grep -q "nfc" /proc/bus/input/devices 2>/dev/null; then
            nfc_available=true
        fi
    fi
    
    if [ "$nfc_available" = true ]; then
        echo "[+] NFC hardware detected"
    else
        echo "[!] WARNING: NFC hardware not detected"
        echo "[!] This device may not support NFC functionality"
    fi
    
    local nfc_enabled="unknown"
    if command -v settings >/dev/null 2>&1; then
        nfc_enabled=$(settings get secure nfc_enabled 2>/dev/null || echo "unknown")
    fi
    
    if [ "$nfc_enabled" = "1" ]; then
        echo "[+] NFC is enabled"
    elif [ "$nfc_enabled" = "0" ]; then
        echo "[!] NFC is currently disabled"
        echo "[!] Enable in Settings > Connected devices > NFC"
    else
        echo "[*] NFC status unknown - check device settings"
    fi
}

set_termux_permissions() {
    echo "[*] Setting permissions..."
    chmod +x nfc_manager.sh 2>/dev/null || true
    chmod +x scripts/emulate_card.sh 2>/dev/null || true
    chmod +x scripts/card_utils.sh 2>/dev/null || true
}

install_termux() {
    local android_version
    android_version=$(detect_android_version)
    
    echo "[*] Detected Android version: $android_version"
    echo "[*] Setting up Termux environment..."
    
    check_termux_environment
    setup_termux_storage_permissions "$android_version"
    install_termux_packages "$android_version"
    create_termux_directory_structure "$android_version"
    create_termux_configuration "$android_version"
    check_nfc_capability "$android_version"
    set_termux_permissions
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                      Termux Setup Complete                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo "[+] Termux environment configured for Android $android_version"
    echo "[+] Directory structure created"
    echo "[+] Configuration files generated"
    echo ""
    
    if [ "$android_version" -ge 14 ]; then
        echo "Android 14+ Instructions:"
        echo "1. Build and install the Android app (use PC setup)"
        echo "2. Grant 'All files access' permission when prompted"
        echo "3. Launch the app once to initialize directories"
        echo "4. Grant any other requested permissions"
        echo "5. Run ./nfc_manager.sh"
    elif [ "$android_version" -ge 11 ]; then
        echo "Android 11+ Instructions:"
        echo "1. Build and install the Android app (use PC setup)"
        echo "2. Grant 'All files access' permission in Settings"
        echo "3. Run ./nfc_manager.sh"
        echo "4. Cards will be stored in Documents/NFCClone/"
    else
        echo "Android $android_version Instructions:"
        echo "1. Build and install the Android app (use PC setup)"
        echo "2. Run ./nfc_manager.sh"
        echo "3. Enable NFC in device settings"
    fi
    
    echo ""
    echo "The Termux installation is complete."
}

check_pc_dependencies() {
    local missing_deps=()
    
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        missing_deps+=("curl or wget")
    fi
    
    if ! command -v magick >/dev/null 2>&1; then
        missing_deps+=("ImageMagick v7+ (magick command)")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "[!] Missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "    - $dep"
        done
        echo ""
        echo "Please install the missing dependencies and run again."
        exit 1
    fi
}

setup_android_studio_project() {
    echo "[*] Setting up Android Studio project structure..."
    
    if [ ! -d "app" ]; then
        echo "[!] This script should be run from an Android Studio project root"
        echo "[!] Expected 'app' directory not found"
        echo ""
        echo "Instructions:"
        echo "1. Create a new Android Studio project"
        echo "2. Copy this script to the project root"
        echo "3. Run the script from there"
        exit 1
    fi
    
    echo "[*] Deleting default files..."
    rm -rf NFCman 2>/dev/null || true
    rm -rf app/src/main/res 2>/dev/null || true
    rm -rf app/src/main/java/com/nfcclone/app 2>/dev/null || true
    rm -f app/src/main/AndroidManifest.xml 2>/dev/null || true
    
    echo "[*] Cloning repository..."
    git clone https://github.com/CPScript/NFCman
    
    echo "[*] Creating directory structure..."
    mkdir -p app/src/main/java/com/nfcclone
    mkdir -p app/src/main/res
    
    echo "[*] Copying files into project..."
    cp -r NFCman/android/res/* app/src/main/res/
    cp -r NFCman/android/src/com/nfcclone/app app/src/main/java/com/nfcclone/
    cp NFCman/android/AndroidManifest.xml app/src/main/
    
    echo "[*] Extracting EmulationControlReceiver class..."
    SOURCE_FILE="app/src/main/java/com/nfcclone/app/NfcEmulatorService.java"
    TARGET_FILE="app/src/main/java/com/nfcclone/app/EmulationControlReceiver.java"
    
    if [ -f "$SOURCE_FILE" ]; then
        awk '
          /\/\* EmulationControlReceiver.java \*\// { inside=1; next }
          inside {
            brace_level += gsub(/\{/, "{")
            brace_level -= gsub(/\}/, "}")
            print
            if (brace_level == 0 && /}/) exit
          }
        ' "$SOURCE_FILE" > "$TARGET_FILE"
        
        awk '
          /\/\* EmulationControlReceiver.java \*\// { inside=1; next }
          inside {
            brace_level += gsub(/\{/, "{")
            brace_level -= gsub(/\}/, "}")
            if (brace_level == 0 && /}/) { inside=0; next }
            next
          }
          { print }
        ' "$SOURCE_FILE" > temp.java && mv temp.java "$SOURCE_FILE"
        
        echo "[*] EmulationControlReceiver class extracted successfully"
    fi
    
    echo "[*] Cleaning XML files..."
    find app/src/main/res -type f -name "*.xml" -exec sed -i '/^<!-- .* -->$/d' {} + 2>/dev/null || true
    
    echo "[*] Setting up app icon..."
    ICON_URL="https://avatars.githubusercontent.com/u/83523587?s=48&v=4"
    TEMP_ICON="app/src/main/res/mipmap-mdpi/ic_launcher.jpeg"
    
    mkdir -p app/src/main/res/mipmap-mdpi
    
    if command -v curl >/dev/null 2>&1; then
        curl -L "$ICON_URL" -o "$TEMP_ICON"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$TEMP_ICON" "$ICON_URL"
    fi
    
    if [ -f "$TEMP_ICON" ]; then
        magick "$TEMP_ICON" app/src/main/res/mipmap-mdpi/ic_launcher.png
        rm "$TEMP_ICON"
        echo "[*] App icon created successfully"
    fi
    
    echo "[*] Copying Gradle configuration..."
    if [ -f "NFCman/android/build.gradle" ]; then
        cp NFCman/android/build.gradle app/build.gradle
    fi
    
    if [ -f "NFCman/android/proguard-rules.pro" ]; then
        cp NFCman/android/proguard-rules.pro app/proguard-rules.pro
    fi
    
    echo "[*] Cleaning up..."
    rm -rf NFCman
}

install_pc() {
    echo "[*] Setting up PC development environment..."
    
    check_pc_dependencies
    setup_android_studio_project
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    PC Setup Complete                          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo "[+] Android Studio project structure created"
    echo "[+] Repository files copied to proper locations"
    echo "[+] App icon configured"
    echo "[+] Gradle configuration applied"
    echo ""
    echo "Next steps:"
    echo "1. Open this project in Android Studio"
    echo "2. Sync the project (File → Sync Project with Gradle Files)"
    echo "3. Build the project (Build → Make Project)"
    echo "4. Generate APK (Build → Build Bundle(s) / APK(s) → Build APK(s))"
    echo "5. Install APK on your Android device"
    echo ""
    echo "For Termux setup, run this script on your Android device in Termux."
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --force-termux    Force Termux installation (override detection)"
    echo "  --force-pc        Force PC installation (override detection)"
    echo "  --help           Show this help message"
    echo ""
    echo "The script automatically detects your environment:"
    echo "  - Termux: Sets up card management and NFC tools"
    echo "  - PC: Sets up Android Studio project structure"
}

main() {
    local force_env=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force-termux)
                force_env="termux"
                shift
                ;;
            --force-pc)
                force_env="pc"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo "[!] Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    local environment
    if [ -n "$force_env" ]; then
        environment="$force_env"
        echo "[*] Forced environment: $environment"
    else
        environment=$(detect_environment)
        echo "[*] Detected environment: $environment"
    fi
    
    case $environment in
        termux)
            install_termux
            ;;
        linux|macos|windows|pc)
            install_pc
            ;;
        *)
            echo "[!] Unsupported environment: $environment"
            echo ""
            echo "This script supports:"
            echo "  - Termux (Android)"
            echo "  - Linux/macOS/Windows (PC)"
            echo ""
            echo "Use --force-termux or --force-pc to override detection."
            exit 1
            ;;
    esac
}

main "$@"
