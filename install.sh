#!/bin/bash

set -e

echo """
CONTRIBUTERS
--------------
@Lolig4 | Setup scripts and bug help
"""

sleep (2)

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

pc_install() {
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                     Setup Android Studio                      ║"
    echo "║                           PC Mode                             ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"

    echo "[*] Setting up PC development environment..."

    if command -v inkscape >/dev/null 2>&1; then
        IMG_CMD="inkscape"
    elif command -v magick >/dev/null 2>&1; then
        IMG_CMD="magick"
    else
        echo "[*] Neither Inkscape or ImageMagick v7+ found. Please install one."
        echo "[*] Please note that ImageMagick can't produce a transparent background."
        exit 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "[*] Git is not installed."
        echo "[*] Please install Git"
        exit 1
    fi

    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
    else
        echo "[*] Neither curl or wget found. Please install one."
        exit 1
    fi

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

    URL="https://avatars.githubusercontent.com/u/83523587?s=48&v=4"
    DEST="ic_launcher.jpeg"
    readarray -t SVG_PATHS < <(find . -type f -iname '*.svg')
    count=${#SVG_PATHS[@]}
    
    if (( count == 0 )); then
        echo "[*] No SVG found!"
        echo "[*] Would you like to use CPScript's profile picture as a fallback? (y/N)"
        read -r REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "[*] Download CPScript's profile picture..."
            if [[ $DOWNLOADER == "curl" ]]; then
                curl -L "$URL" -o "$DEST"
            elif [[ $DOWNLOADER == "wget" ]]; then
                wget -O "$DEST" "$URL"
            fi
            IMAGE=$DEST
        else
            echo "[*] Please drop a SVG into your Android Studio project."
            exit 1
        fi
    elif (( count == 1 )); then
        IMAGE="${SVG_PATHS[0]}"
        echo "[*] SVG found: $IMAGE"
    else
        echo "[*] More than one SVG found! Please ensure that only one SVG is in your Android Studio project."
        exit 1
    fi

    echo "[*] Deleting default files..."
    rm -rf app/src/main/res
    rm -rf app/src/main/java/com/nfcclone/app
    rm -f app/src/main/AndroidManifest.xml

    echo "[*] Cloning repository..."
    git clone https://github.com/CPScript/NFCman

    echo "[*] Copying files into project..."
    cp -r NFCman/android/res app/src/main/
    cp -r NFCman/android/src/com app/src/main/java/
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
    find app/src/main/res -type f -name "*.xml" -exec sed -i '/^<!-- .* -->$/d' {} + 2>/dev/null || \
    find app/src/main/res -type f -name "*.xml" -exec sed '/^<!-- .* -->$/d' {} \; 2>/dev/null || true

    echo "[*] Create ic_launcher.png..."
    declare -A SIZES=(
      [mdpi]=48
      [hdpi]=72
      [xhdpi]=96
      [xxhdpi]=144
      [xxxhdpi]=192
    )

    for DENSITY in "${!SIZES[@]}"; do
      SIZE=${SIZES[$DENSITY]}
      OUT_DIR="app/src/main/res/mipmap-$DENSITY"
      OUT_FILE="$OUT_DIR/ic_launcher.png"
      
      echo "[*] Generating ${DENSITY} (${SIZE}×${SIZE})..."
      mkdir -p "$OUT_DIR"
      
      if [[ $IMG_CMD == "inkscape" ]]; then
        inkscape "$IMAGE" \
          --export-background-opacity=0 \
          --export-filename="$OUT_FILE" \
          --export-width="$SIZE" \
          --export-height="$SIZE"
      elif [[ $IMG_CMD == "magick" ]]; then
        magick "$IMAGE" -resize "${SIZE}x${SIZE}" "$OUT_FILE"
      fi
    done

    echo "[*] Setting up Gradle configuration..."
    
    cat > app/build.gradle << 'EOF'
apply plugin: 'com.android.application'

android {
    compileSdkVersion 34
    buildToolsVersion "34.0.0"
    
    defaultConfig {
        applicationId "com.nfcclone.app"
        minSdkVersion 19
        targetSdkVersion 34
        versionCode 2
        versionName "2.0"
        
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }
    
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            debuggable false
        }
        debug {
            debuggable true
            minifyEnabled false
        }
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
    
    packagingOptions {
        pickFirst '**/libjsc.so'
        pickFirst '**/libc++_shared.so'
    }
}

dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.core:core:1.10.1'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
    implementation 'com.google.android.material:material:1.9.0'
    
    testImplementation 'junit:junit:4.13.2'
    androidTestImplementation 'androidx.test.ext:junit:1.1.5'
    androidTestImplementation 'androidx.test.espresso:espresso-core:3.5.1'
}
EOF

    cat > app/proguard-rules.pro << 'EOF'
# Add project specific ProGuard rules here.

# Keep NFC related classes
-keep class com.nfcclone.app.** { *; }

# Keep JSON parsing
-keepattributes Signature
-keepattributes *Annotation*
-keep class org.json.** { *; }

# Keep NFC technology classes
-keep class android.nfc.** { *; }
-keep class android.nfc.tech.** { *; }

# Keep HCE service
-keep class * extends android.nfc.cardemulation.HostApduService {
    public <init>(...);
    public <methods>;
}

# Keep broadcast receivers
-keep class * extends android.content.BroadcastReceiver {
    public <init>(...);
    public <methods>;
}
EOF

    echo "[*] Cleaning up..."
    rm -rf NFCman
    if [[ $IMAGE == "ic_launcher.jpeg" ]]; then
        rm $IMAGE
    fi

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    PC Setup Complete                          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo "[+] Android Studio project structure created"
    echo "[+] Repository files copied to proper locations"
    echo "[+] App icon configured from SVG/fallback image"
    echo "[+] Gradle configuration applied"
    echo "[+] ProGuard rules configured"
    echo ""
    echo "Next steps:"
    echo "1. Open this project in Android Studio"
    echo "2. Sync the project (File → Sync Project with Gradle Files)"
    echo "3. Build the project (Build → Make Project)"
    echo "4. Generate APK (Build → Build Bundle(s) / APK(s) → Build APK(s))"
    echo "5. Install APK on your Android device"
    echo "6. Run the Termux script on your device: ./nfc_manager.sh"
    echo ""
}

main() {
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
    main
fi
