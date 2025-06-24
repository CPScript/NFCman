#!/bin/bash

# By; https://github.xom/Lolig4

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                     Setup Android Studio                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

check_pc_dependencies() {
  if command -v inkscape >/dev/null 2>&1; then
    IMG_CMD="inkscape"
  elif command -v magick /dev/null 2>&1; then
    IMG_CMD="magick"
  else
    echo "[*] Neither Inkscape or ImageMagick v7+ found. Please install one."
    echo "[*] Please note that ImageMagick can’t produce a transparent background."
    exit 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "[*] Git is not installed."
    echo "[*] Please install Git"
    exit 1
  fi
  if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
  elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
  else
    echo "[*] Neither curl or wget found. Please install one."
    exit 1
  fi
}

setup_android_studio_project() {
  echo "[*] Setting up Android Studio project structure..."

  if [ ! -d "app" ]; then
      echo "[!] This script should be run from an Android Studio project root"
      echo "[!] Expected 'app' directory not found"
      echo ""
      echo "Instructions:"
      echo "1. Create a new Android Studio project"
      echo "2. Copy this script to the project root"
      echo "3. Run the script from there"
      exit 1
  fi

  URL="https://avatars.githubusercontent.com/u/83523587?s=48&v=4"
  DEST="ic_launcher.jpeg"
  readarray -t SVG_PATHS < <(find . -type f -iname '*.svg')
  count=${#SVG_PATHS[@]}
  if (( count == 0 )); then
    echo "[*] No SVG found!"
    echo "[*] Would you like to use CPscrip's profile picture as a fallback? (y/N)"
    read -r REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "[*] Download CPscrip's profile picture…"
      echo $DOWNLOADER
      if [[ $DOWNLOADER == "curl" ]]; then
        curl -L "$URL" -o "$DEST"
      elif [[ $DOWNLOADER == "wget" ]]; then
        wget -O "$DEST" "$URL"
      fi
      IMAGE=$DEST
    else
      echo "[*] Please drop a SVG into your Android Studio project."
      exit 1
    fi
  elif (( count == 1 )); then
    IMAGE="${SVG_PATHS[0]}"
    echo "[*] SVG found: $IMAGE"
  else
    echo "[*] More than one SVG found! Please ensure that only one SVG is in your Android Studio project."
    exit 1
  fi

  echo "[*] Deleting default files..."
  rm -rf app/src/main/res
  rm -rf app/src/main/java/com/nfcclone/app
  rm -f app/src/main/AndroidManifest.xml

  echo "[*] Cloning repository..."
  git clone https://github.com/CPScript/NFCman

  echo "[*] Copying files into project..."
  cp -r NFCman/android/res app/src/main/res
  cp -r NFCman/android/res/xml/values app/src/main/res/values
  cp -r NFCman/android/res/xml/layout app/src/main/res/layout
  cp -r NFCman/android/src/com/nfcclone/app app/src/main/java/com/nfcclone
  cp NFCman/android/AndroidManifest.xml app/src/main

  echo "[*] Extracting EmulationControlReceiver class..."
  SOURCE_FILE="app/src/main/java/com/nfcclone/app/NfcEmulatorService.java"
  TARGET_FILE="app/src/main/java/com/nfcclone/app/EmulationControlReceiver.java"

  if [ -f "$SOURCE_FILE" ]; then
      awk '
        /\/\* EmulationControlReceiver.java \*\// { inside=1; next }
        inside {
          brace_level += gsub(/\{/, "{")
          brace_level -= gsub(/\}/, "}")
          print
          if (brace_level == 0 && /}/) exit
        }
      ' "$SOURCE_FILE" > "$TARGET_FILE"
      
      awk '
        /\/\* EmulationControlReceiver.java \*\// { inside=1; next }
        inside {
          brace_level += gsub(/\{/, "{")
          brace_level -= gsub(/\}/, "}")
          if (brace_level == 0 && /}/) { inside=0; next }
          next
        }
        { print }
      ' "$SOURCE_FILE" > temp.java && mv temp.java "$SOURCE_FILE"
      
      echo "[*] EmulationControlReceiver class extracted successfully"
  fi

  echo "[*] Cleaning XML files..."
  find app/src/main/res -type f -name "*.xml" -exec sed -i '/^<!-- .* -->$/d' {} +

  echo "[*] Create ic_launcher.png..."
  declare -A SIZES=(
    [mdpi]=48
    [hdpi]=72
    [xhdpi]=96
    [xxhdpi]=144
    [xxxhdpi]=192
  )

  for DENSITY in "${!SIZES[@]}"; do
    SIZE=${SIZES[$DENSITY]}
    OUT_DIR="app/src/main/res/mipmap-$DENSITY"
    OUT_FILE="$OUT_DIR/ic_launcher.png"
    
    echo "[*] Generating ${DENSITY} (${SIZE}×${SIZE})…"
    mkdir -p "$OUT_DIR"
    
    if [[ $IMG_CMD == "inkscape" ]]; then
      inkscape "$IMAGE" \
        --export-background-opacity=0 \
        --export-filename="$OUT_FILE" \
        --export-width="$SIZE" \
        --export-height="$SIZE"
    elif [[ $IMG_CMD == "magick" ]]; then
      magick "$IMAGE" -resize "${SIZE}x${SIZE}" "$OUT_FILE"
    fi
  done

  echo "[*] Cleaning up..."
  rm -rf NFCman
  if [[ $IMAGE == "ic_launcher.jpeg" ]]; then
    rm $IMAGE
  fi
}

install_pc() {
    echo "[*] Setting up PC development environment..."
    
    check_pc_dependencies
    setup_android_studio_project
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    PC Setup Complete                          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo "[+] Android Studio project structure created"
    echo "[+] Repository files copied to proper locations"
    echo "[+] App icon configured"
    echo "[+] Gradle configuration applied"
    echo ""
    echo "Next steps:"
    echo "1. Open this project in Android Studio"
    echo "2. Sync the project (File → Sync Project with Gradle Files)"
    echo "3. Build the project (Build → Make Project)"
    echo "4. Generate APK (Build → Build Bundle(s) / APK(s) → Build APK(s))"
    echo "5. Install APK on your Android device"
    echo ""
}