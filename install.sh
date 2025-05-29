#!/bin/bash
# Fixed?

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                              NFCman                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# Verify Termux environment
if [ ! -d "/data/data/com.termux" ] && [ ! -d "/data/data/com.termux.fdroid" ]; then
    echo "[!] This installation must be run in Termux"
    exit 1
fi

# Request storage permission
echo "[*] Setting up storage access..."
termux-setup-storage

# Wait for user to grant permission
if [ ! -d "/storage/emulated/0" ]; then
    echo "[!] Storage permission required. Grant permission and run again."
    exit 1
fi

# Install required packages
echo "[*] Installing required packages..."
pkg update -y
pkg install -y jq termux-api android-tools

# Create directory structure
ANDROID_DATA_DIR="/storage/emulated/0/Android/data/com.nfcclone.app/files"
echo "[*] Creating directory structure..."
mkdir -p "$ANDROID_DATA_DIR/cards"
mkdir -p logs

# Set up configuration
echo "[*] Creating configuration..."
cat > config.json << 'EOF'
{
    "android_data_dir": "/storage/emulated/0/Android/data/com.nfcclone.app/files",
    "cards_dir": "/storage/emulated/0/Android/data/com.nfcclone.app/files/cards",
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
    ]
}
EOF

# Create Android app build script
echo "[*] Creating Android app build configuration..."
cat > build_android_app.sh << 'EOF'
#!/bin/bash
# Android App Build Script

echo "Building Android NFC Clone application..."

# Check for Android SDK
if ! command -v aapt >/dev/null 2>&1; then
    echo "[!] Android SDK not found"
    echo "[!] Install Android SDK or use Android Studio to build"
    echo ""
    echo "Manual build instructions:"
    echo "1. Open Android Studio"
    echo "2. Import the android/ directory as a project"
    echo "3. Build and install the APK"
    echo ""
    echo "Or download pre-built APK from releases"
    exit 1
fi

# Build commands would go here
# This would typically involve gradle build commands
echo "[*] Building APK..."
echo "[!] Complete build process requires Android Studio or gradle setup"
EOF

chmod +x build_android_app.sh

# Create the corrected layout file
echo "[*] Creating Android layout files..."
mkdir -p android/res/layout
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
        android:gravity="top" />

    <Button
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Back to Main Menu"
        android:layout_marginTop="16dp"
        android:onClick="finish" />

</LinearLayout>
EOF

# Create NFC tech filter
mkdir -p android/res/xml
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

# Create broadcast receiver for emulation control
cat > android/src/com/nfcclone/app/EmulationControlReceiver.java << 'EOF'
package com.nfcclone.app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;

public class EmulationControlReceiver extends BroadcastReceiver {
    private static final String TAG = "EmulationControl";
    
    @Override
    public void onReceive(Context context, Intent intent) {
        if ("com.nfcclone.app.STOP_EMULATION".equals(intent.getAction())) {
            Log.d(TAG, "Stopping emulation via broadcast");
            
            SharedPreferences prefs = context.getSharedPreferences("NfcClonePrefs", Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = prefs.edit();
            editor.remove("current_card_path");
            editor.apply();
            
            // Clear emulation config file
            java.io.File configFile = new java.io.File("/storage/emulated/0/Android/data/com.nfcclone.app/files/emulation_config.json");
            if (configFile.exists()) {
                configFile.delete();
            }
        }
    }
}
EOF

# Set executable permissions
echo "[*] Setting permissions..."
chmod +x nfc_manager_fixed.sh

# Check NFC availability
echo "[*] Checking NFC capability..."
if ! pm list features | grep -q "android.hardware.nfc"; then
    echo "[!] WARNING: NFC hardware not detected"
    echo "[!] This device may not support NFC functionality"
else
    echo "[+] NFC hardware detected"
fi

# Check if NFC is enabled
nfc_enabled=$(settings get secure nfc_enabled 2>/dev/null || echo "0")
if [ "$nfc_enabled" != "1" ]; then
    echo "[!] NFC is currently disabled"
    echo "[!] Enable in Settings > Connected devices > NFC"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                      Installation Status                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo "[+] Termux environment configured"
echo "[+] Directory structure created"
echo "[+] Configuration files generated"
echo "[+] Android app source prepared"
echo ""
echo "Next steps:"
echo "1. Build and install the Android app:"
echo "   - Use Android Studio to build android/ directory"
echo "   - Or install pre-built APK if available"
echo ""
echo "2. Run the fixed NFC manager:"
echo "   ./nfc_manager.sh"
echo ""
echo "3. Enable NFC in device settings if not already enabled"
echo ""
echo "The Android app component is required for NFC functionality."
echo "The original framework failed because it tried to use desktop"
echo "Linux NFC libraries on Android, which cannot work."
EOF

chmod +x install_fixed.sh
