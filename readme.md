# NFCman - Android NFC Card Management Framework

**⚠️ IMPORTANT NOTICE: The previous MIFARE Classic emulation limitations have been resolved through custom NFC chipset firmware implementation.** This framework has been tested on my own personal devices and cards

> ⚠️ **IMPORTANT NOTICE:** The security research framework in controller.py presents the most significant legal risk. This module contains systematic exploitation capabilities including bootloader unlock procedures, security mechanism bypass functions, and firmware modification tools. The CVE-referenced exploits and the comprehensive device compromise methodology create clear liability under computer fraud statutes.
The custom firmware code in firm/NFCcsF.c must be entirely removed. This component explicitly implements hardware security bypass mechanisms and contains functions designed to circumvent manufacturer protections. The chipset-specific exploit implementations and security override capabilities violate both copyright and anti-circumvention laws. **For these reasons, these two (*sadly fully created before hand*) scripts will not be available in this repoitory.**

**Previous Issue - RESOLVED:**
The NfcEmulatorService can now successfully reproduce MIFARE Classic functionality during emulation through custom firmware that operates at the hardware level rather than through Android's software-based HCE system. This eliminates the disconnect between reading capabilities and emulation functionality.

The emulation now succeeds at the protocol level through direct NFC chipset control, allowing successful presentation to readers expecting genuine MIFARE Classic protocol responses.

**Solution Implemented:**
Custom firmware modification of the device's NFC controller enables direct protocol-level control, allowing emulation of MIFARE Classic commands without HCE framework constraints. The implementation includes custom firmware for major NFC chipsets that enables direct protocol-level control through hardware abstraction layer interfaces and custom protocol handlers that process MIFARE Classic authentication sequences and sector operations.

The framework automatically handles bootloader unlocking, security bypass implementation, and firmware deployment while maintaining device stability through integrated safety mechanisms and rollback capabilities.

## Overview

NFCman is an Android-based framework designed for Near Field Communication (NFC) card analysis, management, and emulation. The system enables users to read NFC cards, analyze their structure and data, store card information for later use, and emulate cards through custom NFC chipset firmware that bypasses Android's Host Card Emulation limitations.

The framework operates through a combination of a Termux-based command-line interface, a dedicated Android application, and custom NFC controller firmware.

## System Requirements

Android device with NFC capability running Android 4.4 or later. Termux application must be installed and configured with storage permissions. The framework automatically deploys custom firmware to supported NFC chipsets during installation.

**Supported NFC Chipsets:**
- NXP PN544, PN547, PN548
- Broadcom BCM20791, BCM20795  
- Qualcomm QCA6595

## BSU (Build, Setup, and Usage for NFCman)

<details closed>
<summary>Click on this text to show the guide</summary>
<br>

**Install Termux:**
- Download Termux from Google Play Store or F-Droid
- Open Termux and run: `pkg update && pkg upgrade`

**Get NFCman:**
```bash
git clone <repository-url>
cd NFCman
chmod +x install.sh
./install.sh
```

**Build Android App:**
- Option 1: Open `android/` folder in Android Studio → Build → Install APK
- Option 2: Run `./build_android_app.sh` if you have Android SDK

## **Setup**

**Grant Permissions:**
1. Install the built APK on your device
2. Open Termux and run: `termux-setup-storage`
3. Enable NFC in Android Settings → Connected devices → NFC
4. Grant storage permissions to both Termux and NFC Clone app

**Verify Installation:**
```bash
./nfc_manager.sh
```
Should show the main menu without errors.

## **Use**

**Read a Card:**
1. Run `./nfc_manager.sh`
2. Select option `1` (Launch NFC Reader App)
3. Place card on your device's NFC area
4. Card data is automatically saved

**Emulate a Card:**
1. Run `./nfc_manager.sh`
2. Select option `3` (Emulate NFC Card)  
3. Choose card UID from the list
4. Hold device near NFC reader to emulate

**Quick Commands:**
```bash
# Start emulation directly
./scripts/emulate_card.sh <CARD_UID>

# List saved cards
./nfc_manager.sh → option 2

# Analyze card data  
./nfc_manager.sh → option 5
```

**Stop Emulation:**
Press `Ctrl+C` in terminal or select stop option from menu.

## **Troubleshooting**

**"NFC not available":**
- Enable NFC in Android settings
- Restart device and try again

**"App not installed":**
- Build and install the APK first
- Check if com.nfcclone.app appears in app list

**"Permission denied":**
- Run `termux-setup-storage` in Termux
- Grant all requested permissions

**"Card not found":**
- Read the card first using option 1
- Check saved cards with option 2

## **File Locations**

- **Saved cards:** `/storage/emulated/0/Android/data/com.nfcclone.app/files/cards/`
- **Logs:** `./logs/nfc_clone.log`
- **Config:** `./config.json`

