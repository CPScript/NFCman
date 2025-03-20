#!/usr/bin/env python3
import nfc
import os
import json
import sys
import base64
import time
import binascii
from utils import load_config, get_card_path

def on_connect(tag):
    """Process tag when detected and save its data"""
    if tag is None:
        print("[!] No tag detected")
        return False
    
    try:
        # Extract UID
        uid = binascii.hexlify(tag.identifier).decode().upper()
        
        # Get tag type info
        tag_info = {
            "UID": uid,
            "Type": str(tag),
            "Technologies": [tech for tech in dir(tag) if not tech.startswith('_') and tech != 'identifier'],
            "Timestamp": int(time.time()),
        }
        
        # Extract NDEF data if available
        if hasattr(tag, 'ndef') and tag.ndef:
            ndef_records = []
            for record in tag.ndef.records:
                record_data = {
                    "type": binascii.hexlify(record.type).decode(),
                    "name": record.name,
                    "data": base64.b64encode(record.data).decode('ascii')
                }
                if hasattr(record, 'text'):
                    record_data["text"] = record.text
                ndef_records.append(record_data)
            tag_info["NDEF"] = ndef_records
        
        # For MIFARE Classic, try to read sectors
        if hasattr(tag, 'mifare'):
            sectors_data = {}
            for sector in range(16):  # Standard MIFARE Classic has 16 sectors
                try:
                    blocks = tag.mifare.read_blocks(sector * 4, 4)
                    sectors_data[f"sector_{sector}"] = binascii.hexlify(blocks).decode()
                except Exception as e:
                    sectors_data[f"sector_{sector}"] = f"Error: {str(e)}"
            tag_info["MIFARE_Data"] = sectors_data
        
        # Save the card data
        config = load_config()
        card_file = get_card_path(uid)
        os.makedirs(os.path.dirname(card_file), exist_ok=True)
        
        # Save raw dump for advanced analysis
        tag_info["RawData"] = {
            "Identifier": binascii.hexlify(tag.identifier).decode(),
        }
        
        # Add raw dumps of any available data
        if hasattr(tag, 'dump'):
            raw_dump = tag.dump()
            tag_info["RawData"]["Dump"] = raw_dump
        
        # Add custom response template
        tag_info["custom_response"] = "9000"  # Default success response
        
        with open(card_file, 'w') as f:
            json.dump(tag_info, f, indent=4)
        
        print(f"[+] Card saved: {uid}")
        print(f"[+] File: {card_file}")
        return True
    
    except Exception as e:
        print(f"[!] Error processing tag: {str(e)}")
        return False

def main():
    """Main function to read an NFC card"""
    try:
        config = load_config()
        reader = config.get('nfc_reader', 'usb')
        
        print("[*] Connecting to NFC reader...")
        with nfc.ContactlessFrontend(reader) as clf:
            print("[*] Place card on reader...")
            
            # Try to read for up to 30 seconds
            clf.connect(rdwr={'on-connect': on_connect, 'beep-on-connect': True})
            
    except KeyboardInterrupt:
        print("\n[*] Reading cancelled")
        return 1
    except Exception as e:
        print(f"[!] Error: {str(e)}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())