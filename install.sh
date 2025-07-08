goto windows
#!/bin/bash

set -e

echo """
CONTRIBUTERS
--------------
@Lolig4 | Setup scripts and bug help
"""

sleep 2

detect_environment() {
    if [ -d "/data/data/com.termux" ] || [ -d "/data/data/com.termux.fdroid" ]; then
        echo "termux"
    elif [ -n "$DISPLAY" ] || [ "$OS" = "Windows_NT" ] || command -v uname >/dev/null 2>&1 && [[ $(uname) =~ ^(Linux|Darwin|CYGWIN|MINGW|MSYS)$ ]]; then
        echo "pc"
    else
        echo "unknown"
    fi
}

termux_install() {
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                        NFCman Installer                       ║"
    echo "║                         Termux Mode                           ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"

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

    check_environment() {
        if [ "$(id -u)" = "0" ]; then
            echo "[!] Do not run this script as root"
            echo "[!] Run as normal Termux user"
            exit 1
        fi
    }

    setup_storage_permissions() {
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

    install_packages() {
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

    create_directory_structure() {
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

    create_configuration() {
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

    set_permissions() {
        echo "[*] Setting permissions..."
        chmod +x nfc_manager.sh 2>/dev/null || true
        chmod +x scripts/emulate_card.sh 2>/dev/null || true
        chmod +x scripts/card_utils.sh 2>/dev/null || true
    }

    check_existing_files() {
        echo "[*] Checking for existing files..."
        
        if [ ! -f "nfc_manager.sh" ]; then
            echo "[!] nfc_manager.sh not found in repository"
            echo "[!] Please ensure you have the complete NFCman repository"
            exit 1
        fi
        
        if [ ! -d "scripts" ]; then
            echo "[!] scripts directory not found in repository"
            echo "[!] Please ensure you have the complete NFCman repository"
            exit 1
        fi
        
        if [ ! -d "android" ]; then
            echo "[!] android directory not found in repository"
            echo "[!] Please ensure you have the complete NFCman repository"
            exit 1
        fi
        
        echo "[+] All required files found in repository"
    }

    main() {
        check_environment
        check_existing_files
        
        local android_version
        android_version=$(detect_android_version)
        
        echo "[*] Detected Android version: $android_version"
        
        setup_storage_permissions "$android_version"
        install_packages "$android_version"
        create_directory_structure "$android_version"
        create_configuration "$android_version"
        
        check_nfc_capability "$android_version"
        set_permissions
        
        echo ""
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║                      Installation Status                      ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo "[+] Termux environment configured for Android $android_version"
        echo "[+] Directory structure created"
        echo "[+] Configuration files generated"
        echo "[+] Repository files are ready to use"
        echo ""
        
        if [ "$android_version" -ge 14 ]; then
            echo "Android 14+ Instructions:"
            echo "1. Build and install the Android app (use PC setup for Android Studio)"
            echo "2. Grant 'All files access' permission when prompted"
            echo "3. Launch the app once to initialize directories"
            echo "4. Grant any other requested permissions"
            echo "5. Run ./nfc_manager.sh"
        elif [ "$android_version" -ge 11 ]; then
            echo "Android 11+ Instructions:"
            echo "1. Build and install the Android app (use PC setup for Android Studio)"
            echo "2. Grant 'All files access' permission in Settings"
            echo "3. Run ./nfc_manager.sh"
            echo "4. Cards will be stored in Documents/NFCClone/"
        else
            echo "Android $android_version Instructions:"
            echo "1. Build and install the Android app (use PC setup for Android Studio)"
            echo "2. Run ./nfc_manager.sh"
            echo "3. Enable NFC in device settings"
        fi
        
        echo ""
        echo "To build the Android app, run this script on your PC/laptop."
        echo "The Termux installation is complete and optimized for your Android version."
    }

    main
}

DOWNLOADER=""
detect_downloader() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
    else
        echo "[*] Neither curl nor wget found. Please install one."
        exit 1
    fi
}

pc_install() {
    # SCRIPT_URL="https://raw.githubusercontent.com/CPScript/NFCman/main/setup/android_studio_setup.sh"
    SCRIPT_URL="https://raw.githubusercontent.com/Lolig4/NFCman/main/setup/android_studio_setup.sh"
    SCRIPT_PATH="$(dirname "$(realpath "$0")")/android_studio_setup.sh"

    if [[ $DOWNLOADER == "curl" ]]; then
        curl -L "$SCRIPT_URL" -o "$SCRIPT_PATH"
    else
        wget -O "$SCRIPT_PATH" "$SCRIPT_URL"
    fi

    chmod +x "$SCRIPT_PATH"
    exec "$SCRIPT_PATH" "$@"
}

update_script() {
    echo "[*] Updating script to latest version..."
        
    # SCRIPT_URL="https://raw.githubusercontent.com/CPScript/NFCman/main/install.sh"
    SCRIPT_URL="https://raw.githubusercontent.com/Lolig4/NFCman/main/install.sh"
    SCRIPT_PATH="$(realpath "$0")"
    TMP_FILE="$(mktemp)"

    if [[ $DOWNLOADER == "curl" ]]; then
        curl -fsSL "$SCRIPT_URL" -o "$TMP_FILE"
    else
        wget -q "$SCRIPT_URL" -O "$TMP_FILE"
    fi

    cp "$SCRIPT_PATH" "$SCRIPT_PATH.bak"
    mv "$TMP_FILE" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    echo "[*] Restarting script with updated version..."
    echo ""
    exec "$SCRIPT_PATH" "$@" "--updated"
}

main() {
    detect_downloader

    if [[ "$1" == "--updated" ]]; then
        shift
    else
        update_script "$@"
    fi
    local environment=$(detect_environment)
    
    case $environment in
        "termux")
            termux_install
            ;;
        "pc")
            pc_install
            ;;
        "unknown")
            echo "╔═══════════════════════════════════════════════════════════════╗"
            echo "║                    Environment Detection                      ║"
            echo "╚═══════════════════════════════════════════════════════════════╝"
            echo ""
            echo "[!] Could not detect environment automatically"
            echo ""
            echo "Please run this script:"
            echo "• On Android device in Termux for device setup"
            echo "• On PC/laptop for Android Studio project setup"
            echo ""
            echo "Force environment selection:"
            echo "• For Termux: FORCE_TERMUX=1 ./install.sh"
            echo "• For PC: FORCE_PC=1 ./install.sh"
            exit 1
            ;;
    esac
}

