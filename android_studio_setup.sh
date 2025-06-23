#!/bin/bash

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                            NFCman                             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo "[*] Delete Default files..."
rm -rf app/src/main/res/xml
rm -rf app/src/main/res/values-night
rm -rf app/src/main/res/values
rm app/src/main/AndroidManifest.xml

echo "[*] Clone Reposetory"
git clone https://github.com/CPScript/NFCman

echo "[*] Copy files into Project"
mkdir -p app/src/main/res/xml
cp NFCman/android/res/xml/apduservice.xml app/src/main/res/xml
cp NFCman/android/src/com/nfcclone/app/NFCReaderActivity.java app/src/main/java/com/nfcclone/app
cp NFCman/android/src/com/nfcclone/app/NfcEmulatorService.java app/src/main/java/com/nfcclone/app
cp NFCman/android/AndroidManifest.xml app/src/main

# Create the layout file
echo "[*] Creating Android layout files..."
mkdir -p app/src/main/res/layout
cat > app/src/main/res/layout/activity_reader.xml << 'EOF'
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
cat > app/src/main/res/xml/nfc_tech_filter.xml << 'EOF'
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
cat > app/src/main/java/com/nfcclone/app/MainActivity.java << 'EOF'
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
cat > app/src/main/res/layout/activity_main.xml << 'EOF'
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
mkdir -p app/src/main/res/values
cat > app/src/main/res/values/strings.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">NFC Clone</string>
    <string name="service_description">NFC Card Emulation Service</string>
    <string name="payment_cards">Payment Cards</string>
    <string name="access_cards">Access Control Cards</string>
</resources>
EOF

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                      Installation Status                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo "[+] Android app source prepared"
