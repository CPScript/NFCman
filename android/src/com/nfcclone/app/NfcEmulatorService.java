package com.nfcclone.app;

import android.content.SharedPreferences;
import android.nfc.cardemulation.HostApduService;
import android.os.Bundle;
import android.util.Log;
import java.util.Arrays;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import org.json.JSONException;
import org.json.JSONObject;

public class NfcEmulatorService extends HostApduService {
    private static final String TAG = "NfcEmulatorService";
    
    // Standard SELECT command for NFC-A and ISO 14443-4 cards
    private static final byte[] SELECT_AID_COMMAND = {
        (byte) 0x00, // CLA
        (byte) 0xA4, // INS
        (byte) 0x04, // P1
        (byte) 0x00, // P2
        (byte) 0x07, // Lc (length of AID)
        // AID - can be customized
        (byte) 0xF0, (byte) 0x01, (byte) 0x02, (byte) 0x03, (byte) 0x04, (byte) 0x05, (byte) 0x06,
        (byte) 0x00  // Le
    };
    
    // Response codes
    private static final byte[] SUCCESS_SW = {(byte) 0x90, (byte) 0x00};
    private static final byte[] FAILURE_SW = {(byte) 0x6A, (byte) 0x82};
    
    private byte[] emulatedUid = null;
    private byte[] customResponse = null;
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "NFC Emulator Service Created");
        loadCardData();
    }
    
    private void loadCardData() {
        SharedPreferences prefs = getSharedPreferences("NfcClonePrefs", MODE_PRIVATE);
        String cardPath = prefs.getString("current_card_path", "");
        
        if (cardPath.isEmpty()) {
            Log.e(TAG, "No card selected for emulation");
            return;
        }
        
        try {
            File cardFile = new File(cardPath);
            if (!cardFile.exists()) {
                Log.e(TAG, "Card file does not exist: " + cardPath);
                return;
            }
            
            FileInputStream fis = new FileInputStream(cardFile);
            byte[] data = new byte[(int) cardFile.length()];
            fis.read(data);
            fis.close();
            
            String jsonContent = new String(data, "UTF-8");
            JSONObject cardData = new JSONObject(jsonContent);
            
            String uidString = cardData.getString("UID");
            emulatedUid = hexStringToByteArray(uidString);
            
            // Check if the card has a custom response
            if (cardData.has("custom_response")) {
                String responseHex = cardData.getString("custom_response");
                customResponse = hexStringToByteArray(responseHex);
            }
            
            Log.d(TAG, "Loaded card UID: " + uidString);
        } catch (IOException | JSONException e) {
            Log.e(TAG, "Error loading card data: " + e.getMessage());
        }
    }
    
    @Override
    public byte[] processCommandApdu(byte[] commandApdu, Bundle extras) {
        Log.d(TAG, "Received APDU: " + bytesToHex(commandApdu));
        
        // If no card is loaded, return failure
        if (emulatedUid == null) {
            Log.e(TAG, "No card data loaded for emulation");
            return FAILURE_SW;
        }
        
        // Process SELECT command (ISO 7816-4)
        if (Arrays.equals(SELECT_AID_COMMAND, commandApdu) || 
            (commandApdu.length >= 5 && commandApdu[0] == (byte)0x00 && commandApdu[1] == (byte)0xA4)) {
            Log.d(TAG, "Received SELECT command, responding with success");
            return SUCCESS_SW;
        }
        
        // Process GET UID command (usually proprietary, this is a simplified example)
        if (commandApdu.length >= 2 && commandApdu[0] == (byte)0xFF && commandApdu[1] == (byte)0xCA) {
            Log.d(TAG, "Received GET UID command, responding with UID");
            byte[] response = new byte[emulatedUid.length + 2];
            System.arraycopy(emulatedUid, 0, response, 0, emulatedUid.length);
            System.arraycopy(SUCCESS_SW, 0, response, emulatedUid.length, 2);
            return response;
        }
        
        // If we have a custom response for this specific command, use it
        if (customResponse != null) {
            Log.d(TAG, "Using custom response");
            return customResponse;
        }
        
        // Default response
        return SUCCESS_SW;
    }
    
    @Override
    public void onDeactivated(int reason) {
        Log.d(TAG, "NFC connection deactivated, reason: " + reason);
    }
    
    private static byte[] hexStringToByteArray(String s) {
        int len = s.length();
        byte[] data = new byte[len / 2];
        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                                 + Character.digit(s.charAt(i+1), 16));
        }
        return data;
    }
    
    private static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }
}
