Includes;

* Android app (android/)
* Desktop Software (controller.py)
* Firmware (firm/)
* Termux Framework (everything else)

---

# NFCman - Android NFC Card Research Framework

**⚠️ IMPORTANT NOTICE: This framework provides legitimate NFC research capabilities within Android's standard security model. Advanced emulation features operate within Host Card Emulation constraints.**

> **SECURITY ADVISORY:** The security research components in controller.py present significant legal and operational risks. These modules contain systematic exploitation methodologies and firmware modification tools that violate computer fraud statutes. The custom firmware implementation assumes hardware access capabilities that do not exist in standard Android security architectures.

## Overview

NFCman is a comprehensive Android-based framework designed for Near Field Communication research, card analysis, and standards-compliant emulation. The system enables researchers to read NFC cards across multiple protocols, analyze their technical structure and data organization, maintain a research database of card information, and perform emulation within Android's Host Card Emulation framework limitations.

The framework operates through an integrated architecture combining a Termux-based command-line interface with a dedicated Android application optimized for NFC research workflows.

## Functional Capabilities

The framework provides legitimate NFC research functionality through Android's standard APIs. Card reading capabilities support MIFARE Classic, MIFARE Ultralight, NTAG series, ISO14443-4, and FeliCa technologies with comprehensive data extraction including UID information, technology specifications, NDEF message content, and sector structure analysis for supported card types.

Card emulation operates within Android's Host Card Emulation framework, supporting ISO14443-4 cards, NDEF-based applications, and basic contactless payment protocols where permitted by device configuration. The system cannot bypass Android's MIFARE Classic emulation restrictions, which exist due to hardware-level protocol requirements.

Analysis tools provide detailed technical examination of card structures, protocol compliance verification, security parameter assessment, and comparative analysis across card types and manufacturers.

## Device Requirements

### Hardware Prerequisites

Android devices must include dedicated NFC hardware with support for ISO14443 Type A and Type B protocols. The device must provide Host Card Emulation capability through Android's standard NFC service implementation. NFC antenna positioning and power characteristics significantly impact reading reliability and should be verified through device specification documentation.

### Supported NFC Controllers

The framework operates with standard Android NFC implementations across major controller manufacturers including NXP semiconductors PN5xx series, Broadcom BCM207xx series, and Qualcomm QCA65xx series. No custom firmware modification is required or attempted, ensuring compatibility with manufacturer security implementations.

### Android Version Compatibility

**Android 13 and Later:**
Modern Android versions implement enhanced storage scoping and permission models that require application initialization before Termux script operation. The framework automatically detects API level 33+ environments and adjusts directory access patterns accordingly. Enhanced security features may limit certain analysis capabilities while maintaining core functionality.

**Android 11-12:**
These versions provide optimal framework compatibility with mature NFC API implementations and manageable storage access patterns. Host Card Emulation functionality operates reliably across device manufacturers. The framework utilizes scoped storage while maintaining compatibility with legacy access patterns where appropriate.

**Android 8-10:**
Earlier Android versions support comprehensive framework functionality with direct storage access and simplified permission models. NFC API implementations may vary across manufacturers, requiring device-specific testing for optimal compatibility. Some advanced analysis features may require alternative implementation approaches.

**Android 6-7:**
Legacy Android versions provide basic framework support with potential limitations in Host Card Emulation capability and storage management. The framework includes compatibility layers for older API implementations while maintaining core research functionality.

## Technical Architecture

### Android Application Components

The NFCReaderActivity implements comprehensive NFC card detection and data extraction using Android's standard NFC APIs. The activity manages multiple technology detection simultaneously, implements appropriate authentication sequences for supported card types, and provides real-time feedback during card reading operations.

The NfcEmulatorService coordinates Host Card Emulation functionality within Android's security constraints. The service registers appropriate Application Identifier configurations, processes APDU command sequences according to ISO7816 specifications, and maintains emulation state through Android's standard service lifecycle.

### Termux Management Interface

The command-line interface provides professional research workflow management through structured menu systems, comprehensive logging capabilities, and detailed card analysis tools. The interface coordinates with Android components through Intent messaging and shared storage mechanisms while maintaining data integrity across framework operations.

### Data Management System

Card information storage utilizes structured JSON formats with comprehensive metadata including extraction timestamps, device configuration details, and protocol-specific technical parameters. The system maintains referential integrity across card databases and provides export capabilities for research documentation and collaboration.

## Installation and Setup

### Prerequisites Installation

Install Termux from F-Droid or Google Play Store to ensure compatibility with modern Android security models. Configure Termux storage access through the setup-storage command to enable framework file operations. Verify NFC hardware functionality through Android system settings before proceeding with framework installation.

### Framework Deployment

