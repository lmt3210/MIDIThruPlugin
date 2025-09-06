#!/bin/bash

VERSION=$(cat MIDIThru.xcodeproj/project.pbxproj | \
          grep -m1 'MARKETING_VERSION' | cut -d'=' -f2 | \
          tr -d ';' | tr -d ' ')
ARCHIVE_DIR=/Users/Larry/Library/Developer/Xcode/Archives/CommandLine

rm -rf ${ARCHIVE_DIR}/MIDIThru-v${VERSION}.xcarchive
cp -a MIDIThru.xcarchive ${ARCHIVE_DIR}/MIDIThru-v${VERSION}.xcarchive
cd MIDIThru.xcarchive && \
    zip -rq ../MIDIThru-v${VERSION}.zip MIDIThru.component
cd ..

echo "** ARCHIVE SUCCEEDED **"

