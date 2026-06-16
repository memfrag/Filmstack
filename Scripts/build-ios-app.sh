#!/bin/sh

set -Eeuo pipefail

## Change directory to parent directory of the directory that the script is in.
cd "$(dirname ${BASH_SOURCE[0]})/.."

##############################################################################
## Terminal Codes
##############################################################################

CSI="\x1b["

create_colors() {
    NORMAL=${CSI}m ; BOLD=${CSI}1m ; FAINT=${CSI}2m ; ITALIC=${CSI}3m
    UNDERLINE=${CSI}4m ; BLINK=${CSI}5m ; INVERT=${CSI}7m
    BLACK=${CSI}30m ; RED=${CSI}31m ; GREEN=${CSI}32m ; YELLOW=${CSI}33m
    BLUE=${CSI}34m; PINK=${CSI}35m ; TEAL=${CSI}36m ; WHITE=${CSI}37m
    BLACKBG=${CSI}40m ; REDBG=${CSI}41m ; GREENBG=${CSI}42m ; YELLOWBG=${CSI}43m
    BLUEBG=${CSI}44m ; PINKBG=${CSI}45m ; TEALBG=${CSI}46m ; WHITEBG=${CSI}47m
    BRIGHTBLACK=${CSI}90m ; BRIGHTRED=${CSI}91m ; BRIGHTGREEN=${CSI}92m
    BRIGHTYELLOW=${CSI}93m ; BRIGHTBLUE=${CSI}94m ; BRIGHTPINK=${CSI}95m
    BRIGHTTEAL=${CSI}96m ; BRIGHTWHITE=${CSI}97m
    BRIGHTBLACKBG=${CSI}100m ; BRIGHTREDBG=${CSI}101m ; BRIGHTGREENBG=${CSI}102m
    BRIGHTYELLOWBG=${CSI}103m ; BRIGHTBLUEBG=${CSI}104m ; BRIGHTPINKBG=${CSI}105m
    BRIGHTTEALBG=${CSI}106m ; BRIGHTWHITEBG=${CSI}107m
}

destroy_colors() {
    NORMAL=${CSI}m ; BOLD= ; FAINT= ; ITALIC= ; UNDERLINE= ; BLINK= ; INVERT=
    BLACK= ; RED= ; GREEN= ; YELLOW= ; BLUE= ; PINK= ; TEAL= ; WHITE=
    BLACKBG= ; REDBG= ; GREENBG= ; YELLOWBG= ; BLUEBG= ; PINKBG= ; TEALBG=
    WHITEBG= ; BRIGHTBLACK= ; BRIGHTRED= ; BRIGHTGREEN= ; BRIGHTYELLOW=
    BRIGHTBLUE= ; BRIGHTPINK= ; BRIGHTTEAL= ; BRIGHTWHITE= ; BRIGHTBLACKBG=
    BRIGHTREDBG= ; BRIGHTGREENBG= ; BRIGHTYELLOWBG= ; BRIGHTBLUEBG=
    BRIGHTPINKBG= ; BRIGHTTEALBG= ; BRIGHTWHITEBG=    
}