if [ "$FORCE_TERMUX" = "1" ]; then
    termux_install
elif [ "$FORCE_PC" = "1" ]; then
    pc_install
else
    main "$@"
fi
exit 1

:windows
@echo off
echo Windows
setlocal EnableDelayedExpansion

:: set "SCRIPT_URL=https://raw.githubusercontent.com/CPScript/NFCman/main/install.sh"
set "UPDATE_URL=https://raw.githubusercontent.com/Lolig4/NFCman/main/install.sh"
set "THIS_SCRIPT=%~f0"
set "TMP_FILE=%TEMP%\install_update.sh"

set "UPDATED=false"
for %%A in (%*) do (
    if "%%A"=="--updated" set "UPDATED=true"
)

if /I "!UPDATED!"=="false" (
    powershell -Command "Invoke-WebRequest -Uri '!UPDATE_URL!' -OutFile '!TMP_FILE!'"
    copy /Y "!THIS_SCRIPT!" "!THIS_SCRIPT!.bak" >nul
    move /Y "!TMP_FILE!" "!THIS_SCRIPT!" >nul
    start "" cmd /c ""!THIS_SCRIPT!" --updated"
    exit /b
)

:: set "SCRIPT_URL=https://raw.githubusercontent.com/CPScript/NFCman/main/setup/windows_setup_script.bat"
set "SETUP_URL=https://raw.githubusercontent.com/Lolig4/NFCman/main/setup/windows_setup_script.bat"
set "SCRIPT_DIR=%~dp0"
set "SETUP_PATH=%SCRIPT_DIR%android_studio_setup.bat"
powershell -Command "Invoke-WebRequest -Uri '!SETUP_URL!' -OutFile '!SETUP_PATH!'"
start "" cmd /c ""!SETUP_PATH!""
exit /b