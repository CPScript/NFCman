@echo off
setlocal enabledelayedexpansion

echo ╔═══════════════════════════════════════════════════════════════╗
echo ║                   NFCman Windows Setup                        ║
echo ╚═══════════════════════════════════════════════════════════════╝

if not exist "app" (
    echo [!] This script should be run from an Android Studio project root
    echo [!] Expected 'app' directory not found
    echo.
    echo Instructions:
    echo 1. Create a new Android Studio project
    echo 2. Copy this script to the project root
    echo 3. Run the script from there
    pause
    exit /b 1
)

echo [*] Checking dependencies...

where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Git is not installed or not in PATH
    echo [!] Please install Git from https://git-scm.com/
    pause
    exit /b 1
)

where magick >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] ImageMagick is not installed or not in PATH
    echo [!] Please install ImageMagick from https://imagemagick.org/
    pause
    exit /b 1
)

set "CURL_AVAILABLE=0"
set "WGET_AVAILABLE=0"

where curl >nul 2>&1
if %errorlevel% equ 0 set "CURL_AVAILABLE=1"

where wget >nul 2>&1
if %errorlevel% equ 0 set "WGET_AVAILABLE=1"

if %CURL_AVAILABLE% equ 0 if %WGET_AVAILABLE% equ 0 (
    echo [!] Neither curl nor wget found
    echo [!] Please install curl or wget
    pause
    exit /b 1
)

echo [+] All dependencies found

echo [*] Cleaning existing files...
if exist "NFCman" rmdir /s /q "NFCman" >nul 2>&1
if exist "app\src\main\res" rmdir /s /q "app\src\main\res" >nul 2>&1
if exist "app\src\main\java\com\nfcclone" rmdir /s /q "app\src\main\java\com\nfcclone" >nul 2>&1
if exist "app\src\main\AndroidManifest.xml" del /q "app\src\main\AndroidManifest.xml" >nul 2>&1

echo [*] Cloning repository...
git clone https://github.com/CPScript/NFCman
if %errorlevel% neq 0 (
    echo [!] Failed to clone repository
    pause
    exit /b 1
)

echo [*] Creating directory structure...
if not exist "app\src\main\java\com\nfcclone" mkdir "app\src\main\java\com\nfcclone"
if not exist "app\src\main\res" mkdir "app\src\main\res"

echo [*] Copying files into project...

xcopy "NFCman\android\res\*" "app\src\main\res\" /s /e /y >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Failed to copy resources
    pause
    exit /b 1
)

xcopy "NFCman\android\src\com\nfcclone\app\*" "app\src\main\java\com\nfcclone\app\" /s /e /y >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Failed to copy Java files
    pause
    exit /b 1
)

copy "NFCman\android\AndroidManifest.xml" "app\src\main\AndroidManifest.xml" >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Failed to copy AndroidManifest.xml
    pause
    exit /b 1
)

echo [*] Extracting EmulationControlReceiver class...

set "SOURCE_FILE=app\src\main\java\com\nfcclone\app\NfcEmulatorService.java"
set "TARGET_FILE=app\src\main\java\com\nfcclone\app\EmulationControlReceiver.java"
set "TEMP_FILE=temp_emulator.java"

