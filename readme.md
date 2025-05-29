## I would love for people to help out and contribute on this project. Pull requests are accepted.
---

# NFCman - Android NFC Card Management Framework

**⚠️ IMPORTANT NOTICE: This software has undergone significant architectural changes and has not been tested in real-world environments. Use with extreme caution and at your own risk. The developers assume no responsibility for any consequences resulting from the use of this software.**

## Overview

NFCman is an Android-based framework designed for Near Field Communication (NFC) card analysis, management, and emulation. The system enables users to read NFC cards, analyze their structure and data, store card information for later use, and emulate cards through Android's Host Card Emulation (HCE) technology. The framework operates through a combination of a Termux-based command-line interface and a dedicated Android application.

## Recent Architectural Changes

This version represents a complete redesign of the original NFCman framework. The previous iteration attempted to use desktop Linux NFC libraries (nfcpy) within the Android environment, which created fundamental compatibility issues that prevented proper operation. The current version has been restructured to eliminate these incompatibilities.

### Key Changes Implemented

The system has been converted from a hybrid desktop-mobile architecture to a pure Android implementation. All Python-based card reading functionality that relied on the nfcpy library has been removed and replaced with direct integration to Android NFC APIs through the Java-based Android application component. The Termux interface now serves as a management layer that coordinates with the Android application rather than attempting direct NFC hardware access.

The card reading process now operates entirely through the Android NFCReaderActivity, which utilizes standard Android NFC APIs to interact with cards across multiple technologies including MIFARE Classic, MIFARE Ultralight, NTAG series, ISO14443-4, and FeliCa. Card emulation functionality continues to leverage Android's Host Card Emulation framework through the NfcEmulatorService.

## System Requirements

The framework requires an Android device with NFC capability running Android 4.4 (KitKat) or later to support Host Card Emulation features. The Termux application must be installed and configured with storage permissions. The custom Android NFC Clone application must be built and installed separately, as it handles all direct NFC operations.

## Installation Process

Begin by installing Termux from either Google Play Store or F-Droid. Open Termux and update the package repository, then install the required dependencies including git, jq, termux-api, and android-tools. Clone the NFCman repository and execute the installation script, which will configure the necessary directory structure and generate configuration files.

The Android application component requires separate compilation and installation. The installation script generates the necessary Android project structure, but the application must be built using Android Studio or a compatible development environment. Once built, install the resulting APK file on your device.

Grant the necessary permissions including NFC access, storage permissions for Termux, and any permissions requested by the NFC Clone application. Ensure that NFC is enabled in your device settings before attempting to use the framework.

## Operational Workflow

### Card Reading Operations

Launch the NFCman management script through Termux, which presents a menu-driven interface for all operations. Select the card reading option, which will launch the Android NFC Clone application. Within the application, position the target NFC card against your device's NFC sensor. The application will automatically detect the card, extract available data including UID, technology information, NDEF records, and sector data where accessible, then save the information as a JSON file in the designated storage directory.

### Card Analysis and Management

The framework provides comprehensive analysis tools for examining saved card data. Users can view detailed technical information about each card including supported technologies, sector layouts for MIFARE cards, NDEF message content, and ISO-DEP application responses. The system supports card labeling, custom response configuration, and data export for sharing or backup purposes.

### Card Emulation Process

To emulate a previously read card, select the emulation option from the management interface and specify the UID of the target card. The system will configure the Android HCE service with the stored card data and activate emulation mode. During emulation, your device will respond to NFC readers with the stored card information, effectively presenting itself as the original card.

## Technical Architecture

### Android Application Component

The NFCReaderActivity implements comprehensive NFC card reading capabilities using Android's standard NFC APIs. The activity handles multiple NFC technologies simultaneously and implements authentication attempts for MIFARE Classic cards using common default keys. The NfcEmulatorService provides Host Card Emulation functionality by processing APDU commands and responding with stored card data or configured custom responses.

### Data Storage and Management

Card information is stored in JSON format within the Android application's private storage directory. Each card file contains the complete extracted data structure including technology information, raw data dumps, and user-configured parameters such as custom responses and labels. The storage format enables both human readability and programmatic access for analysis tools.

### Integration Layer

The Termux-based management interface coordinates with the Android application through Android's Intent system and shared storage mechanisms. Configuration files enable communication between the command-line tools and the Android services, while Android's notification system provides status updates during operations.

## Security and Legal Considerations

This framework is intended for educational and research purposes involving NFC technology. Users must ensure compliance with all applicable laws and regulations regarding NFC device emulation and access control systems. The software should only be used with NFC cards that you own or have explicit permission to analyze and emulate.

Many modern access control systems implement security measures designed to detect emulation attempts. Payment cards and other high-security applications utilize cryptographic protocols that cannot be successfully emulated through this framework. The system is most effective with basic access cards and identification tags that rely primarily on UID-based authentication.

## Important Limitations and Warnings

### Testing Status

This version of NFCman represents a significant architectural redesign that has not undergone comprehensive testing in real-world environments. The integration between Termux components and the Android application may exhibit unexpected behaviors or compatibility issues with specific device configurations or Android versions.

### Hardware Compatibility

NFC implementation varies significantly across Android devices and manufacturers. The framework may not function correctly on all devices, even those that officially support NFC and HCE. Some devices may have restrictions or modifications to the NFC subsystem that prevent proper operation.

### Emulation Limitations

Host Card Emulation operates within the constraints of Android's security model and may not successfully emulate all card types or respond to all reader implementations. Modern access control systems often implement additional security measures that can detect emulation attempts.

## Troubleshooting Common Issues

If card reading operations fail, verify that NFC is enabled in device settings and that the NFC Clone application has been granted all necessary permissions. Ensure that cards are positioned correctly against the device's NFC antenna, which location varies by device model.

For emulation problems, confirm that the Android HCE service is properly registered and that the target reader system is compatible with HCE-based emulation. Some readers may require specific timing or response characteristics that differ from the framework's default configuration.

If the Termux interface cannot communicate with the Android application, verify that both components have appropriate storage permissions and that the shared directory structure has been created correctly.

## Development and Contribution

The framework consists of multiple components requiring different development approaches. The Android application component requires Android development tools and knowledge of NFC APIs, while the Termux interface utilizes standard shell scripting and JSON processing tools.

Contributors should focus on testing the framework across different device types and Android versions to identify compatibility issues and edge cases. Additional card type support, improved authentication mechanisms for MIFARE cards, and enhanced analysis tools represent areas for potential improvement.

## Disclaimer and Risk Assessment

This software is provided without warranty of any kind, either express or implied. The developers disclaim all liability for any direct, indirect, incidental, or consequential damages resulting from the use or inability to use this software. Users assume full responsibility for compliance with applicable laws and regulations.

The untested nature of this architectural revision introduces additional risks beyond those inherent in NFC manipulation tools. Unexpected behaviors could potentially damage NFC cards, interfere with legitimate access control systems, or cause device instability. Users should thoroughly test the framework in controlled environments before relying on it for any critical applications.

Given the experimental status of this version, users are strongly advised to maintain backups of any important card data and to avoid using the framework in production environments or situations where failure could result in significant inconvenience or security implications.
