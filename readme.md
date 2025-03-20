> Not tested, this is a new version

---

NFCman lets you manipulate NFC cards and signals directly from your phone. With this tool, you can:
- Read and extract data from NFC cards
- Save card data for later use
- Emulate cards to unlock doors, access control systems, and other NFC readers
- Analyze card structures including MIFARE sectors
- Customize card responses for specialized systems

## Requirements

- Android device with NFC capability
- Termux installed
- Android 4.4+ (KitKat) for HCE support
- Python with nfcpy library

## Installation

1. Install Termux from Google Play or F-Droid

2. Open Termux and install required packages:
```bash
pkg update && pkg upgrade -y
pkg install git python termux-api jq -y
pip install nfcpy
```

3. Clone the repository:
```bash
git clone https://github.com/username/nfc-clone.git
cd nfc-clone
```

4. Run the installer:
```bash
chmod +x install.sh
./install.sh
```

5. Install the Android component:
   - The installer will attempt to build and install the app
   - If that fails, you'll need to manually build and install the APK

## Project Structure

```
nfc-clone/
├── android/                # Android HCE app files
│   ├── AndroidManifest.xml # App configuration
│   ├── NfcEmulatorService.java # Card emulation service
│   └── res/xml/apduservice.xml # NFC service config
├── config.json            # Framework configuration
├── install.sh             # Installation script
├── nfc_manager.sh         # Main interface script
└── scripts/               # Utility scripts
    ├── read_card.py       # Card reading script
    ├── emulate_card.sh    # Card emulation script
    ├── utils.py           # Python utilities
    └── card_utils.sh      # Bash utilities
```

## Tutorial

### 1. Reading an NFC Card

1. Start the NFC manager:
```bash
./nfc_manager.sh
```

2. Select option `1` (Read NFC Card) from the menu.

3. When prompted, place your NFC card on your device's NFC sensor:
```
[*] Place card on reader...
```

4. The framework will read the card and save its data:
```
[+] Card saved: 0A1B2C3D
[+] File: ./cards/card_0A1B2C3D.json
```

