package com.nfcclone.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.nfc.cardemulation.HostApduService;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Arrays;

public class NfcEmulatorService extends HostApduService {
    private static final String TAG = "NfcEmulatorService";
    private static final String NOTIFICATION_CHANNEL_ID = "nfc_emulation_channel";
    private static final int FOREGROUND_NOTIFICATION_ID = 1001;
    
    private static final byte[] SUCCESS_SW = {(byte) 0x90, (byte) 0x00};
    private static final byte[] FILE_NOT_FOUND_SW = {(byte) 0x6A, (byte) 0x82};
    private static final byte[] WRONG_LENGTH_SW = {(byte) 0x67, (byte) 0x00};
    private static final byte[] INSTRUCTION_NOT_SUPPORTED_SW = {(byte) 0x6D, (byte) 0x00};
    private static final byte[] CLASS_NOT_SUPPORTED_SW = {(byte) 0x6E, (byte) 0x00};
    
    private byte[] emulatedUid = null;
    private byte[] customResponse = null;
    private String currentCardUid = null;
    private JSONObject cardData = null;
    private boolean emulationActive = false;
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "NFC Emulator Service Created");
        
        createNotificationChannel();
        loadEmulationConfiguration();
    }
    
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "NFC Emulation",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("NFC card emulation status");
            channel.setShowBadge(false);
            
            NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "Service started with intent: " + intent);
        
        if (intent != null) {
            String action = intent.getStringExtra("action");
            String cardUid = intent.getStringExtra("card_uid");
            
            if ("start_emulation".equals(action) && cardUid != null) {
                startEmulation(cardUid);
            } else if ("stop_emulation".equals(action)) {
                stopEmulation();
            }
        }
        
        loadEmulationConfiguration();
        
        return START_STICKY;
    }
    
    private void loadEmulationConfiguration() {
        try {
            File[] possibleConfigFiles = {
                new File(getFilesDir().getParentFile(), "files/emulation_config.json"),
                new File("/storage/emulated/0/Android/data/" + getPackageName() + "/files/emulation_config.json"),
                new File(getFilesDir(), "emulation_config.json")
            };
            
            File configFile = null;
            for (File file : possibleConfigFiles) {
                if (file.exists()) {
                    configFile = file;
                    break;
                }
            }
            
            if (configFile == null || !configFile.exists()) {
                Log.d(TAG, "No emulation configuration found");
                stopEmulation();
                return;
            }
            
            FileInputStream fis = new FileInputStream(configFile);
            byte[] data = new byte[(int) configFile.length()];
            fis.read(data);
            fis.close();
            
            String jsonContent = new String(data, "UTF-8");
            JSONObject config = new JSONObject(jsonContent);
            
            boolean active = config.optBoolean("active", false);
            String cardUid = config.optString("card_uid", "");
            
            if (active && !cardUid.isEmpty()) {
                if (!cardUid.equals(currentCardUid)) {
                    startEmulation(cardUid);
                }
            } else {
                stopEmulation();
            }
            
        } catch (IOException | JSONException e) {
            Log.e(TAG, "Error loading emulation configuration: " + e.getMessage());
            stopEmulation();
        }
    }
    
    private void startEmulation(String cardUid) {
        try {
            File[] possibleCardFiles = {
                new File(getFilesDir(), "cards/card_" + cardUid + ".json"),
                new File("/storage/emulated/0/Android/data/" + getPackageName() + "/files/cards/card_" + cardUid + ".json")
            };
            
            File cardFile = null;
            for (File file : possibleCardFiles) {
                if (file.exists()) {
                    cardFile = file;
                    break;
                }
            }
            
            if (cardFile == null || !cardFile.exists()) {
                Log.e(TAG, "Card file not found for UID: " + cardUid);
                return;
            }
            
            FileInputStream fis = new FileInputStream(cardFile);
            byte[] data = new byte[(int) cardFile.length()];
            fis.read(data);
            fis.close();
            
            String jsonContent = new String(data, "UTF-8");
            cardData = new JSONObject(jsonContent);
            
            String uidString = cardData.getString("UID");
            emulatedUid = hexStringToByteArray(uidString);
            
            customResponse = null;
            if (cardData.has("custom_response")) {
                String responseHex = cardData.getString("custom_response");
                if (responseHex != null && !responseHex.isEmpty()) {
                    customResponse = hexStringToByteArray(responseHex);
                }
            }
            
            currentCardUid = cardUid;
            emulationActive = true;
            
            startForegroundService();
            
            Log.d(TAG, "Started emulating card: " + uidString);
            Log.d(TAG, "Custom response: " + (customResponse != null ? bytesToHex(customResponse) : "None"));
            
        } catch (IOException | JSONException e) {
            Log.e(TAG, "Error starting emulation: " + e.getMessage());
            stopEmulation();
        }
    }
    
    private void startForegroundService() {
        Intent notificationIntent = new Intent(this, MainActivity.class);
        
        int flags = 0;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = PendingIntent.FLAG_IMMUTABLE;
        }
        
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, flags);
        
        Notification notification = new NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("NFC Emulation Active")
            .setContentText("Emulating card: " + (currentCardUid != null ? currentCardUid : "Unknown"))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build();
        
        startForeground(FOREGROUND_NOTIFICATION_ID, notification);
    }
    
    private void stopEmulation() {
        emulatedUid = null;
        customResponse = null;
        currentCardUid = null;
        cardData = null;
        emulationActive = false;
        
        stopForeground(true);
        
        Log.d(TAG, "Emulation stopped");
    }
    
    @Override
    public byte[] processCommandApdu(byte[] commandApdu, Bundle extras) {
        Log.d(TAG, "Received APDU: " + bytesToHex(commandApdu));
        
        if (!emulationActive || emulatedUid == null) {
            Log.e(TAG, "No active emulation");
            return FILE_NOT_FOUND_SW;
        }
        
        if (commandApdu.length < 4) {
            Log.e(TAG, "APDU too short");
            return WRONG_LENGTH_SW;
        }
        
        byte cla = commandApdu[0];
        byte ins = commandApdu[1];
        byte p1 = commandApdu[2];
        byte p2 = commandApdu[3];
        
        Log.d(TAG, String.format("CLA: %02X, INS: %02X, P1: %02X, P2: %02X", cla, ins, p1, p2));
        
        try {
            if (cla == (byte) 0x00 && ins == (byte) 0xA4) {
                return handleSelectCommand(commandApdu);
            }
            
            if (cla == (byte) 0xFF && ins == (byte) 0xCA) {
                return handleGetUidCommand(p1, p2);
            }
            
            if (cla == (byte) 0x00 && ins == (byte) 0xB0) {
                return handleReadBinaryCommand(p1, p2, commandApdu);
            }
            
            byte[] specificResponse = handleCardSpecificCommands(commandApdu);
            if (specificResponse != null) {
                return specificResponse;
            }
            
            if (customResponse != null && customResponse.length > 0) {
                Log.d(TAG, "Using configured custom response");
                return customResponse;
            }
            
            Log.d(TAG, "Returning default success response");
            return SUCCESS_SW;
            
        } catch (Exception e) {
            Log.e(TAG, "Error processing APDU", e);
            return FILE_NOT_FOUND_SW;
        }
    }
    
    private byte[] handleSelectCommand(byte[] commandApdu) {
        Log.d(TAG, "Processing SELECT command");
        
        if (commandApdu.length < 5) {
            return WRONG_LENGTH_SW;
        }
        
        byte p1 = commandApdu[2];
        byte p2 = commandApdu[3];
        int lc = commandApdu[4] & 0xFF;
        
        if (commandApdu.length < 5 + lc) {
            return WRONG_LENGTH_SW;
        }
        
        byte[] aid = new byte[lc];
        System.arraycopy(commandApdu, 5, aid, 0, lc);
        
        Log.d(TAG, "SELECT AID: " + bytesToHex(aid));
        
        if (p1 == (byte) 0x04 && p2 == (byte) 0x00) {
            Log.d(TAG, "AID selection successful");
            return SUCCESS_SW;
        }
        
        return SUCCESS_SW;
    }
    
    private byte[] handleGetUidCommand(byte p1, byte p2) {
        Log.d(TAG, "Processing GET UID command");
        
        if (p1 == (byte) 0x00 && p2 == (byte) 0x00) {
            byte[] response = new byte[emulatedUid.length + 2];
            System.arraycopy(emulatedUid, 0, response, 0, emulatedUid.length);
            System.arraycopy(SUCCESS_SW, 0, response, emulatedUid.length, 2);
            
            Log.d(TAG, "Returning UID: " + bytesToHex(emulatedUid));
            return response;
        }
        
        return FILE_NOT_FOUND_SW;
    }
    
    private byte[] handleReadBinaryCommand(byte p1, byte p2, byte[] commandApdu) {
        Log.d(TAG, "Processing READ BINARY command");
        
        int offset = ((p1 & 0xFF) << 8) | (p2 & 0xFF);
        int length = 0;
        
        if (commandApdu.length == 5) {
            length = commandApdu[4] & 0xFF;
        } else if (commandApdu.length == 4) {
            length = 256;
        }
        
        Log.d(TAG, String.format("READ BINARY - Offset: %d, Length: %d", offset, length));
        
        if (offset == 0 && emulatedUid != null) {
            int responseLength = Math.min(length, emulatedUid.length);
            byte[] response = new byte[responseLength + 2];
            System.arraycopy(emulatedUid, 0, response, 0, responseLength);
            System.arraycopy(SUCCESS_SW, 0, response, responseLength, 2);
            return response;
        }
        
        return FILE_NOT_FOUND_SW;
    }
    
    private byte[] handleCardSpecificCommands(byte[] commandApdu) {
        if (cardData == null) {
            return null;
        }
        
        try {
            if (cardData.has("MIFARE")) {
                return handleMifareCommands(commandApdu);
            }
            
            if (cardData.has("ISO_DEP")) {
                return handleIsoDepCommands(commandApdu);
            }
            
            if (cardData.has("NDEF")) {
                return handleNdefCommands(commandApdu);
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error handling card-specific commands: " + e.getMessage());
        }
        
        return null;
    }
    
    private byte[] handleMifareCommands(byte[] commandApdu) {
        Log.d(TAG, "Processing MIFARE-specific command");
        
        if (commandApdu.length >= 2 && 
            (commandApdu[1] == (byte) 0x60 || commandApdu[1] == (byte) 0x61)) {
            Log.d(TAG, "MIFARE authentication command");
            return SUCCESS_SW;
        }
        
        return null;
    }
    
    private byte[] handleIsoDepCommands(byte[] commandApdu) {
        try {
            JSONObject isoData = cardData.getJSONObject("ISO_DEP");
            if (isoData.has("AID_Responses")) {
                JSONObject aidResponses = isoData.getJSONObject("AID_Responses");
                
                if (commandApdu.length >= 2 && 
                    commandApdu[0] == (byte) 0x00 && commandApdu[1] == (byte) 0xA4) {
                    
                    if (commandApdu.length >= 6) {
                        int lc = commandApdu[4] & 0xFF;
                        if (commandApdu.length >= 5 + lc) {
                            byte[] aid = new byte[lc];
                            System.arraycopy(commandApdu, 5, aid, 0, lc);
                            String aidHex = bytesToHex(aid);
                            
                            if (aidResponses.has(aidHex)) {
                                String responseHex = aidResponses.getString(aidHex);
                                if (!responseHex.startsWith("Error:")) {
                                    return hexStringToByteArray(responseHex);
                                }
                            }
                        }
                    }
                }
            }
        } catch (JSONException e) {
            Log.e(TAG, "Error processing ISO-DEP command: " + e.getMessage());
        }
        
        return null;
    }
    
    private byte[] handleNdefCommands(byte[] commandApdu) {
        Log.d(TAG, "Processing NDEF command");
        
        try {
            JSONObject ndefData = cardData.getJSONObject("NDEF");
            
            if (commandApdu.length >= 2 && 
                commandApdu[0] == (byte) 0x00 && commandApdu[1] == (byte) 0xA4) {
                Log.d(TAG, "NDEF file selection");
                return SUCCESS_SW;
            }
            
        } catch (JSONException e) {
            Log.e(TAG, "Error processing NDEF command: " + e.getMessage());
        }
        
        return null;
    }
    
    @Override
    public void onDeactivated(int reason) {
        String reasonStr;
        switch (reason) {
            case DEACTIVATION_LINK_LOSS:
                reasonStr = "LINK_LOSS";
                break;
            case DEACTIVATION_DESELECTED:
                reasonStr = "DESELECTED";
                break;
            default:
                reasonStr = String.valueOf(reason);
                break;
        }
        
        Log.d(TAG, "NFC connection deactivated: " + reasonStr);
        
        loadEmulationConfiguration();
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        stopEmulation();
        Log.d(TAG, "Service destroyed");
    }
    
    private static byte[] hexStringToByteArray(String s) {
        if (s == null || s.length() == 0) {
            return new byte[0];
        }
        
        s = s.replaceAll("[^0-9A-Fa-f]", "");
        
        int len = s.length();
        if (len % 2 != 0) {
            s = "0" + s;
            len++;
        }
        
        byte[] data = new byte[len / 2];
        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                                 + Character.digit(s.charAt(i+1), 16));
        }
        return data;
    }
    
    private static String bytesToHex(byte[] bytes) {
        if (bytes == null || bytes.length == 0) {
            return "";
        }
        
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }
}

/* EmulationControlReceiver.java */
package com.nfcclone.app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class EmulationControlReceiver extends BroadcastReceiver {
    private static final String TAG = "EmulationControlReceiver";
    
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        Log.d(TAG, "Received broadcast: " + action);
        
        if ("com.nfcclone.app.STOP_EMULATION".equals(action)) {
            try {
                Intent serviceIntent = new Intent(context, NfcEmulatorService.class);
                serviceIntent.putExtra("action", "stop_emulation");
                context.startService(serviceIntent);
                
                Log.d(TAG, "Emulation stop signal sent");
            } catch (Exception e) {
                Log.e(TAG, "Error stopping emulation", e);
            }
        }
    }
}