if exist "%SOURCE_FILE%" (
    set "EXTRACTING=0"
    set "BRACE_COUNT=0"
    
    for /f "usebackq delims=" %%a in ("%SOURCE_FILE%") do (
        set "LINE=%%a"
        
        echo !LINE! | findstr /c:"/* EmulationControlReceiver.java */" >nul 2>&1
        if !errorlevel! equ 0 (
            set "EXTRACTING=1"
        ) else if !EXTRACTING! equ 1 (
            set "TEMP_LINE=!LINE!"
            
            set "OPEN_COUNT=0"
            :count_open
            echo !TEMP_LINE! | findstr /c:"{" >nul 2>&1
            if !errorlevel! equ 0 (
                set /a "OPEN_COUNT+=1"
                set "TEMP_LINE=!TEMP_LINE:*{=!"
                goto count_open
            )
            
            set "TEMP_LINE=!LINE!"
            set "CLOSE_COUNT=0"
            :count_close
            echo !TEMP_LINE! | findstr /c:"}" >nul 2>&1
            if !errorlevel! equ 0 (
                set /a "CLOSE_COUNT+=1"
                set "TEMP_LINE=!TEMP_LINE:*}=!"
                goto count_close
            )
            
            set /a "BRACE_COUNT+=!OPEN_COUNT!"
            set /a "BRACE_COUNT-=!CLOSE_COUNT!"
            
            echo !LINE!>>"%TARGET_FILE%"
            
            if !BRACE_COUNT! equ 0 (
                echo !LINE! | findstr /c:"}" >nul 2>&1
                if !errorlevel! equ 0 goto extract_done
            )
        )
    )
    :extract_done
    
    set "EXTRACTING=0"
    set "BRACE_COUNT=0"
    
    for /f "usebackq delims=" %%a in ("%SOURCE_FILE%") do (
        set "LINE=%%a"
        
        echo !LINE! | findstr /c:"/* EmulationControlReceiver.java */" >nul 2>&1
        if !errorlevel! equ 0 (
            set "EXTRACTING=1"
        ) else if !EXTRACTING! equ 1 (
            set "TEMP_LINE=!LINE!"
            
            set "OPEN_COUNT=0"
            :count_open2
            echo !TEMP_LINE! | findstr /c:"{" >nul 2>&1
            if !errorlevel! equ 0 (
                set /a "OPEN_COUNT+=1"
                set "TEMP_LINE=!TEMP_LINE:*{=!"
                goto count_open2
            )
            
            set "TEMP_LINE=!LINE!"
            set "CLOSE_COUNT=0"
            :count_close2
            echo !TEMP_LINE! | findstr /c:"}" >nul 2>&1
            if !errorlevel! equ 0 (
                set /a "CLOSE_COUNT+=1"
                set "TEMP_LINE=!TEMP_LINE:*}=!"
                goto count_close2
            )
            
            set /a "BRACE_COUNT+=!OPEN_COUNT!"
            set /a "BRACE_COUNT-=!CLOSE_COUNT!"
            
            if !BRACE_COUNT! equ 0 (
                echo !LINE! | findstr /c:"}" >nul 2>&1
                if !errorlevel! equ 0 (
                    set "EXTRACTING=0"
                )
            )
        ) else (
            echo !LINE!>>"%TEMP_FILE%"
        )
    )
    
    move "%TEMP_FILE%" "%SOURCE_FILE%" >nul 2>&1
    echo [+] EmulationControlReceiver class extracted successfully
)

echo [*] Cleaning XML files...
for /r "app\src\main\res" %%f in (*.xml) do (
    if exist "%%f" (
        powershell -Command "(Get-Content '%%f') | Where-Object { $_ -notmatch '^<!-- .* --> } | Set-Content '%%f'" >nul 2>&1
    )
)

echo [*] Setting up app icon...
set "ICON_URL=https://avatars.githubusercontent.com/u/83523587?s=48&v=4"
set "TEMP_ICON=app\src\main\res\mipmap-mdpi\ic_launcher.jpeg"

if not exist "app\src\main\res\mipmap-mdpi" mkdir "app\src\main\res\mipmap-mdpi"

if %CURL_AVAILABLE% equ 1 (
    curl -L "%ICON_URL%" -o "%TEMP_ICON%" >nul 2>&1
) else if %WGET_AVAILABLE% equ 1 (
    wget -O "%TEMP_ICON%" "%ICON_URL%" >nul 2>&1
)

if exist "%TEMP_ICON%" (
    magick "%TEMP_ICON%" "app\src\main\res\mipmap-mdpi\ic_launcher.png" >nul 2>&1
    if %errorlevel% equ 0 (
        del "%TEMP_ICON%" >nul 2>&1
        echo [+] App icon created successfully
    ) else (
        echo [!] Failed to convert icon
    )
) else (
    echo [!] Failed to download icon
)

echo [*] Creating icons for different densities...
set "BASE_ICON=app\src\main\res\mipmap-mdpi\ic_launcher.png"