The card data is saved as a JSON file containing:
- Card UID
- Card type
- NDEF data (if available)
- MIFARE sector data (if it's a MIFARE card)
- Raw dumps for advanced analysis

### 2. Understanding the Card Data

The `read_card.py` script extracts several important elements from cards:

```python
tag_info = {
    "UID": uid,                    # Unique identifier
    "Type": str(tag),              # Card type (MIFARE, NTAG, etc.)
    "Technologies": [...],         # Supported technologies
    "Timestamp": int(time.time()), # When the card was read
}
```

For MIFARE cards, it also extracts sector data:
```python
if hasattr(tag, 'mifare'):
    sectors_data = {}
    for sector in range(16):
        try:
            blocks = tag.mifare.read_blocks(sector * 4, 4)
            sectors_data[f"sector_{sector}"] = binascii.hexlify(blocks).decode()
        except Exception as e:
            sectors_data[f"sector_{sector}"] = f"Error: {str(e)}"
    tag_info["MIFARE_Data"] = sectors_data
```

### 3. Listing Saved Cards

1. From the main menu, select option `2` (List Saved Cards).

2. You'll see a table of all saved cards:
```
[*] Saved cards:
----------------------------------------
| UID                | Type            |
----------------------------------------
| 0A1B2C3D           | MIFARE Classic  |
| E5F6G7H8           | NTAG215         |
----------------------------------------
```

The `list_saved_cards()` function in `card_utils.sh` handles this:
```bash
function list_saved_cards() {
    load_config
    
    echo "[*] Saved cards:"
    echo "----------------------------------------"
    echo "| UID                | Type            |"
    echo "----------------------------------------"
    
    find "$CARD_DATA_DIR" -name "card_*.json" | while read -r card_file; do
        if [ -f "$card_file" ]; then
            local uid=$(jq -r '.UID // "Unknown"' "$card_file")
            local type=$(jq -r '.Type // "Unknown"' "$card_file")
            local type_short=${type:0:15}
            printf "| %-18s | %-15s |\n" "$uid" "$type_short"
        fi
    done
    echo "----------------------------------------"
}
```

### 4. Analyzing a Card

1. From the main menu, select option `5` (Analyze Card).

2. Enter the UID of the card to analyze.

3. View the detailed analysis:
```
[*] Card Analysis: 0A1B2C3D
--------------------------------------------------
Type: MIFARE Classic 1K

Supported Technologies:
- mifare
- ndef

MIFARE Sectors:
sector_0: 0A1B2C3D10480804...
sector_1: 00000000000000...
...
```

The analysis is handled by the `analyze_card()` function in `utils.py`:
```python
def analyze_card(uid):
    """Analyze a saved card and print detailed information"""
    card_path = get_card_path(uid)
    
    if not os.path.exists(card_path):
        print(f"[!] Card not found: {uid}")
        return False
    
    try:
        with open(card_path, 'r') as f:
            card_data = json.load(f)
        
        print(f"\n[*] Card Analysis: {uid}")
        print("-" * 50)
        print(f"Type: {card_data.get('Type', 'Unknown')}")
        
        # More analysis code here...
    
    except Exception as e:
        print(f"[!] Error analyzing card: {str(e)}")
        return False
```

### 5. Emulating a Card

1. From the main menu, select option `3` (Emulate NFC Card).

2. Enter the UID of the card you want to emulate:
```
[?] Enter card UID to emulate: 0A1B2C3D
```

3. The emulation service will start:
```
[*] Preparing to emulate card: 0A1B2C3D
[*] Card file: ./cards/card_0A1B2C3D.json
[+] NFC emulation service started
```

The emulation process:
1. The `emulate_card.sh` script loads the card data
2. It prepares a JSON settings file with the card details
3. This is passed to the Android HCE component 
4. The Android app handles the actual emulation

Key code from `emulate_card.sh`:
```bash
# Create a temporary JSON settings file for the Android app
TEMP_SETTINGS=$(mktemp)
cat > "$TEMP_SETTINGS" << EOF
{
    "uid": "$CARD_UID",
    "card_path": "$CARD_FILE",
    "auto_response": true
}
EOF

# Copy settings to a location accessible by the app
ANDROID_STORAGE_PATH="/storage/emulated/0/Android/data/com.nfcclone.app/files"
mkdir -p "$ANDROID_STORAGE_PATH"
cp "$TEMP_SETTINGS" "$ANDROID_STORAGE_PATH/current_card.json"

# Start the NFC Emulator app
am start -n com.nfcclone.app/.MainActivity --ez "start_emulation" true
```

The core emulation occurs in `NfcEmulatorService.java`:
```java
@Override
public byte[] processCommandApdu(byte[] commandApdu, Bundle extras) {
    Log.d(TAG, "Received APDU: " + bytesToHex(commandApdu));
    
    // If no card is loaded, return failure
    if (emulatedUid == null) {
        Log.e(TAG, "No card data loaded for emulation");
        return FAILURE_SW;
    }
    
    // Process SELECT command
    if (Arrays.equals(SELECT_AID_COMMAND, commandApdu) || 
        (commandApdu.length >= 5 && commandApdu[0] == (byte)0x00 && commandApdu[1] == (byte)0xA4)) {
        Log.d(TAG, "Received SELECT command, responding with success");
        return SUCCESS_SW;
    }
    
    // Process GET UID command
    if (commandApdu.length >= 2 && commandApdu[0] == (byte)0xFF && commandApdu[1] == (byte)0xCA) {
        Log.d(TAG, "Received GET UID command, responding with UID");
        byte[] response = new byte[emulatedUid.length + 2];
        System.arraycopy(emulatedUid, 0, response, 0, emulatedUid.length);
        System.arraycopy(SUCCESS_SW, 0, response, emulatedUid.length, 2);
        return response;
    }
    
    // Use custom response if available
    if (customResponse != null) {
        return customResponse;
    }
    
    // Default response
    return SUCCESS_SW;
}
```

4. Place your phone against the NFC reader to test the emulation.

5. Press Ctrl+C to stop emulation when finished.

### 6. Modifying Card Data

1. From the main menu, select option `4` (Modify Card Data).

2. Enter the UID of the card to modify.

3. Choose a modification option:
   - Edit custom response: Change how the card responds to commands
   - Add label: Add a name to identify the card
   - Edit raw data: Directly edit the JSON card file

The custom response option is particularly useful if the original reader expects specific responses:
```bash
echo -n "[?] Enter new custom response (hex, e.g. 9000): "
read -r new_response
jq ".custom_response = \"$new_response\"" "$card_file" > "${card_file}.tmp" && mv "${card_file}.tmp" "$card_file"
```

### 7. Exporting and Importing Cards

1. From the main menu, select option `6` (Export/Import Card).

2. To export a card (to share with others or backup):
   - Select `1` (Export Card)
   - Enter the card UID
   - The card will be exported to a portable JSON format

3. To import a card:
   - Select `2` (Import Card)
   - Enter the path to the import file
   - The card will be added to your collection

## Advanced Usage

### Custom Card Responses for Specific Systems

Some access systems check for specific responses. You can customize these:

1. Log the responses from your original card using an NFC analyzer app
2. Use the "Edit custom response" option to set the same response
3. Test with the target system

### Handling Encrypted Cards

For encrypted cards (like secure MIFARE DESFire):

1. Reading will get the UID, which is often enough for basic emulation
2. Some systems check only the UID, not the encrypted content
3. If the system verifies cryptographic authentication, you'll need to use more advanced tools

### Working with Different Card Types

Different card types are handled in `read_card.py`:

- MIFARE Classic: Tries to read all sectors
- NDEF cards: Extracts NDEF records and text
- Other cards: Gets basic identification info

The Android emulation component handles various card protocols in the HCE service.

## Troubleshooting

### Card Reading Problems

- **Card not detected**: Check NFC is enabled in phone settings
- **Read errors**: Some cards use encryption or proprietary protocols
- **Incomplete data**: Some sectors may be protected, but the UID is always readable

### Emulation Issues

- **Emulation not working**: Verify Android HCE app installed correctly
- **Reader rejects emulated card**: Modern systems may detect emulation
- **Inconsistent results**: Try adjusting how you position the phone

### NFC Compatibility

- This framework works best with:
  - MIFARE Classic 1K/4K
  - NTAG21x series
  - ISO 14443-A cards
- Limited support for:
  - MIFARE DESFire
  - FeliCa
  - ISO 14443-B

## Advanced Setup: Rooting and Alternatives

### Rooting Your Android Device

Rooting provides additional capabilities for NFC manipulation, including direct memory access to the NFC controller and bypassing Android security restrictions. With root access, you can:

- Clone a wider range of NFC cards including some secured types
- Directly manipulate the NFC hardware at a lower level
- Use advanced emulation features not available through standard HCE

> ⚠️ **WARNING**: Rooting voids warranty, may trigger security measures, and could potentially brick your device if done incorrectly. Proceed at your own risk.

#### General Rooting Methods

Every Android device has a different rooting procedure. Here's a general approach:

1. **Preparation**:
   ```bash
   # Enable Developer Options:
   Settings > About Phone > Tap "Build Number" 7 times
   
   # Enable USB Debugging and OEM Unlocking:
   Settings > Developer Options > Enable both options
   
   # Install required tools on your computer:
   # ADB and Fastboot tools from Android SDK Platform Tools
   ```

2. **Unlock Bootloader**:
   ```bash
   # Connect phone to computer via USB
   adb devices                    # Verify connection
   adb reboot bootloader          # Reboot to bootloader
   
   # Unlock bootloader (exact command varies by manufacturer)
   fastboot flashing unlock       # For newer devices
   # OR
   fastboot oem unlock            # For older devices
   ```

3. **Install Custom Recovery**:
   ```bash
   # Download TWRP for your specific device from twrp.me
   fastboot flash recovery twrp-[your-device]-[version].img
   fastboot reboot recovery
   ```

4. **Install Magisk**:
   - Download latest Magisk APK from [GitHub](https://github.com/topjohnwu/Magisk/releases)
   - Rename it to Magisk.zip
   - Transfer to your device
   - In TWRP, select "Install" and choose the Magisk.zip file
   - Reboot system

#### Device-Specific Guides

For model-specific instructions, search:
- XDA Developers forums for your device model
- Manufacturer-specific methods:
  - Samsung: Use Odin with patched AP files
  - Pixel: Special fastboot commands
  - Xiaomi: Request unlock permission through Mi Unlock tool
  - OnePlus: Relatively straightforward bootloader unlock

#### Verifying Root for NFCman:

```bash
# In Termux:
pkg install root-repo
pkg install tsu
tsu                       # Should give you a # prompt if root works
whoami                    # Should display "root"

# Check NFC hardware access
ls -la /dev/nfc*          # Should show NFC device files
```

### Alternative: Using Termux with X11 Environment

If you can't or don't want to root your device, you can set up a graphical environment in Termux to use additional NFC tools through a GUI interface:

1. **Install Required Packages**:
   ```bash
   pkg update && pkg upgrade
   pkg install x11-repo
   pkg install xorg-server tigervnc xfce4 aterm
   ```

2. **Configure VNC Server**:
   ```bash
   vncserver -localhost    # Start VNC server
   # Set a password when prompted
   
   # Create startup file
   mkdir -p ~/.vnc
   cat > ~/.vnc/xstartup << 'EOF'
   #!/data/data/com.termux/files/usr/bin/bash
   xrdb $HOME/.Xresources
   xfce4-session &
   EOF
   
   chmod +x ~/.vnc/xstartup
   ```

3. **Kill existing server and restart properly**:
   ```bash
   vncserver -kill :1
   vncserver -geometry 1280x720 -localhost :1
   ```

4. **Install VNC Viewer**:
   - Install a VNC client app from Google Play (like VNC Viewer by RealVNC)
   - Configure connection to: localhost:5901
   - Enter the password you set earlier

5. **Install and Run NFC Tools in X11**:
   ```bash
   # In your VNC X11 session terminal
   pkg install python-tkinter
   
   # Install graphical NFC tools
   pip install nfcpy-gui
   
   # Create a launcher script for the NFC GUI tool
   cat > ~/nfc-gui.sh << 'EOF'
   #!/data/data/com.termux/files/usr/bin/bash
   cd $HOME
   python -c "import nfcpy_gui; nfcpy_gui.main()"
   EOF
   
   chmod +x ~/nfc-gui.sh
   ```

6. **Run the GUI Tool**:
   - From the X11 desktop, open a terminal
   - Execute `~/nfc-gui.sh`
   - The graphical NFC tool will allow you to scan and analyze cards

This X11 setup provides a desktop-like environment for working with NFC tools that have graphical interfaces, offering an alternative approach for users who prefer visual tools or cannot root their devices.

## Security Considerations

- Only clone cards you own or have permission to clone
- Be aware that bypassing access control may violate terms of service or laws
- This tool is for educational and personal use
- Cards containing financial data (credit cards, etc.) use strong encryption and cannot be cloned with this tool

## Legal Disclaimer

This framework is provided for educational purposes only. Use at your own risk and responsibility. The developers are not responsible for any misuse.
