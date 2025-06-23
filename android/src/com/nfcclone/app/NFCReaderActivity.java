package com.nfcclone.app;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.nfc.NfcAdapter;
import android.nfc.NfcManager;
import android.nfc.Tag;
import android.nfc.tech.IsoDep;
import android.nfc.tech.MifareClassic;
import android.nfc.tech.MifareUltralight;
import android.nfc.tech.Ndef;
import android.nfc.tech.NdefFormatable;
import android.nfc.tech.NfcA;
import android.nfc.tech.NfcB;
import android.nfc.tech.NfcF;
import android.nfc.tech.NfcV;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.util.Log;
import android.widget.TextView;
import android.widget.Toast;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.Arrays;

public class NFCReaderActivity extends Activity {
    private static final String TAG = "NFCReaderActivity";
    private NfcAdapter nfcAdapter;
    private PendingIntent pendingIntent;
    private IntentFilter[] intentFiltersArray;
    private String[][] techListsArray;
    private TextView statusText;
    
    private File cardsDir;
    private boolean nfcSetupComplete = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        try {
            setContentView(R.layout.activity_reader);
            
            statusText = findViewById(R.id.status_text);
            updateStatus("Initializing NFC reader...");
            
            initializeNFC();
            setupCardsDirectory();
            setupNFCReading();
            
            updateStatus("Ready to read NFC cards\nPlace card on device...");
            
        } catch (Exception e) {
            Log.e(TAG, "Error in onCreate", e);
            updateStatus("Initialization error: " + e.getMessage());
            handleFatalError(e);
        }
    }
    
    private void initializeNFC() throws Exception {
        try {
            NfcManager nfcManager = (NfcManager) getSystemService(Context.NFC_SERVICE);
            if (nfcManager == null) {
                throw new Exception("NFC Manager not available");
            }
            
            nfcAdapter = nfcManager.getDefaultAdapter();
            if (nfcAdapter == null) {
                throw new Exception("NFC not available on this device");
            }
            
            if (!nfcAdapter.isEnabled()) {
                throw new Exception("NFC is disabled. Please enable NFC in Settings.");
            }
            
            Log.d(TAG, "NFC initialized successfully");
            
        } catch (Exception e) {
            Log.e(TAG, "NFC initialization failed", e);
            throw new Exception("NFC initialization failed: " + e.getMessage());
        }
    }
    
    private void setupCardsDirectory() {
        File primaryDir = null;
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && Environment.isExternalStorageManager()) {
            File documentsDir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS), "NFCClone");
            primaryDir = new File(documentsDir, "cards");
            if (!primaryDir.exists()) {
                primaryDir.mkdirs();
            }
            Log.d(TAG, "Using Documents directory for storage: " + primaryDir.getAbsolutePath());
        }
        
        if (primaryDir == null || !primaryDir.exists() || !primaryDir.canWrite()) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                try {
                    File legacyDir = new File(Environment.getExternalStorageDirectory(), "NFCClone");
                    primaryDir = new File(legacyDir, "cards");
                    if (!primaryDir.exists()) {
                        primaryDir.mkdirs();
                    }
                    if (primaryDir.canWrite()) {
                        Log.d(TAG, "Using legacy external storage: " + primaryDir.getAbsolutePath());
                    } else {
                        primaryDir = null;
                    }
                } catch (Exception e) {
                    Log.w(TAG, "Cannot use legacy external storage", e);
                    primaryDir = null;
                }
            }
        }
        
        if (primaryDir == null || !primaryDir.exists() || !primaryDir.canWrite()) {
            File internalDir = new File(getFilesDir(), "cards");
            if (!internalDir.exists()) {
                internalDir.mkdirs();
            }
            primaryDir = internalDir;
            Log.d(TAG, "Using internal storage fallback: " + primaryDir.getAbsolutePath());
        }
        
        cardsDir = primaryDir;
        Log.d(TAG, "Cards will be saved to: " + cardsDir.getAbsolutePath());
        
        if (!cardsDir.exists()) {
            boolean created = cardsDir.mkdirs();
            Log.d(TAG, "Cards directory created: " + created);
        }
        
        if (!cardsDir.canWrite()) {
            Log.e(TAG, "Warning: Cards directory is not writable");
        }
    }
    
    private void setupNFCReading() {
        try {
            int flags = 0;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                flags = PendingIntent.FLAG_MUTABLE;
            } else {
                flags = 0;
            }
            
            pendingIntent = PendingIntent.getActivity(
                this, 0, 
                new Intent(this, getClass()).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), 
                flags);
            
            IntentFilter ndef = new IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED);
            IntentFilter tech = new IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED);
            IntentFilter tag = new IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED);
            
            try {
                ndef.addDataType("*/*");
            } catch (IntentFilter.MalformedMimeTypeException e) {
                Log.e(TAG, "Failed to add MIME type", e);
                throw new RuntimeException("Failed to add MIME type.", e);
            }
            
            intentFiltersArray = new IntentFilter[]{ndef, tech, tag};
            
            techListsArray = new String[][]{
                new String[]{NfcA.class.getName()},
                new String[]{NfcB.class.getName()},
                new String[]{NfcF.class.getName()},
                new String[]{NfcV.class.getName()},
                new String[]{IsoDep.class.getName()},
                new String[]{MifareClassic.class.getName()},
                new String[]{MifareUltralight.class.getName()},
                new String[]{Ndef.class.getName()},
                new String[]{NdefFormatable.class.getName()}
            };
            
            nfcSetupComplete = true;
            Log.d(TAG, "NFC reading setup complete");
            
        } catch (Exception e) {
            Log.e(TAG, "Error setting up NFC reading", e);
            updateStatus("NFC setup error: " + e.getMessage());
        }
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        
        try {
            if (nfcAdapter != null && nfcSetupComplete) {
                try {
                    nfcAdapter.enableForegroundDispatch(this, pendingIntent, intentFiltersArray, techListsArray);
                    Log.d(TAG, "NFC foreground dispatch enabled");
                } catch (Exception e) {
                    Log.e(TAG, "Error enabling foreground dispatch", e);
                    updateStatus("Error enabling NFC: " + e.getMessage());
                }
            } else {
                updateStatus("NFC not properly initialized");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in onResume", e);
        }
    }
    
    @Override
    protected void onPause() {
        super.onPause();
        
        try {
            if (nfcAdapter != null) {
                try {
                    nfcAdapter.disableForegroundDispatch(this);
                    Log.d(TAG, "NFC foreground dispatch disabled");
                } catch (Exception e) {
                    Log.e(TAG, "Error disabling foreground dispatch", e);
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in onPause", e);
        }
    }
    
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        
        try {
            Log.d(TAG, "New intent received: " + intent.getAction());
            handleNFCIntent(intent);
        } catch (Exception e) {
            Log.e(TAG, "Error handling new intent", e);
            updateStatus("Error processing NFC: " + e.getMessage());
        }
    }
    
    private void handleNFCIntent(Intent intent) {
        try {
            String action = intent.getAction();
            Log.d(TAG, "Handling NFC intent: " + action);
            
            if (NfcAdapter.ACTION_NDEF_DISCOVERED.equals(action) ||
                NfcAdapter.ACTION_TECH_DISCOVERED.equals(action) ||
                NfcAdapter.ACTION_TAG_DISCOVERED.equals(action)) {
                
                Tag tag = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
                if (tag != null) {
                    processTag(tag);
                } else {
                    Log.w(TAG, "No tag found in intent");
                    updateStatus("No NFC tag detected");
                }
            } else {
                Log.w(TAG, "Unhandled intent action: " + action);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error handling NFC intent", e);
            updateStatus("Error processing NFC intent: " + e.getMessage());
        }
    }
    
    private void processTag(Tag tag) {
        if (tag == null) {
            updateStatus("Invalid tag");
            return;
        }
        
        try {
            JSONObject cardData = new JSONObject();
            byte[] uid = tag.getId();
            String uidHex = bytesToHex(uid);
            
            Log.d(TAG, "Processing tag with UID: " + uidHex);
            updateStatus("Reading card: " + uidHex);
            
            cardData.put("UID", uidHex);
            cardData.put("Timestamp", System.currentTimeMillis() / 1000);
            cardData.put("Technologies", new JSONArray(Arrays.asList(tag.getTechList())));
            cardData.put("AndroidVersion", Build.VERSION.SDK_INT);
            cardData.put("DeviceModel", Build.MODEL);
            
            boolean hasData = false;
            
            try {
                if (readNdefData(tag, cardData)) hasData = true;
            } catch (Exception e) {
                Log.w(TAG, "Error reading NDEF data", e);
                cardData.put("NDEF_Error", e.getMessage());
            }
            
            try {
                if (readMifareData(tag, cardData)) hasData = true;
            } catch (Exception e) {
                Log.w(TAG, "Error reading MIFARE data", e);
                cardData.put("MIFARE_Error", e.getMessage());
            }
            
            try {
                if (readIsoDepData(tag, cardData)) hasData = true;
            } catch (Exception e) {
                Log.w(TAG, "Error reading ISO-DEP data", e);
                cardData.put("ISO_DEP_Error", e.getMessage());
            }
            
            try {
                if (readNfcAData(tag, cardData)) hasData = true;
            } catch (Exception e) {
                Log.w(TAG, "Error reading NFC-A data", e);
                cardData.put("NFC_A_Error", e.getMessage());
            }
            
            if (saveCardData(uidHex, cardData)) {
                updateStatus("Card saved: " + uidHex + "\nSaved to: " + cardsDir.getAbsolutePath() + "\nPlace another card or press back");
                Toast.makeText(this, "Card " + uidHex + " saved successfully", Toast.LENGTH_SHORT).show();
            } else {
                updateStatus("Failed to save card: " + uidHex + "\nCheck permissions and storage");
                Toast.makeText(this, "Failed to save card " + uidHex, Toast.LENGTH_LONG).show();
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error processing tag", e);
            updateStatus("Error reading card: " + e.getMessage());
            Toast.makeText(this, "Error reading card: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }
    
    private boolean readNdefData(Tag tag, JSONObject cardData) {
        try {
            Ndef ndef = Ndef.get(tag);
            if (ndef == null) return false;
            
            ndef.connect();
            
            JSONObject ndefData = new JSONObject();
            ndefData.put("Type", ndef.getType());
            ndefData.put("MaxSize", ndef.getMaxSize());
            ndefData.put("IsWritable", ndef.isWritable());
            
            if (ndef.getNdefMessage() != null) {
                ndefData.put("Message", bytesToHex(ndef.getNdefMessage().toByteArray()));
            }
            
            cardData.put("NDEF", ndefData);
            ndef.close();
            return true;
            
        } catch (Exception e) {
            Log.e(TAG, "Error reading NDEF data", e);
            return false;
        }
    }
    
    private boolean readMifareData(Tag tag, JSONObject cardData) {
        try {
            MifareClassic mifare = MifareClassic.get(tag);
            if (mifare == null) return false;
            
            mifare.connect();
            
            JSONObject mifareData = new JSONObject();
            mifareData.put("Type", mifare.getType());
            mifareData.put("SectorCount", mifare.getSectorCount());
            mifareData.put("BlockCount", mifare.getBlockCount());
            mifareData.put("Size", mifare.getSize());
            
            JSONObject sectorsData = new JSONObject();
            
            byte[][] defaultKeys = {
                MifareClassic.KEY_DEFAULT,
                MifareClassic.KEY_MIFARE_APPLICATION_DIRECTORY,
                {(byte)0xFF, (byte)0xFF, (byte)0xFF, (byte)0xFF, (byte)0xFF, (byte)0xFF},
                {(byte)0xA0, (byte)0xA1, (byte)0xA2, (byte)0xA3, (byte)0xA4, (byte)0xA5},
                {(byte)0xD3, (byte)0xF7, (byte)0xD3, (byte)0xF7, (byte)0xD3, (byte)0xF7}
            };
            
            for (int sector = 0; sector < mifare.getSectorCount(); sector++) {
                try {
                    boolean authenticated = false;
                    
                    for (byte[] key : defaultKeys) {
                        if (mifare.authenticateSectorWithKeyA(sector, key) || 
                            mifare.authenticateSectorWithKeyB(sector, key)) {
                            authenticated = true;
                            break;
                        }
                    }
                    
                    if (authenticated) {
                        JSONArray blocks = new JSONArray();
                        int startBlock = mifare.sectorToBlock(sector);
                        int blockCount = mifare.getBlockCountInSector(sector);
                        
                        for (int block = 0; block < blockCount; block++) {
                            try {
                                byte[] blockData = mifare.readBlock(startBlock + block);
                                blocks.put(bytesToHex(blockData));
                            } catch (Exception e) {
                                blocks.put("Read error: " + e.getMessage());
                            }
                        }
                        sectorsData.put("sector_" + sector, blocks);
                    } else {
                        sectorsData.put("sector_" + sector, "Authentication failed");
                    }
                } catch (Exception e) {
                    sectorsData.put("sector_" + sector, "Error: " + e.getMessage());
                }
            }
            
            mifareData.put("Sectors", sectorsData);
            cardData.put("MIFARE", mifareData);
            mifare.close();
            return true;
            
        } catch (Exception e) {
            Log.e(TAG, "Error reading MIFARE data", e);
            return false;
        }
    }
    
    private boolean readIsoDepData(Tag tag, JSONObject cardData) {
        try {
            IsoDep isoDep = IsoDep.get(tag);
            if (isoDep == null) return false;
            
            isoDep.connect();
            
            JSONObject isoData = new JSONObject();
            isoData.put("MaxTransceiveLength", isoDep.getMaxTransceiveLength());
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                isoData.put("IsExtendedLengthApduSupported", isoDep.isExtendedLengthApduSupported());
            }
            
            String[] commonAids = {
                "A000000172950001",
                "A0000001510000",
                "A000000025010801",
                "F001020304050607"
            };
            
            JSONObject aidResponses = new JSONObject();
            for (String aid : commonAids) {
                try {
                    byte[] selectCommand = buildSelectCommand(hexToBytes(aid));
                    byte[] response = isoDep.transceive(selectCommand);
                    aidResponses.put(aid, bytesToHex(response));
                } catch (Exception e) {
                    aidResponses.put(aid, "Error: " + e.getMessage());
                }
            }
            
            isoData.put("AID_Responses", aidResponses);
            cardData.put("ISO_DEP", isoData);
            isoDep.close();
            return true;
            
        } catch (Exception e) {
            Log.e(TAG, "Error reading ISO-DEP data", e);
            return false;
        }
    }
    
    private boolean readNfcAData(Tag tag, JSONObject cardData) {
        try {
            NfcA nfcA = NfcA.get(tag);
            if (nfcA == null) return false;
            
            nfcA.connect();
            
            JSONObject nfcAData = new JSONObject();
            nfcAData.put("ATQA", bytesToHex(nfcA.getAtqa()));
            nfcAData.put("SAK", nfcA.getSak());
            nfcAData.put("MaxTransceiveLength", nfcA.getMaxTransceiveLength());
            
            cardData.put("NFC_A", nfcAData);
            nfcA.close();
            return true;
            
        } catch (Exception e) {
            Log.e(TAG, "Error reading NFC-A data", e);
            return false;
        }
    }
    
    private byte[] buildSelectCommand(byte[] aid) {
        byte[] command = new byte[6 + aid.length];
        command[0] = (byte) 0x00;
        command[1] = (byte) 0xA4;
        command[2] = (byte) 0x04;
        command[3] = (byte) 0x00;
        command[4] = (byte) aid.length;
        System.arraycopy(aid, 0, command, 5, aid.length);
        command[5 + aid.length] = (byte) 0x00;
        return command;
    }
    
    private boolean saveCardData(String uid, JSONObject cardData) {
        File cardFile = new File(cardsDir, "card_" + uid + ".json");
        
        try {
            cardData.put("custom_response", "9000");
            cardData.put("label", "");
            cardData.put("saved_location", cardFile.getAbsolutePath());
            
            FileWriter writer = new FileWriter(cardFile);
            writer.write(cardData.toString(4));
            writer.close();
            
            Log.d(TAG, "Card saved: " + cardFile.getAbsolutePath());
            
            if (!cardFile.exists()) {
                Log.e(TAG, "File was not created successfully");
                return false;
            }
            
            if (cardFile.length() == 0) {
                Log.e(TAG, "File is empty after writing");
                return false;
            }
            
            Log.d(TAG, "Card file size: " + cardFile.length() + " bytes");
            return true;
            
        } catch (IOException | JSONException e) {
            Log.e(TAG, "Error saving card data", e);
            return false;
        }
    }
    
    private String bytesToHex(byte[] bytes) {
        if (bytes == null || bytes.length == 0) return "";
        
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }
    
    private byte[] hexToBytes(String hex) {
        if (hex == null || hex.length() == 0) return new byte[0];
        
        int len = hex.length();
        byte[] data = new byte[len / 2];
        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(hex.charAt(i), 16) << 4)
                                 + Character.digit(hex.charAt(i+1), 16));
        }
        return data;
    }
    
    private void updateStatus(String message) {
        if (statusText != null) {
            statusText.setText(message);
        }
        Log.d(TAG, "Status: " + message);
    }
    
    private void handleFatalError(Exception e) {
        Log.e(TAG, "Fatal error", e);
        Toast.makeText(this, "Fatal error: " + e.getMessage(), Toast.LENGTH_LONG).show();
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        
        try {
            if (nfcAdapter != null) {
                nfcAdapter.disableForegroundDispatch(this);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in onDestroy", e);
        }
    }
}
