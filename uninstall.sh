#!/bin/sh

set -e

sudo rm -rf /System/Library/Extensions/IOProxyFramebuffer.kext
sudo rm -rf /System/Library/Extensions/IOProxyVideoCard.kext
sudo rm -rf /usr/bin/vncserver

