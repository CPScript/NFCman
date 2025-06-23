#!/bin/bash

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                            NFCman                             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

URL="https://avatars.githubusercontent.com/u/83523587?s=48&v=4"
DEST="app/src/main/res/mipmap-mdpi/ic_launcher.jpeg"

if ! command -v magick >/dev/null 2>&1; then
    echo "[*] 'magick' command not found. Please install ImageMagick v7+"
    exit 1
fi
if ! command -v git >/dev/null 2>&1; then
    echo "[*] Git is not installed."
    echo "[*] Please install Git"
    exit 1
fi
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo "[*] Neither curl nor wget found. Please install one."
  exit 1
fi

echo "[*] Deleting default files..."
rm -rf NFCman
rm -rf app/src/main/res
rm -rf app/src/main/java/com/nfcclone/app
rm -f app/src/main/AndroidManifest.xml

echo "[*] Cloning repository"
git clone https://github.com/CPScript/NFCman

echo "[*] Copying files into project"
cp -r NFCman/android/res app/src/main/res
cp -r NFCman/android/res/xml/values app/src/main/res/values
cp -r NFCman/android/res/xml/layout app/src/main/res/layout
cp -r NFCman/android/src/com/nfcclone/app app/src/main/java/com/nfcclone
cp NFCman/android/AndroidManifest.xml app/src/main

SOURCE_FILE="app/src/main/java/com/nfcclone/app/NfcEmulatorService.java"
TARGET_FILE="app/src/main/java/com/nfcclone/app/EmulationControlReceiver.java"

inside_block=0
brace_level=0

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

echo "[*] Class successfully extracted to $TARGET_FILE"

find app/src/main/res -type f -name "*.xml" -exec sed -i '/^<!-- .* -->$/d' {} +
echo "[*] XML files cleaned"

mkdir -p app/src/main/res/mipmap-mdpi
if command -v curl >/dev/null 2>&1; then
  curl -L "$URL" -o "$DEST"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$DEST" "$URL"
else
  echo "[*] Neither curl nor wget found. Please install one."
  exit 1
fi

magick "$DEST" app/src/main/res/mipmap-mdpi/ic_launcher.png
rm "$DEST"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                      Installation Status                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo "[+] Android app source prepared"