```bash
git clone https://github.com/CPScript/NFCman
cd NFCman
chmod +x install.sh
./install.sh
```

The installation script automatically detects Android version, configures appropriate storage permissions, installs required dependencies through Termux package management, creates directory structures compatible with detected Android security model, and generates configuration files optimized for the target environment.

### Android Application Build

Framework operation requires building and installing the companion Android application. Open the android directory in Android Studio and configure build parameters according to target device specifications. Generate signed APK through standard Android development workflows and install on target device with appropriate permissions.

[I need more Help](setup/android_studio_guide.md)

Alternative build approaches include gradle command-line compilation for environments with Android SDK access, though Android Studio provides optimal compatibility verification and dependency management.

### Permission Configuration

Grant storage access permissions to both Termux and the NFCman Android application through Android system settings. Enable NFC functionality in device settings and verify Host Card Emulation availability through NFC service configuration. Some devices may require additional manufacturer-specific NFC settings adjustment.

### Verification Process

Execute the management script through ./nfc_manager.sh and verify that all framework components initialize without errors. Test basic NFC reading functionality with available cards to confirm proper API integration and data extraction capability.

## Operational Procedures

### Card Reading Workflow

Launch the NFCman management interface and select the card reading option to initialize the Android NFC reader activity. Position target cards against the device NFC antenna according to manufacturer specifications and maintain stable contact throughout the reading process. The framework automatically detects supported technologies and extracts comprehensive card data including protocol-specific information and security parameters.

### Data Analysis Capabilities

The framework provides detailed analysis of extracted card data through multiple examination modes. Technical analysis displays protocol compliance information, sector organization for structured cards, and security implementation details. Comparative analysis enables research across multiple cards to identify patterns, manufacturer variations, and implementation differences.

### Emulation Operations

Card emulation operates within Android's Host Card Emulation constraints using previously extracted card data. Select target cards from the framework database and configure emulation parameters according to research requirements. The system activates Host Card Emulation services and responds to reader interrogation with stored card information where protocol compatibility permits.

### Research Documentation

The framework maintains comprehensive logging of all operations including detailed timestamps, device configuration snapshots, and protocol interaction records. Export capabilities enable research documentation and collaboration through standardized data formats compatible with external analysis tools.

## Protocol Support Matrix

| Technology | Reading Support | Analysis Capability | Emulation Compatibility |
|------------|----------------|--------------------|-----------------------|
| MIFARE Classic | Full | Comprehensive | Limited (HCE constraints) |
| MIFARE Ultralight | Full | Comprehensive | Partial |
| NTAG Series | Full | Comprehensive | Good |
| ISO14443-4 | Full | Comprehensive | Full |
| FeliCa | Full | Basic | Limited |
| NFC-A/B/F/V | Full | Comprehensive | Protocol-dependent |

## Compatibility Considerations

### Android Version Differences

Framework operation adapts automatically to detected Android API levels with version-specific optimizations for storage access patterns, permission management approaches, and NFC API utilization. Modern Android versions may impose additional restrictions on certain analysis capabilities while maintaining core research functionality.

### Device Manufacturer Variations

NFC implementations vary significantly across device manufacturers, requiring framework adaptation for optimal compatibility. The system includes manufacturer-specific configuration options and fallback mechanisms for environments with non-standard NFC implementations.

### Hardware Limitations

NFC antenna characteristics, power management approaches, and controller implementations directly impact framework capability. Users should verify hardware specifications and conduct preliminary testing to establish baseline functionality before proceeding with comprehensive research activities.

## Legal and Ethical Framework

This research framework operates within legitimate NFC analysis boundaries using standard Android APIs and established research methodologies. Users must ensure compliance with applicable regulations regarding NFC device research and access control system analysis. The framework should only be utilized with NFC cards owned by the researcher or with explicit authorization for analysis activities.

The system does not attempt to bypass Android security implementations or manufacturer protection mechanisms, ensuring compatibility with institutional research policies and legal compliance requirements.

## Troubleshooting and Support

### Common Resolution Procedures

NFC reading failures typically result from improper card positioning, insufficient contact duration, or hardware compatibility issues. Verify NFC antenna location through device documentation and ensure stable card contact throughout reading operations.

Emulation compatibility issues generally stem from Android Host Card Emulation limitations rather than framework deficiencies. Verify that target applications support standard HCE protocols and consider alternative emulation approaches for unsupported card types.

Framework communication problems between Termux and Android components usually indicate permission configuration issues or storage access restrictions. Verify that both applications have appropriate permissions and that shared storage directories are accessible.

### Configuration Optimization

Framework performance can be enhanced through device-specific configuration adjustments including NFC power management settings, storage access optimization, and background processing priority modification.
