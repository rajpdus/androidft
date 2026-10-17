#!/bin/zsh
# Build a release binary and wrap it in AndroidFT.app with the Homebrew
# libmtp/libusb dylibs copied into the bundle so it runs without Homebrew.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH=/opt/homebrew/bin:$PATH
swift build -c release 2>&1 | tail -3
BIN=.build/release/AndroidFT
APP=build/AndroidFT.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AndroidFT"
cp scripts/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
MTP=$(readlink -f /opt/homebrew/opt/libmtp/lib/libmtp.9.dylib)
USB=$(readlink -f /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib)
cp "$MTP" "$APP/Contents/Frameworks/libmtp.9.dylib"
cp "$USB" "$APP/Contents/Frameworks/libusb-1.0.0.dylib"
chmod u+w "$APP/Contents/Frameworks/"*.dylib
install_name_tool -id @rpath/libmtp.9.dylib "$APP/Contents/Frameworks/libmtp.9.dylib"
install_name_tool -id @rpath/libusb-1.0.0.dylib "$APP/Contents/Frameworks/libusb-1.0.0.dylib"
install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @rpath/libusb-1.0.0.dylib "$APP/Contents/Frameworks/libmtp.9.dylib"
install_name_tool -change /opt/homebrew/opt/libmtp/lib/libmtp.9.dylib @rpath/libmtp.9.dylib "$APP/Contents/MacOS/AndroidFT"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/AndroidFT"
install_name_tool -add_rpath @loader_path "$APP/Contents/Frameworks/libmtp.9.dylib"
codesign --force --deep --sign - "$APP"
echo "Built $APP"
otool -L "$APP/Contents/MacOS/AndroidFT" | grep -E "mtp|usb"
