#!/bin/bash

INSTALL_DIR=/Users/Larry/Library/Audio/Plug-Ins/Components

rm -rf ${INSTALL_DIR}/MIDIThru.component
cp -a MIDIThru.xcarchive/MIDIThru.component ${INSTALL_DIR}

echo "** INSTALL SUCCEEDED **"

