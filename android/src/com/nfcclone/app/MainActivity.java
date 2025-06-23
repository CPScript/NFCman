package com.nfcclone.app;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.nfc.NfcAdapter;
import android.nfc.NfcManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.Settings;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import java.io.File;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private static final String TAG = "MainActivity";
    private static final int PERMISSION_REQUEST_CODE = 1001;
    private static final int MANAGE_EXTERNAL_STORAGE_REQUEST_CODE = 1002;
    
    private TextView statusText;
    private Button readButton;
    private NfcAdapter nfcAdapter;
    private boolean permissionsGranted = false;
    private boolean nfcAvailable = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        try {
            setContentView(R.layout.activity_main);
            
            initializeViews();
            checkNfcAvailability();
            requestAllPermissions();
            
        } catch (Exception e) {
            Log.e(TAG, "Error in onCreate", e);
            showErrorDialog("Initialization Error", "Failed to initialize app: " + e.getMessage());
        }
    }
    
    private void initializeViews() {
        statusText = findViewById(R.id.status_text);
        readButton = findViewById(R.id.read_button);
        
        if (statusText != null) {
            statusText.setText("Initializing...");
        }
        
        if (readButton != null) {
            readButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    launchNFCReader();
                }
            });
            readButton.setEnabled(false);
        }
    }
    
    private void checkNfcAvailability() {
        try {
            NfcManager nfcManager = (NfcManager) getSystemService(Context.NFC_SERVICE);
            nfcAdapter = nfcManager.getDefaultAdapter();
            
            if (nfcAdapter == null) {
                nfcAvailable = false;
                updateStatus("NFC not available on this device");
                Log.w(TAG, "NFC not available");
                return;
            }
            
            if (!nfcAdapter.isEnabled()) {
                nfcAvailable = false;
                updateStatus("NFC is disabled. Please enable in Settings.");
                showNfcSettingsDialog();
                return;
            }
            
            nfcAvailable = true;
            updateStatus("NFC available and enabled");
            Log.d(TAG, "NFC available and enabled");
            
        } catch (Exception e) {
            Log.e(TAG, "Error checking NFC availability", e);
            nfcAvailable = false;
            updateStatus("Error checking NFC: " + e.getMessage());
        }
    }
    
    private void requestAllPermissions() {
        List<String> permissionsToRequest = new ArrayList<>();
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS);
                }
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED) {
                    permissionsToRequest.add(Manifest.permission.READ_MEDIA_IMAGES);
                }
            }
            
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.Q) {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                    permissionsToRequest.add(Manifest.permission.READ_EXTERNAL_STORAGE);
                }
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                    permissionsToRequest.add(Manifest.permission.WRITE_EXTERNAL_STORAGE);
                }
            }
            
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.NFC) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.NFC);
            }
            
            if (!permissionsToRequest.isEmpty()) {
                ActivityCompat.requestPermissions(this, 
                    permissionsToRequest.toArray(new String[0]), 
                    PERMISSION_REQUEST_CODE);
            } else {
                checkManageExternalStoragePermission();
            }
        } else {
            permissionsGranted = true;
            onPermissionsResult();
        }
    }
    
    private void checkManageExternalStoragePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                showManageStoragePermissionDialog();
                return;
            }
        }
        
        permissionsGranted = true;
        onPermissionsResult();
    }
    
    private void showManageStoragePermissionDialog() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            new AlertDialog.Builder(this)
                .setTitle("Storage Permission Required")
                .setMessage("This app needs 'All files access' permission to save NFC card data. Please grant permission in the next screen.")
                .setPositiveButton("Open Settings", (dialog, which) -> {
                    try {
                        Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
                        intent.setData(Uri.parse("package:" + getPackageName()));
                        startActivityForResult(intent, MANAGE_EXTERNAL_STORAGE_REQUEST_CODE);
                    } catch (Exception e) {
                        Log.e(TAG, "Error opening storage settings", e);
                        Intent intent = new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION);
                        startActivityForResult(intent, MANAGE_EXTERNAL_STORAGE_REQUEST_CODE);
                    }
                })
                .setNegativeButton("Continue without", (dialog, which) -> {
                    permissionsGranted = true;
                    onPermissionsResult();
                })
                .show();
        } else {
            permissionsGranted = true;
            onPermissionsResult();
        }
    }
    
    private void showNfcSettingsDialog() {
        new AlertDialog.Builder(this)
            .setTitle("NFC Required")
            .setMessage("NFC is required for this app to function. Please enable NFC in Settings.")
            .setPositiveButton("Open Settings", (dialog, which) -> {
                try {
                    Intent intent = new Intent(Settings.ACTION_NFC_SETTINGS);
                    startActivity(intent);
                } catch (Exception e) {
                    Intent intent = new Intent(Settings.ACTION_WIRELESS_SETTINGS);
                    startActivity(intent);
                }
            })
            .setNegativeButton("Cancel", null)
            .show();
    }
    
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            boolean allGranted = true;
            for (int result : grantResults) {
                if (result != PackageManager.PERMISSION_GRANTED) {
                    allGranted = false;
                    break;
                }
            }
            
            if (allGranted) {
                checkManageExternalStoragePermission();
            } else {
                permissionsGranted = true;
                onPermissionsResult();
                Toast.makeText(this, "Some permissions denied. App may not function correctly.", Toast.LENGTH_LONG).show();
            }
        }
    }
    
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        if (requestCode == MANAGE_EXTERNAL_STORAGE_REQUEST_CODE) {
            checkManageExternalStoragePermission();
        }
    }
    
    private void onPermissionsResult() {
        createAppDirectories();
        updateButtonState();
        updateStatus("Ready");
    }
    
    private void createAppDirectories() {
        try {
            File internalDir = new File(getFilesDir(), "cards");
            if (!internalDir.exists()) {
                boolean created = internalDir.mkdirs();
                Log.d(TAG, "Internal cards directory created: " + created);
            }
            
            File publicDocumentsDir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS), "NFCClone");
            if (!publicDocumentsDir.exists()) {
                boolean created = publicDocumentsDir.mkdirs();
                Log.d(TAG, "Public documents directory created: " + created);
            }
            
            File publicCardsDir = new File(publicDocumentsDir, "cards");
            if (!publicCardsDir.exists()) {
                boolean created = publicCardsDir.mkdirs();
                Log.d(TAG, "Public cards directory created: " + created);
            }
            
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                try {
                    File legacyDir = new File(Environment.getExternalStorageDirectory(), "NFCClone");
                    if (!legacyDir.exists()) {
                        legacyDir.mkdirs();
                    }
                    
                    File legacyCardsDir = new File(legacyDir, "cards");
                    if (!legacyCardsDir.exists()) {
                        legacyCardsDir.mkdirs();
                    }
                    Log.d(TAG, "Legacy directories created");
                } catch (Exception e) {
                    Log.w(TAG, "Could not create legacy directories", e);
                }
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error creating directories", e);
        }
    }
    
    private void updateButtonState() {
        if (readButton != null) {
            readButton.setEnabled(permissionsGranted && nfcAvailable);
        }
    }
    
    private void updateStatus(String message) {
        if (statusText != null) {
            statusText.setText(message);
        }
        Log.d(TAG, "Status: " + message);
    }
    
    private void launchNFCReader() {
        try {
            if (!nfcAvailable) {
                Toast.makeText(this, "NFC not available", Toast.LENGTH_SHORT).show();
                return;
            }
            
            if (!nfcAdapter.isEnabled()) {
                Toast.makeText(this, "Please enable NFC", Toast.LENGTH_SHORT).show();
                showNfcSettingsDialog();
                return;
            }
            
            Intent intent = new Intent(this, NFCReaderActivity.class);
            startActivity(intent);
            
        } catch (Exception e) {
            Log.e(TAG, "Error launching NFC reader", e);
            showErrorDialog("Launch Error", "Failed to launch NFC reader: " + e.getMessage());
        }
    }
    
    private void showErrorDialog(String title, String message) {
        try {
            new AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton("OK", null)
                .show();
        } catch (Exception e) {
            Log.e(TAG, "Error showing dialog", e);
        }
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        
        try {
            checkNfcAvailability();
            updateButtonState();
            
            if (nfcAvailable && permissionsGranted) {
                updateStatus("Ready to read NFC cards");
            } else if (!nfcAvailable) {
                updateStatus("NFC not available or disabled");
            } else if (!permissionsGranted) {
                updateStatus("Permissions required");
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error in onResume", e);
        }
    }
    
    @Override
    protected void onPause() {
        super.onPause();
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
    }
}
