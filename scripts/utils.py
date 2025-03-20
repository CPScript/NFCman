#!/usr/bin/env python3
import json
import os
import sys
import binascii

def load_config():
    """Load configuration from config.json"""
    try:
        with open('config.json', 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"[!] Error loading config: {str(e)}")
        return {"card_data_dir": "./cards", "nfc_reader": "usb"}

def get_card_path(uid):
    """Get the path for a card file based on its UID"""
    config = load_config()
    card_data_dir = config.get('card_data_dir', './cards')
    return os.path.join(card_data_dir, f"card_{uid}.json")

def list_saved_cards():
    """List all saved cards"""
    config = load_config()
    card_data_dir = config.get('card_data_dir', './cards')
    
    if not os.path.exists(card_data_dir):
        print(f"[!] Card directory not found: {card_data_dir}")
        return []
    
    card_files = [f for f in os.listdir(card_data_dir) if f.startswith('card_') and f.endswith('.json')]
    
    cards = []
    for card_file in card_files:
        try:
            with open(os.path.join(card_data_dir, card_file), 'r') as f:
                card_data = json.load(f)
                uid = card_data.get('UID', 'Unknown')
                card_type = card_data.get('Type', 'Unknown')
                timestamp = card_data.get('Timestamp', 0)
                
                cards.append({
                    'uid': uid,
                    'type': card_type,
                    'timestamp': timestamp,
                    'file': card_file
                })
        except Exception as e:
            print(f"[!] Error reading card file {card_file}: {str(e)}")
    
    return cards

def parse_hex_string(hex_string):
    """Convert a hex string to byte array"""
    try:
        return binascii.unhexlify(hex_string)
    except binascii.Error as e:
        print(f"[!] Invalid hex string: {str(e)}")
        return None

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
        
        if 'Technologies' in card_data:
            print("\nSupported Technologies:")
            for tech in card_data['Technologies']:
                print(f"- {tech}")
        
        if 'NDEF' in card_data:
            print("\nNDEF Records:")
            for i, record in enumerate(card_data['NDEF']):
                print(f"\nRecord {i+1}:")
                print(f"  Type: {record.get('type', 'Unknown')}")
                if 'text' in record:
                    print(f"  Text: {record['text']}")
        
        if 'MIFARE_Data' in card_data:
            print("\nMIFARE Sectors:")
            for sector, data in card_data['MIFARE_Data'].items():
                if not data.startswith('Error'):
                    print(f"  {sector}: {data[:20]}...")
                else:
                    print(f"  {sector}: {data}")
        
        return True
    
    except Exception as e:
        print(f"[!] Error analyzing card: {str(e)}")
        return False