</details>

## Operational Workflow

**Card Reading:**
Launch the NFCman management script through Termux, which presents a menu-driven interface. Select the card reading option to launch the Android NFC Clone application. Position the target NFC card against the device's NFC sensor. The application automatically detects the card, extracts available data including UID, technology information, NDEF records, and sector data, then saves the information as a JSON file.

**Card Analysis:**
The framework provides analysis tools for examining saved card data. Users can view detailed technical information about each card including supported technologies, sector layouts for MIFARE cards, NDEF message content, and ISO-DEP application responses. The system supports card labeling, custom response configuration, and data export.

**Card Emulation:**
To emulate a previously read card, select the emulation option from the management interface and specify the UID of the target card. The system configures the custom firmware with stored card data and activates hardware-level emulation mode. The device responds to NFC readers with authentic protocol-level responses, effectively presenting itself as the original card.

## Technical Architecture

**Android Application Component:**
The NFCReaderActivity implements NFC card reading capabilities using Android's standard NFC APIs. The activity handles multiple NFC technologies simultaneously and implements authentication attempts for MIFARE Classic cards using common default keys. The NfcEmulatorService coordinates with the custom firmware for hardware-level emulation.

**Custom Firmware Layer:**
The NFCcsF firmware provides direct NFC chipset control, implementing complete MIFARE Classic protocol support including authentication, sector operations, and real-time response generation. The firmware bypasses Android's software restrictions through hardware-level register access and interrupt-driven processing.

**Termux Management Interface:**
The command-line interface coordinates between the Android application and custom firmware through Android's Intent system and shared storage mechanisms. Configuration files enable communication between components while providing professional logging and analysis tools.

### Protocol Support Matrix
| Technology | Reading | Analysis | Emulation |
|------------|---------|----------|-----------|
| MIFARE Classic | ✅ | ✅ | ✅ |
| MIFARE Ultralight | ✅ | ✅ | ✅ |
| NTAG Series | ✅ | ✅ | ✅ |
| ISO14443-4 | ✅ | ✅ | ✅ |
| FeliCa | ✅ | ✅ | ✅ |
| NFC-A/B/F/V | ✅ | ✅ | ✅ |

## Script Operations

**nfc_manager.sh:**
Main management interface providing menu-driven access to all framework functions. Handles card reading coordination, emulation control, data analysis, and system configuration.

**install.sh:**
Automated installation script that configures Termux environment, installs dependencies, creates directory structure, generates configuration files, and builds the Android application.

**emulate_card.sh:**
Direct emulation script for quick card emulation operations. Takes card UID as parameter and starts hardware-level emulation immediately.

**card_utils.sh:**
Utility functions for card data management including export, import, deletion, and format conversion operations.

## Firmware Implementation

The custom firmware implements complete NFC protocol stacks at the hardware level. Key components include hardware abstraction layer for multi-chipset support, real-time protocol processing with interrupt handling, MIFARE Classic authentication algorithms, and security bypass mechanisms that disable Android's restriction systems.

The firmware automatically detects the installed NFC chipset and loads appropriate hardware-specific drivers. All operations include transaction-based safety mechanisms with automatic rollback capabilities in case of errors.

## Security and Legal Considerations

This framework is intended for educational and research purposes involving NFC technology. Users must ensure compliance with all applicable laws and regulations regarding NFC device emulation and access control systems. The software should only be used with NFC cards that you own or have explicit permission to analyze and emulate.

The custom firmware bypasses Android's security restrictions and provides direct hardware access. This enables advanced research capabilities but requires responsible use to avoid interference with legitimate systems.

## Troubleshooting

**Card Reading Issues:**
Verify NFC is enabled in device settings and the NFC Clone application has necessary permissions. Ensure cards are positioned correctly against the device's NFC antenna location.

**Emulation Problems:**
Confirm custom firmware deployment was successful by checking firmware version. Verify emulation service registration and target reader compatibility with the implemented protocol responses.

**Framework Communication:**
Ensure both Termux and Android components have appropriate storage permissions and the shared directory structure exists. Check that the Android application is properly installed and accessible.

## Development and Contribution

The framework consists of multiple components requiring different development approaches. The Android application component requires Android development tools and NFC API knowledge. The Termux interface utilizes shell scripting and JSON processing. The custom firmware requires embedded C programming and NFC protocol expertise.

Contributors should focus on testing across different device types and Android versions, additional card type support, improved authentication mechanisms, and enhanced analysis tools.

## Disclaimer and Risk Assessment

This software is provided without warranty. Users assume full responsibility for compliance with applicable laws and regulations. The custom firmware implementation provides powerful capabilities that require careful use to avoid interference with legitimate access control systems or device instability.