## For preview of colors during development.
display_colors() {
    NML="${NORMAL}\n"
    echo "${BOLD}bold${NML}${FAINT}faint${NML}${ITALIC}italic${NORMAL}"
    echo "${UNDERLINE}underline${NML}${BLINK}blink${NML}${INVERT}invert${NORMAL}"    
    echo "${BLACK}black${NML}${RED}red${NML}${GREEN}green${NML}${YELLOW}yellow${NORMAL}"
    echo "${BLUE}blue${NML}${PINK}pink${NML}${TEAL}teal${NML}${WHITE}white${NORMAL}"
    echo "${BLACKBG}black${NML}${REDBG}red${NML}${GREENBG}green${NML}${YELLOWBG}yellow${NORMAL}"
    echo "${BLUEBG}blue${NML}${PINKBG}pink${NML}${TEALBG}teal${NML}${WHITEBG}white${NORMAL}"
    echo "${BRIGHTBLACK}bright black${NML}${BRIGHTRED}bright red${NORMAL}"
    echo "${BRIGHTGREEN}bright green${NML}${BRIGHTYELLOW}bright yellow${NORMAL}"
    echo "${BRIGHTBLUE}bright blue${NML}${BRIGHTPINK}bright pink${NORMAL}"
    echo "${BRIGHTTEAL}bright teal${NML}${BRIGHTWHITE}bright white${NORMAL}"
    echo "${BRIGHTBLACKBG}bright black${NML}${BRIGHTREDBG}bright red${NORMAL}"
    echo "${BRIGHTGREENBG}bright green${NML}${BRIGHTYELLOWBG}bright yellow${NORMAL}"
    echo "${BRIGHTBLUEBG}bright blue${NML}${BRIGHTPINKBG}bright pink${NORMAL}"
    echo "${BRIGHTTEALBG}bright teal${NML}${BRIGHTWHITEBG}bright white${NORMAL}"
}

##############################################################################
## Usage
##############################################################################

display_usage() {
    cat <<EOF
Usage: $0 [--build-only] <flavor>

Options:
  -p, --plain           Plain text only, no fancy terminal colors.
  -b, --build-only      Build app, but don't upload to TestFlight.
  
Inputs:
  <flavor>              Build flavor to use. One of:
                          - release 
  
EOF
}

##############################################################################
## Parse arguments
##############################################################################

BUILD_ONLY=
FLAVOR=

create_colors

while (( "$#" )); do
    case $1 in
        -h | --help)
            display_usage
            exit
            ;;
        -p | --plain)
            shift
            destroy_colors
            ;;
        -b | --build-only) # Build but don't upload to TestFlight
            shift
            BUILD_ONLY=1
            ;;
        release)
            FLAVOR=$1
            shift
            ;;
        *)
            display_usage
            exit
            ;;
    esac
done

##############################################################################
## Verify flavor and set up flavor dependent variables
##############################################################################

APP_NAME=Filmstack
SANITIZED_APP_NAME=Filmstack
CONFIG=
SCHEME=
BUNDLE_ID=
PROVISIONING_PROFILE=
PUSH_EXTENSION_BUNDLE_ID=
PUSH_EXTENSION_PROVISIONING_PROFILE=
FLAVORFG=
FLAVORBG=

case $FLAVOR in
    release)
        CONFIG=Release
        SCHEME="${APP_NAME} (Release)"
        BUNDLE_ID="io.apparata.${SANITIZED_APP_NAME}"
        FLAVORFG=$BRIGHTWHITE
        FLAVORBG=$BRIGHTGREENBG
        ;;
    *)
        display_usage
        exit
        ;;
esac

##############################################################################
## Intro text
##############################################################################

if [ "$BUILD_ONLY" = "1" ]; then
    echo "${BLUE}Starting${NORMAL} ${BOLD}${FLAVORFG}${FLAVORBG} $FLAVOR ${NORMAL}${BLUE} build${NORMAL} ${RED}${BLINK}** Build only, no TestFlight upload **${NORMAL}"
else
    echo "${BLUE}Starting ${BOLD}${FLAVORFG}${FLAVORBG} $FLAVOR ${NORMAL}${BLUE} build${NORMAL} ${BLUE}for upload to TestFlight${NORMAL}"
fi

##############################################################################
## Set up directories and paths
##############################################################################

ARCHIVE_FOLDER="${HOME}/Library/Developer/Xcode/Archives/${SANITIZED_APP_NAME}"
ARCHIVE_TIMESTAMP=`date -u +"%FT%H%MZ"`
ARCHIVE_PATH="${ARCHIVE_FOLDER}/${SANITIZED_APP_NAME}-${ARCHIVE_TIMESTAMP}.xcarchive"
mkdir -p "$ARCHIVE_FOLDER"

