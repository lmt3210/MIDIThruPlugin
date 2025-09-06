#!/bin/bash

DERIVED_DIR=/Users/Larry/Library/Developer/Xcode/DerivedData
BUILD_DIR=${DERIVED_DIR}/MIDIThru-*
PRODUCTS_DIR=${DERIVED_DIR}/MIDIThru-*/Build/Products/Development

rm -f make.log
touch make.log
rm -rf ${BUILD_DIR}

echo "Building MIDIThru" 2>&1 | tee -a make.log

xcodebuild -project MIDIThru.xcodeproj clean 2>&1 | tee -a make.log
xcodebuild -project MIDIThru.xcodeproj \
    -scheme "MIDIThru" build 2>&1 | tee -a make.log
cp -a ${PRODUCTS_DIR} ./MIDIThru.xcarchive

