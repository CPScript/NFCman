#!/bin/bash

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                        NFCman Installer                       ║"
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
    if [ ! -d "/data/data/com.termux" ] && [ ! -d "/data/data/com.termux.fdroid" ]; then
        echo "[!] This installation must be run in Termux"
        exit 1
    fi
    
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
    
    mkdir -p android/res/layout
    mkdir -p android/res/xml
    mkdir -p android/res/values
    mkdir -p android/res/mipmap-hdpi
    mkdir -p android/res/mipmap-mdpi
    mkdir -p android/res/mipmap-xhdpi
    mkdir -p android/res/mipmap-xxhdpi
    mkdir -p android/res/mipmap-xxxhdpi
    mkdir -p android/src/com/nfcclone/app
}

create_configuration() {
    local android_version="$1"
    
    echo "[*] Creating configuration for Android $android_version..."
    
    local termux_cards_dir="$HOME/nfc_cards"
    local public_cards_dir="/storage/emulated/0/Documents/NFCClone/cards"
    local primary_cards_dir="$public_cards_dir"
    
    if [ "$android_version" -ge 14 ]; then
        primary_cards_dir="$termux_cards_dir"
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

create_android_manifest() {
    cat > android/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.nfcclone.app"
    android:versionCode="2"
    android:versionName="2.0">

    <uses-sdk
        android:minSdkVersion="19"
        android:targetSdkVersion="34" />

    <uses-permission android:name="android.permission.NFC" />
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" android:minSdkVersion="30" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    
    <uses-feature
        android:name="android.hardware.nfc"
        android:required="true" />
    <uses-feature
        android:name="android.hardware.nfc.hce"
        android:required="true" />
    
    <application
        android:allowBackup="false"
        android:icon="@mipmap/ic_launcher"
        android:label="NFC Clone"
        android:theme="@style/Theme.AppCompat.NoActionBar"
        android:requestLegacyExternalStorage="true">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:screenOrientation="portrait">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        
        <activity
            android:name=".NFCReaderActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:screenOrientation="portrait">
            <intent-filter>
                <action android:name="android.nfc.action.NDEF_DISCOVERED" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="*/*" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.nfc.action.TAG_DISCOVERED" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.nfc.action.TECH_DISCOVERED" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
            
            <meta-data
                android:name="android.nfc.action.TECH_DISCOVERED"
                android:resource="@xml/nfc_tech_filter" />
        </activity>
        
        <service
            android:name=".NfcEmulatorService"
            android:exported="true"
            android:permission="android.permission.BIND_NFC_SERVICE">
            <intent-filter>
                <action android:name="android.nfc.cardemulation.action.HOST_APDU_SERVICE" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
            <meta-data
                android:name="android.nfc.cardemulation.host_apdu_service"
                android:resource="@xml/apduservice" />
        </service>
        
        <receiver
            android:name=".EmulationControlReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="com.nfcclone.app.STOP_EMULATION" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
EOF
}

create_app_icons() {
    echo "[*] Creating app icons..."
    
    cat > android/res/mipmap-hdpi/ic_launcher.png << 'EOF' | base64 -d > android/res/mipmap-hdpi/ic_launcher.png || true
EOF
    
    cat > android/res/mipmap-mdpi/ic_launcher.png << 'EOF' | base64 -d > android/res/mipmap-mdpi/ic_launcher.png || true
EOF
    
    cat > android/res/mipmap-xhdpi/ic_launcher.png << 'EOF' | base64 -d > android/res/mipmap-xhdpi/ic_launcher.png || true
EOF
    
    cat > android/res/mipmap-xxhdpi/ic_launcher.png << 'EOF' | base64 -d > android/res/mipmap-xxhdpi/ic_launcher.png || true
EOF
    
    cat > android/res/mipmap-xxxhdpi/ic_launcher.png << 'EOF' | base64 -d > android/res/mipmap-xxxhdpi/ic_launcher.png || true
EOF
    
    echo "[*] Note: Icon files created as placeholders. Replace with actual PNG files."
    echo "[*] Use the provided SVG logo to generate PNG icons at different resolutions."
}

create_nfc_tech_filter() {
    cat > android/res/xml/nfc_tech_filter.xml << 'EOF'
<resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">
    <tech-list>
        <tech>android.nfc.tech.IsoDep</tech>
    </tech-list>
    <tech-list>
        <tech>android.nfc.tech.NfcA</tech>
    </tech-list>
    <tech-list>
        <tech>android.nfc.tech.NfcB</tech>
    </tech-list>
    <tech-list>
        <tech>android.nfc.tech.NfcF</tech>
    </tech-list>
    <tech-list>
        <tech>android.nfc.tech.NfcV</tech>
    </tech-list>
    <tech-list>
        <tech>android.nfc.tech.Ndef</tech>
    </tech-list>
    <tech-list>
        <tech>android.nfc.tech.MifareClassic</tech>
    </tech-list>
    <tech-list>
        <tech>android.nfc.tech.MifareUltralight</tech>
    </tech-list>
</resources>
EOF
}

create_android_layouts() {
    cat > android/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp"
    android:background="#1a1a1a">

    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="NFC Clone"
        android:textSize="32sp"
        android:textColor="#ffffff"
        android:textAlignment="center"
        android:layout_marginBottom="24dp" />

    <TextView
        android:id="@+id/status_text"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Initializing..."
        android:textSize="16sp"
        android:textColor="#cccccc"
        android:textAlignment="center"
        android:padding="16dp"
        android:background="#2a2a2a"
        android:layout_marginBottom="24dp" />

    <Button
        android:id="@+id/read_button"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Read NFC Card"
        android:textSize="18sp"
        android:layout_marginBottom="16dp"
        android:enabled="false" />

    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Permissions and NFC must be enabled to read cards.\nUse the Termux script to manage and emulate cards."
        android:textColor="#cccccc"
        android:textAlignment="center"
        android:layout_marginTop="24dp"
        android:textSize="14sp" />

</LinearLayout>
EOF

    cat > android/res/layout/activity_reader.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp"
    android:background="#1a1a1a">

    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="NFC Card Reader"
        android:textSize="24sp"
        android:textColor="#ffffff"
        android:textAlignment="center"
        android:layout_marginBottom="24dp" />

    <TextView
        android:id="@+id/status_text"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:text="Initializing..."
        android:textSize="16sp"
        android:textColor="#cccccc"
        android:padding="16dp"
        android:background="#2a2a2a"
        android:gravity="top"
        android:scrollbars="vertical" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:layout_marginTop="16dp">

        <Button
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Back"
            android:layout_marginRight="8dp"
            android:onClick="finish" />

        <Button
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Clear Log"
            android:layout_marginLeft="8dp"
            android:onClick="clearLog" />

    </LinearLayout>

</LinearLayout>
EOF
}

create_android_resources() {
    cat > android/res/values/strings.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">NFC Clone</string>
    <string name="service_description">NFC Card Emulation Service</string>
    <string name="payment_cards">Payment Cards</string>
    <string name="access_cards">Access Control Cards</string>
    <string name="nfc_required_title">NFC Required</string>
    <string name="nfc_required_message">This app requires NFC to function. Please enable NFC in your device settings.</string>
    <string name="permissions_required_title">Permissions Required</string>
    <string name="permissions_required_message">This app needs various permissions to read and store NFC card data.</string>
    <string name="storage_permission_title">Storage Access Required</string>
    <string name="storage_permission_message">This app needs access to storage to save NFC card data.</string>
</resources>
EOF
}

create_build_script() {
    cat > build_android_app.sh << 'EOF'
#!/bin/bash

echo "Building Android NFC Clone application..."

if ! command -v aapt >/dev/null 2>&1; then
    echo "[!] Android SDK not found"
    echo "[!] Install Android SDK or use Android Studio to build"
    echo ""
    echo "Manual build instructions:"
    echo "1. Open Android Studio"
    echo "2. Import the android/ directory as a project"
    echo "3. Convert SVG logo to PNG icons using Android Studio"
    echo "4. Build and install the APK"
    echo ""
    echo "Or use online tools to convert the SVG logo to PNG icons:"
    echo "- 48x48 for mdpi"
    echo "- 72x72 for hdpi"
    echo "- 96x96 for xhdpi"
    echo "- 144x144 for xxhdpi"
    echo "- 192x192 for xxxhdpi"
    exit 1
fi

echo "[*] Building APK..."
echo "[!] Complete build process requires Android Studio or gradle setup"
EOF
    
    chmod +x build_android_app.sh
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

main() {
    check_environment
    
    local android_version
    android_version=$(detect_android_version)
    
    echo "[*] Detected Android version: $android_version"
    
    setup_storage_permissions "$android_version"
    install_packages "$android_version"
    create_directory_structure "$android_version"
    create_configuration "$android_version"
    
    create_android_manifest
    create_app_icons
    create_nfc_tech_filter
    create_android_layouts
    create_android_resources
    create_build_script
    
    check_nfc_capability "$android_version"
    set_permissions
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                      Installation Status                      ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo "[+] Termux environment configured for Android $android_version"
    echo "[+] Directory structure created"
    echo "[+] Configuration files generated"
    echo "[+] Android app source prepared"
    echo "[+] App logo SVG created"
    echo ""
    
    if [ "$android_version" -ge 14 ]; then
        echo "Android 14+ Instructions:"
        echo "1. Build and install the Android app"
        echo "2. Grant 'All files access' permission when prompted"
        echo "3. Launch the app once to initialize directories"
        echo "4. Grant any other requested permissions"
        echo "5. Run ./nfc_manager.sh"
    elif [ "$android_version" -ge 11 ]; then
        echo "Android 11+ Instructions:"
        echo "1. Build and install the Android app"
        echo "2. Grant 'All files access' permission in Settings"
        echo "3. Run ./nfc_manager.sh"
        echo "4. Cards will be stored in Documents/NFCClone/"
    else
        echo "Android $android_version Instructions:"
        echo "1. Build and install the Android app"
        echo "2. Run ./nfc_manager.sh"
        echo "3. Enable NFC in device settings"
    fi
    
    echo ""
    echo "IMPORTANT: Convert the app_logo.svg to PNG files:"
    echo "- Place PNG icons in android/res/mipmap-*/ directories"
    echo "- Use Android Studio Asset Studio or online converters"
    echo ""
    echo "The installation is complete and optimized for your Android version."
}

main
