#!/bin/sh

set -e

xcodebuild build -project Satellite.xcodeproj -target All

./uninstall.sh

echo "Installing IOProxyFramebuffer.kext..."
sudo cp -R ioproxyvideofamily/IOProxyFramebuffer/build/Release/IOProxyFramebuffer.kext /System/Library/Extensions/

echo "Installing IOProxyVideoCard.kext..."
sudo cp -R ioproxyvideofamily/IOProxyVideoFamily/build/Release/IOProxyVideoCard.kext /System/Library/Extensions/

echo "Installing vncserver"
sudo install -m 0755 vncserver/build/Release/vncserver /usr/bin/

echo "Reboot and run 'vncserver'"
