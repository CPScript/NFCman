package com.nfcclone.app;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.IntentFilter;
import android.nfc.NfcAdapter;
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
import android.os.Bundle;
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
    
    private static final String CARDS_DIR = "/storage/emulated/0/Android/data/com.nfcclone.app/files/cards";
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_reader);
        
        statusText = findViewById(R.id.status_text);
        statusText.setText("Ready to read NFC cards\nPlace card on device...");
        
        nfcAdapter = NfcAdapter.getDefaultAdapter(this);
        
        if (nfcAdapter == null || !nfcAdapter.isEnabled()) {
            Toast.makeText(this, "NFC not available or disabled", Toast.LENGTH_LONG).show();
            finish();
            return;
        }
        
        setupNFCReading();
        createCardsDirectory();
    }
    
    private void setupNFCReading() {
        pendingIntent = PendingIntent.getActivity(
            this, 0, new Intent(this, getClass()).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), 0);
        
        IntentFilter ndef = new IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED);
        IntentFilter tech = new IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED);
        IntentFilter tag = new IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED);
        
        try {
            ndef.addDataType("*/*");
        } catch (IntentFilter.MalformedMimeTypeException e) {
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
    }
    
    private void createCardsDirectory() {
        File cardsDir = new File(CARDS_DIR);
        if (!cardsDir.exists()) {
            cardsDir.mkdirs();
        }
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        nfcAdapter.enableForegroundDispatch(this, pendingIntent, intentFiltersArray, techListsArray);
    }
    
    @Override
    protected void onPause() {
        super.onPause();
        nfcAdapter.disableForegroundDispatch(this);
    }
    
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleNFCIntent(intent);
    }
    
    private void handleNFCIntent(Intent intent) {
        String action = intent.getAction();
        if (NfcAdapter.ACTION_NDEF_DISCOVERED.equals(action) ||
            NfcAdapter.ACTION_TECH_DISCOVERED.equals(action) ||
            NfcAdapter.ACTION_TAG_DISCOVERED.equals(action)) {
            
            Tag tag = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
            processTag(tag);
        }
    }
    
    private void processTag(Tag tag) {
        if (tag == null) return;
        
        try {
            JSONObject cardData = new JSONObject();
            byte[] uid = tag.getId();
            String uidHex = bytesToHex(uid);
            
            cardData.put("UID", uidHex);
            cardData.put("Timestamp", System.currentTimeMillis() / 1000);
            cardData.put("Technologies", new JSONArray(Arrays.asList(tag.getTechList())));
            
            statusText.setText("Reading card: " + uidHex);
            
            // Read NDEF data
            readNdefData(tag, cardData);
            
            // Read MIFARE data
            readMifareData(tag, cardData);
            
            // Read ISO-DEP data
            readIsoDepData(tag, cardData);
            
            // Read NFC-A data
            readNfcAData(tag, cardData);
            
            // Save card data
            saveCardData(uidHex, cardData);
            
            statusText.setText("Card saved: " + uidHex + "\nPlace another card or press back");
            Toast.makeText(this, "Card " + uidHex + " saved successfully", Toast.LENGTH_SHORT).show();
            
        } catch (Exception e) {
            Log.e(TAG, "Error processing tag", e);
            statusText.setText("Error reading card: " + e.getMessage());
        }
    }
    
    private void readNdefData(Tag tag, JSONObject cardData) {
        try {
            Ndef ndef = Ndef.get(tag);
            if (ndef != null) {
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
            }
        } catch (Exception e) {
            Log.e(TAG, "Error reading NDEF data", e);
        }
    }
    
    private void readMifareData(Tag tag, JSONObject cardData) {
        try {
            MifareClassic mifare = MifareClassic.get(tag);
            if (mifare != null) {
                mifare.connect();
                
                JSONObject mifareData = new JSONObject();
                mifareData.put("Type", mifare.getType());
                mifareData.put("SectorCount", mifare.getSectorCount());
                mifareData.put("BlockCount", mifare.getBlockCount());
                mifareData.put("Size", mifare.getSize());
                
                JSONObject sectorsData = new JSONObject();
                
                for (int sector = 0; sector < mifare.getSectorCount(); sector++) {
                    try {
                        // Try default keys
                        boolean authenticated = mifare.authenticateSectorWithKeyA(sector, MifareClassic.KEY_DEFAULT) ||
                                              mifare.authenticateSectorWithKeyB(sector, MifareClassic.KEY_DEFAULT) ||
                                              mifare.authenticateSectorWithKeyA(sector, MifareClassic.KEY_MIFARE_APPLICATION_DIRECTORY) ||
                                              mifare.authenticateSectorWithKeyB(sector, MifareClassic.KEY_MIFARE_APPLICATION_DIRECTORY);
                        
                        if (authenticated) {
                            JSONArray blocks = new JSONArray();
                            int startBlock = mifare.sectorToBlock(sector);
                            int blockCount = mifare.getBlockCountInSector(sector);
                            
                            for (int block = 0; block < blockCount; block++) {
                                byte[] blockData = mifare.readBlock(startBlock + block);
                                blocks.put(bytesToHex(blockData));
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
            }
        } catch (Exception e) {
            Log.e(TAG, "Error reading MIFARE data", e);
        }
    }
    
    private void readIsoDepData(Tag tag, JSONObject cardData) {
        try {
            IsoDep isoDep = IsoDep.get(tag);
            if (isoDep != null) {
                isoDep.connect();
                
                JSONObject isoData = new JSONObject();
                isoData.put("MaxTransceiveLength", isoDep.getMaxTransceiveLength());
                isoData.put("IsExtendedLengthApduSupported", isoDep.isExtendedLengthApduSupported());
                
                // Try to select common AIDs
                String[] commonAids = {
                    "A000000172950001", // EMV
                    "A0000001510000",   // VISA
                    "A000000025010801", // MasterCard
                    "F001020304050607"  // Custom test AID
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
            }
        } catch (Exception e) {
            Log.e(TAG, "Error reading ISO-DEP data", e);
        }
    }
    
    private void readNfcAData(Tag tag, JSONObject cardData) {
        try {
            NfcA nfcA = NfcA.get(tag);
            if (nfcA != null) {
                nfcA.connect();
                
                JSONObject nfcAData = new JSONObject();
                nfcAData.put("ATQA", bytesToHex(nfcA.getAtqa()));
                nfcAData.put("SAK", nfcA.getSak());
                nfcAData.put("MaxTransceiveLength", nfcA.getMaxTransceiveLength());
                
                cardData.put("NFC_A", nfcAData);
                nfcA.close();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error reading NFC-A data", e);
        }
    }
    
    private byte[] buildSelectCommand(byte[] aid) {
        byte[] command = new byte[6 + aid.length];
        command[0] = (byte) 0x00; // CLA
        command[1] = (byte) 0xA4; // INS
        command[2] = (byte) 0x04; // P1
        command[3] = (byte) 0x00; // P2
        command[4] = (byte) aid.length; // Lc
        System.arraycopy(aid, 0, command, 5, aid.length);
        command[5 + aid.length] = (byte) 0x00; // Le
        return command;
    }
    
    private void saveCardData(String uid, JSONObject cardData) throws IOException, JSONException {
        File cardFile = new File(CARDS_DIR, "card_" + uid + ".json");
        
        // Add default emulation response
        cardData.put("custom_response", "9000");
        cardData.put("label", "");
        
        FileWriter writer = new FileWriter(cardFile);
        writer.write(cardData.toString(4));
        writer.close();
        
        Log.d(TAG, "Card saved: " + cardFile.getAbsolutePath());
    }
    
    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }
    
    private byte[] hexToBytes(String hex) {
        int len = hex.length();
        byte[] data = new byte[len / 2];
        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(hex.charAt(i), 16) << 4)
                                 + Character.digit(hex.charAt(i+1), 16));
        }
        return data;
    }
}