OUTPUT_FOLDER=/tmp/appbuild
EXPORT_OPTIONS_PATH="${OUTPUT_FOLDER}/exportOptions.plist"
if [ -f "$OUTPUT_FOLDER" ]; then
    rm -rf "$OUTPUT_FOLDER"
fi
mkdir -p "$OUTPUT_FOLDER"

LOGS_PATH=/tmp/appbuildlogs
if [ ! -f "$LOGS_PATH" ]; then
    mkdir -p "$LOGS_PATH"
fi

##############################################################################
## Build app archive
##############################################################################

echo "${BLUE}Building archive...${NORMAL}"

xcrun xcodebuild clean archive \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -sdk iphoneos \
    -configuration "$CONFIG" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -disableAutomaticPackageResolution

##############################################################################
## End execution of script here if build only.
##############################################################################    

if [ "$BUILD_ONLY" = "1" ]; then
    echo "${BLUE}Skipping export upload to TestFlight.${NORMAL}"
    echo "${GREEN}Done building flavor ${BOLD}${FLAVORFG}${FLAVORBG} $FLAVOR ${NORMAL}${GREEN} version ${NORMAL}\n${PINK}Archived at ${ARCHIVE_PATH}${NORMAL}"
    exit
fi

##############################################################################
## Generate export options for TestFlight upload
##############################################################################
    
echo "${BLUE}Generate export options plist...${NORMAL}"
    
cat >"$EXPORT_OPTIONS_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

##############################################################################
## Export and upload build to TestFlight
##############################################################################

echo "${BLUE}Uploading to TestFlight...${NORMAL}"

EXPORT_LOG="$LOGS_PATH/XcodeExportOutput-${ARCHIVE_TIMESTAMP}.log"

# Upload to TestFlight and pipe stdout & stderr to log file. We will parse
# this file to find the ContentDelivery.log where build number is.
xcrun xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
    -exportPath "$OUTPUT_FOLDER" \
    -allowProvisioningUpdates \
    2>&1 | tee "${EXPORT_LOG}"

##############################################################################
## Cleanup
##############################################################################

echo "${BLUE}Removing the archive, because we (hopefully) don't need it anymore...${NORMAL}"

rm -rf "$ARCHIVE_PATH"

##############################################################################
## Tag commit with build number.
##############################################################################

# Figure out where ContentDelivery.log file is located.
DISTRO_LOGS=`cat "$EXPORT_LOG" | grep "Created bundle at path" | sed -E 's/.+Created bundle at path "(.+)"./\1/'`
DELIVERY_LOG="${DISTRO_LOGS}/ContentDelivery.log"

# Extract version and build number from ContentDelivery.log
SEMANTIC_VERSION=`grep "Short version string: " "$DELIVERY_LOG" | sed -E 's/Short version string: ([0-9\.]+)/\1/'`
BUILD_NUMBER=`grep "Version string: " "$DELIVERY_LOG" | sed -E 's/ +Version string: ([0-9]+)/\1/'`
BUILD_TAG="builds/v${SEMANTIC_VERSION}+${BUILD_NUMBER}"

GIT=`sh /etc/profile; which git`
COMMIT_HASH=`"$GIT" rev-parse --short HEAD`

"${GIT}" tag ${BUILD_TAG}
"${GIT}" push origin ${BUILD_TAG}

echo "${BLUE}Tagging commit ${NORMAL}${BOLD}${COMMIT_HASH}${NORMAL} with ${NORMAL}${BOLD}${BUILD_TAG}${NORMAL}...${NORMAL}"

##############################################################################
## ...and we are done.
##############################################################################

echo "${GREEN}Done building flavor ${BOLD}${FLAVORFG}${FLAVORBG} $FLAVOR ${NORMAL}\n${BLUE}Build was uploaded to TestFlight.${NORMAL}"
