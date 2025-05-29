#!/bin/bash
# NFCman Android Installation Script. Fixed?

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                            NFCman                             ║"
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
    ],
    "emulation": {
        "default_response": "9000",
        "auto_start": false,
        "notification_enabled": true
    }
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

echo "[*] Building APK..."
echo "[!] Complete build process requires Android Studio or gradle setup"
EOF

chmod +x build_android_app.sh

# Create the layout file
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

# Create MainActivity for the Android app
mkdir -p android/src/com/nfcclone/app
cat > android/src/com/nfcclone/app/MainActivity.java << 'EOF'
package com.nfcclone.app;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.view.View;

public class MainActivity extends Activity {
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        Button readButton = findViewById(R.id.read_button);
        readButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent intent = new Intent(MainActivity.this, NFCReaderActivity.class);
                startActivity(intent);
            }
        });
    }
}
EOF

# Create main activity layout
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
        android:layout_marginBottom="48dp" />

    <Button
        android:id="@+id/read_button"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Read NFC Card"
        android:textSize="18sp"
        android:layout_marginBottom="16dp" />

    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Use the Termux script to manage and emulate cards"
        android:textColor="#cccccc"
        android:textAlignment="center"
        android:layout_marginTop="24dp" />

</LinearLayout>
EOF

# Create string resources
mkdir -p android/res/values
cat > android/res/values/strings.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">NFC Clone</string>
    <string name="service_description">NFC Card Emulation Service</string>
    <string name="payment_cards">Payment Cards</string>
    <string name="access_cards">Access Control Cards</string>
</resources>
EOF

# Set executable permissions
echo "[*] Setting permissions..."
chmod +x nfc_manager.sh

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
echo "2. Run the NFC manager:"
echo "   ./nfc_manager.sh"
echo ""
echo "3. Enable NFC in device settings if not already enabled"
echo ""
echo "The Android app is required for NFC card reading and emulation."
echo "All card management is handled through the Termux interface."