if exist "%BASE_ICON%" (
    if not exist "app\src\main\res\mipmap-hdpi" mkdir "app\src\main\res\mipmap-hdpi"
    if not exist "app\src\main\res\mipmap-xhdpi" mkdir "app\src\main\res\mipmap-xhdpi"
    if not exist "app\src\main\res\mipmap-xxhdpi" mkdir "app\src\main\res\mipmap-xxhdpi"
    if not exist "app\src\main\res\mipmap-xxxhdpi" mkdir "app\src\main\res\mipmap-xxxhdpi"
    
    magick "%BASE_ICON%" -resize 72x72 "app\src\main\res\mipmap-hdpi\ic_launcher.png" >nul 2>&1
    magick "%BASE_ICON%" -resize 96x96 "app\src\main\res\mipmap-xhdpi\ic_launcher.png" >nul 2>&1
    magick "%BASE_ICON%" -resize 144x144 "app\src\main\res\mipmap-xxhdpi\ic_launcher.png" >nul 2>&1
    magick "%BASE_ICON%" -resize 192x192 "app\src\main\res\mipmap-xxxhdpi\ic_launcher.png" >nul 2>&1
    
    echo [+] Multiple density icons created
)

echo [*] Copying Gradle configuration...
if exist "NFCman\android\build.gradle" (
    copy "NFCman\android\build.gradle" "app\build.gradle" >nul 2>&1
    if %errorlevel% equ 0 echo [+] App build.gradle copied
)

if exist "NFCman\android\proguard-rules.pro" (
    copy "NFCman\android\proguard-rules.pro" "app\proguard-rules.pro" >nul 2>&1
    if %errorlevel% equ 0 echo [+] ProGuard rules copied
)

if exist "NFCman\android\settings.gradle" (
    copy "NFCman\android\settings.gradle" "settings.gradle" >nul 2>&1
    if %errorlevel% equ 0 echo [+] Settings.gradle copied
)

if not exist "gradle" (
    echo [*] Creating Gradle wrapper directory...
    mkdir "gradle\wrapper"
    
    if exist "NFCman\android\gradle\wrapper\gradle-wrapper.properties" (
        copy "NFCman\android\gradle\wrapper\gradle-wrapper.properties" "gradle\wrapper\gradle-wrapper.properties" >nul 2>&1
    )
)

if not exist "local.properties" (
    echo [*] Creating local.properties template...
    echo # This file is automatically generated by Android Studio.>local.properties
    echo # Do not modify this file -- YOUR CHANGES WILL BE ERASED!>>local.properties
    echo #>>local.properties
    echo # This file should *NOT* be checked into Version Control Systems,>>local.properties
    echo # as it contains information specific to your local configuration.>>local.properties
    echo #>>local.properties
    echo # Location of the SDK. This is only used by Gradle.>>local.properties
    echo # For customization when using a Version Control System, please read the>>local.properties
    echo # header note.>>local.properties
    echo #sdk.dir=C\:\\Users\\%USERNAME%\\AppData\\Local\\Android\\Sdk>>local.properties
    echo.>>local.properties
    echo # Uncomment and set your Android SDK path above>>local.properties
)

echo [*] Cleaning up...
rmdir /s /q "NFCman" >nul 2>&1

echo.
echo ╔═══════════════════════════════════════════════════════════════╗
echo ║                    Windows Setup Complete                     ║
echo ╚═══════════════════════════════════════════════════════════════╝
echo [+] Android Studio project structure created
echo [+] Repository files copied to proper locations
echo [+] App icons configured for all densities
echo [+] Gradle configuration applied
echo [+] EmulationControlReceiver class extracted
echo.
echo Next steps:
echo 1. Set your Android SDK path in local.properties
echo 2. Open this project in Android Studio
echo 3. Sync the project (File → Sync Project with Gradle Files^)
echo 4. Build the project (Build → Make Project^)
echo 5. Generate APK (Build → Build Bundle(s^) / APK(s^) → Build APK(s^)^)
echo 6. Install APK on your Android device
echo.
echo For Termux setup, run install.sh on your Android device in Termux.
echo.
echo Setup completed successfully!
pause
