#!/bin/bash

# Copyright (c) 2008 iphonedevlinux <iphonedevlinux@googlemail.com>
# Copyright (c) 2008, 2009 m4dm4n <m4dm4n@gmail.com>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# What version of the toolchain are we building?
TOOLCHAIN_VERSION="2.2"

# Build everything relative to IPHONEDEV_DIR
# Default is /home/loginname/iphonedev
IPHONEDEV_DIR="${HOME}/Projects/iphone/toolchain"

# Usage
# ======================
#
# 1. Configure $IPHONEDEV_DIR and $TOOLCHAIN_VERSION to desired settings.
#    The script will operate entirely within $IPHONEDEV_DIR. Basic sanity
#    checks against the $TOOLCHAIN_VERSION are included.
#
# 2. Run these commands in order:
# 	./toolchain.sh headers
# 	./toolchain.sh firmware
# 	./toolchain.sh darwin_sources
# 	./toolchain.sh build
#    OR simply run:
#	./toolchain.sh all
#
# ./toolchain.sh all
#   Perform all stages in the order defined below. See each individual
#   stage for details.
#
# ./toolchain.sh headers
#   Extract OSX and iPhone SDK headers from the iPhone SDK image. You
#   will need to have the image available to provide to the script. This
#   is not downloaded automatically. Results extracted to
#   $IPHONEDEV_DIR/SDKs/iPhoneOS2.{version}.sdk and
#   $IPHONEDEV_DIR/SDKs/MacOSX10.5.sdk
#
# ./toolchain.sh firmware
#   Extract iPhone or iPod touch firmware located in
#   $IPHONEDEV_DIR/files/firmware/ or downloads firmware appropriate to the
#   toolchain version automatically using firmware.list. Now searches for
#   decryptions-keys and tries to extract the root-filesystem of the
#   firmware to ./files/fw/{FirmwareVersion}/system. The symlink
#   ./files/fw/current is automatically set to the extracted system.
#
# ./toolchain.sh darwin_sources
#   You will need to register at developer.apple.com or have a valid account.
#   You may specify APPLE_ID and APPLE_PASSWORD environment variables to avoid
#   prompting.
#
# ./toolchain.sh build
#   Starts the build process decribed by saurik in
#   http://www.saurik.com/id/4. This script uses the same paths under
#   $IPHONEDEV_DIR/toolchain/

FILES_DIR="${IPHONEDEV_DIR}/files"
SDKS_DIR="${IPHONEDEV_DIR}/sdks"
TOOLS_DIR="${IPHONEDEV_DIR}/tools"
XPWN_DIR="${TOOLS_DIR}/xpwn"
MIG_DIR="${TOOLS_DIR}/mig"
TMP_DIR="${IPHONEDEV_DIR}/tmp"
MNT_DIR="${FILES_DIR}/mnt"
FW_DIR="${FILES_DIR}/firmware"

IPHONE_SDK="iphone_sdk_for_iphone_os_${TOOLCHAIN_VERSION}_*_final.dmg"
IPHONE_SDK_DMG="${FILES_DIR}/${IPHONE_SDK}"
IPHONE_SDK_IMG="${FILES_DIR}/iphone_sdk.img"

DMG="${TOOLS_DIR}/dmg"
VFDECRYPT="${TOOLS_DIR}/vfdecrypt"
MIG="${MIG_DIR}/mig"

MACOSX_PKG="${MNT_DIR}/Packages/MacOSX10.5.pkg"
IPHONE_PKG="${MNT_DIR}/Packages/iPhoneSDKHeadersAndLibs.pkg"

# Tools
XPWN_GIT="git://github.com/planetbeing/xpwn.git"
MIG_URL="ftp://ftp.gnu.org/gnu/mig/mig-1.3.tar.gz"
VFDECRYPT_URL="http://iphone-elite.googlecode.com/files/vfdecrypt-linux.tar.gz"
IPHONEWIKI_KEY_URL="http://www.theiphonewiki.com/wiki/index.php?title=VFDecrypt_Keys"

# Download information for Apple's open source components
AID_LOGIN="https://daw.apple.com/cgi-bin/WebObjects/DSAuthWeb.woa/wa/login?appIdKey=D236F0C410E985A7BB866A960326865E7F924EB042FA9A161F6A628F0291F620&path=/darwinsource/tarballs/apsl/cctools-667.8.0.tar.gz"
DARWIN_SOURCES_DIR="$FILES_DIR/darwin_sources"

NEEDED_COMMANDS="git-clone git-pull gcc cmake make sudo mount xar cpio tar wget unzip gawk"
NEEDED_PACKAGES="libssl-dev libbz2-dev gobjc bison flex"

HERE=`pwd`

# Beautified echo commands
cecho() {
	while [[ $# > 1 ]]; do
		case $1 in
			red)	echo -n "$(tput setaf 1)";;
			green)	echo -n "$(tput setaf 2)";;
			blue)	echo -n "$(tput setaf 3)";;
			purple)	echo -n "$(tput setaf 4)";;
			cyan)	echo -n "$(tput setaf 5)";;
			grey)	echo -n "$(tput setaf 6)";;
			white)	echo -n "$(tput setaf 7)";;
			bold)	echo -n "$(tput bold)";;
			*) 	break;;
		esac
		shift
	done
	echo "$*$(tput sgr0)"
}

error() {
	cecho red $*
}

message_status() {
	cecho green $*
}

message_action() {
	cecho blue $*
}

check_commands() {
    local command
    local missing
    for c in $NEEDED_COMMANDS ; do
        command=$(which $c)
        if [ -z $command ] ; then 
            missing="$missing $c"
        fi
    done
    if [ "$missing" != "" ] ; then
        error "The following commands are missing:$missing"
        error "You may need to install additional software for them using your package manager."
        exit 1
    fi
}

check_packages() {
	local missing
	for p in $NEEDED_PACKAGES; do
		local package_state=$(dpkg --get-selections | awk "/^$p.*install$/ { print \"install\"; exit }")
		if ! [ "$package_state" == "install" ]; then
			missing="$missing $p"
		fi
	done
	if [ "$missing" != "" ] ; then
		error "The following required packages are missing:$missing"
		error "You may need to install them using your package manager."
		exit 1
	fi
}

# Takes a plist string and does a very basic lookup of a particular key value,
# given a key name and an XPath style path to the key in terms of dict entries
plist_key() {
	local PLIST_PATH="$2"
	local PLIST_KEY="$1"
	local PLIST_DATA="$3"

	cat "${PLIST_DATA}" | awk '
		/<key>.*<\/key>/ { sub(/^.*<key>/, "", $0); sub(/<\/key>.*$/, "", $0); lastKey = $0; }
		/<dict>/ { path = path lastKey "/"; }
		/<\/dict>/ { sub(/[a-zA-Z0-9]*\/$/, "", path);}
		/<((string)|(integer))>.*<\/((string)|(integer))>/ {
			if(lastKey == "'"${PLIST_KEY}"'" && path == "'"${PLIST_PATH}"'") {
				sub(/^.*<((string)|(integer))>/,"", $0);
				sub(/<\/((string)|(integer))>.*$/,"", $0);
				print $0;
			}
		}'
}

# Builds the XPWN dmg decryption tools, which we will use later to convert dmgs to
# images, so that we can mount them.
build_xpwn_dmg() {
    [ ! -d $TOOLS_DIR ] && mkdir -p $TOOLS_DIR
    [ -x $DMG ] && return

    # Check for xpwn and try to update it if we're working off the git
    # repo that should have been extracted earlier
    if [ -d $XPWN_DIR ] ; then
        if [ -d "$XPWN_DIR/.git" ] ; then
            message_status "Updating xpwn git..."
            if cd "$XPWN_DIR" && ! git pull $XPWN_GIT master; then
            	error "Failed to pull xpwn git. Check errors."
            	exit 1
            fi
        fi
    else 
        message_status "Checking out xpwn git..."
        if ! git clone $XPWN_GIT $XPWN_DIR; then
        	error "Failed to clone xpwn git. Check errors."
        	exit 1
        fi
    fi

    cd $XPWN_DIR

    message_status "Building xpwn's dmg-to-iso tool..."
    [ -r Makefile ] && make clean
    if cmake CMakeLists.txt && cd dmg && make; then
	message_status "Build finished."
	if cp dmg $DMG; then
		# Get rid of the xpwn stuff, we don't need it anymore
		message_status "Removing xpwn remnants."
		cd $HERE && rm -Rf $XPWN_DIR
	else
		error "Failed to copy xpwn's dmg-to-iso tool to ${DMG}."
		exit 1
	fi
    else
    	error "Failed to make xpwn. Check errors."
    	exit 1
    fi
}

# Retrieve and build vfdecrypt, which is used for decrypting the ipsw firmware images
# which we will download automatically.
build_vfdecrypt() {
    if [ ! -x $VFDECRYPT ] ; then
    	message_status "Downloading and building vfdecrypt..."
    	mkdir -p $TOOLS_DIR && cd $TOOLS_DIR
        
        local VFDECRYPT_TGZ=`basename $VFDECRYPT_URL`
        
        # Try to locate the tool source or ask the user if we can't find it. As a last
        # resort we can download it.
        if [ ! -r $VFDECRYPT_TGZ ]; then
        	echo "I can't find the VFDecrypt source ($VFDECRYPT_TGZ)."
        	read -p "Do you have it (y/N)? "
        	if [ "$REPLY" == "yes" ] || [ "$REPLY" == "y" ]; then
        		read -p "Location of VFDecrypt: " VFDECRYPT_TGZ
        	else
        		read -p "Do you want me to download it (Y/n)? "
        		[ "$REPLY" != "no" ] && [ "$REPLY" != "n" ] && wget $VFDECRYPT_URL
        	fi
        fi
        
        if [ -r $VFDECRYPT_TGZ ]; then
        	tar xfzv $VFDECRYPT_TGZ vfdecrypt.c
        	if ! gcc -o vfdecrypt vfdecrypt.c -lssl; then
        		error "Failed to build VFdecrypt! Check errors."
        		exit 1
        	fi
        	rm $VFDECRYPT_TGZ vfdecrypt.c
        else
        	error "I can't find the VFdecrypt source or executable."
        	error "Building the toolchain cannot proceed"
        	exit 1
        fi
    fi
}

convert_dmg_to_img() {
    [ ! -x $DMG ] && build_xpwn_dmg

    # Look for the DMG and ask the user if is isn't findable. It's probably possible
    # to automate this, however I don't feel it's appropriate at this time considering
    # that the download size would force the user to leave the script running unattended
    # for too long.
    if [ ! -r $IPHONE_SDK_IMG ] && [ ! -r $IPHONE_SDK_DMG ] ; then
    	error "I'm having trouble finding the iPhone SDK. I looked here:"
    	error $IPHONE_SDK_DMG
    	read -p "Do you have the SDK (y/N)? "
    	if [ "$REPLY" != "y" ]; then
    		error "You will need to download the SDK before you can build the toolchain. The"
    		error "required file can be obtained from: http://developer.apple.com/iphone/"
    		exit 1
    	fi
    	echo "Please enter the full path to the dmg containing the SDK:"
    	read IPHONE_SDK_DMG
    	if [ ! -r $IPHONE_SDK_DMG ] ; then
    		error "Sorry, I can't find the file!"
    		error "You will need to download the SDK before you can build the toolchain. The"
    		error "required file can be obtained from: http://developer.apple.com/iphone/"
    		exit 1
    	fi
    fi

    if [ ! -r $IPHONE_SDK_IMG ] ; then
    	message_status "Converting `basename $IPHONE_SDK_DMG` to img format..."
        $DMG extract $IPHONE_SDK_DMG $IPHONE_SDK_IMG > /dev/null
        if [ ! -s $IPHONE_SDK_IMG ]; then
        	error "Failed to extract `basename $IPHONE_SDK_DMG`!"
        	rm $IPHONE_SDK_IMG
        	exit 1
        fi
    fi
}

extract_headers() {
    mkdir -p ${MNT_DIR}
    mkdir -p ${SDKS_DIR}
    mkdir -p ${TMP_DIR}
    
    # Make sure we don't already have these
    if [ -d "${SDKS_DIR}/iPhoneOS${TOOLCHAIN_VERSION}.sdk" ] && [ -d "${SDKS_DIR}/MacOSX10.5.sdk" ]; then
    	echo "SDKs seem to already be extracted."
    	return
    fi

    # Inform the user why we suddenly need their password
    message_status "Trying to mount the iPhone SDK img..."
    echo "In order to extract `basename $IPHONE_SDK_IMG`, I am going to run:"
    echo -e "\tsudo mount -o loop $IPHONE_SDK_IMG $MNT_DIR"
    
    if ! sudo mount -o loop $IPHONE_SDK_IMG $MNT_DIR ; then
    	error "Failed to mount ${IPHONE_SDK_IMG} at ${MNT_DIR}!"
    	exit 1
    fi
    message_status "Extracting `basename $IPHONE_PKG`..."

    rm -fR $TMP_DIR/*

    cp $IPHONE_PKG $TMP_DIR/iphone.pkg
    cd $TMP_DIR
    xar -xf iphone.pkg Payload
    mv Payload Payload.gz
    gunzip Payload.gz
    cat Payload | cpio -id "*.h"
    mv Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${TOOLCHAIN_VERSION}.sdk ${SDKS_DIR}

    rm -fR $TMP_DIR/*

    message_status "Extracting `basename $MACOSX_PKG`..."

    cp $MACOSX_PKG $TMP_DIR/macosx.pkg
    cd $TMP_DIR 
    xar -xf macosx.pkg Payload
    mv Payload Payload.gz
    gunzip Payload.gz
    cat Payload | cpio -id "*.h"
    mv SDKs/MacOSX10.5.sdk ${SDKS_DIR}

    rm -fR $TMP_DIR/*

    message_status "Unmounting iPhone SDK img..."
    sudo umount $MNT_DIR
    message_status "Removing `basename $IPHONE_SDK_IMG`..."
    rm $IPHONE_SDK_IMG
}

# If we can't find the firmware file we try to download it from the
# apple download urls above.
extract_firmware() {
   [ ! -x $VFDECRYPT ] && build_vfdecrypt
   [ ! -x $DMG ] && build_xpwn_dmg
   mkdir -p $FW_DIR
   mkdir -p $MNT_DIR
   mkdir -p $TMP_DIR

    if [ -z "$FW_FILE" ]; then
    	FW_FILE=`ls ${FW_DIR}/*${TOOLCHAIN_VERSION}*.ipsw 2>/dev/null`
    	if [ ! $? ] && [[ `echo ${FW_FILE} | wc -w` > 1 ]]; then
    		error "I attempted to search for the correct firmware version, but"
    		error "it looks like you have several ipsw files. Please specify"
    		error "one like so:"
    		error "./toolchain.sh firmware /path/to/firmware/here.ipsw"
    		exit 1
    	fi
    fi

    if [ ! -r "$FW_FILE" ] ; then
    	echo "I can't find the firmware image for iPhone/iPod Touch $TOOLCHAIN_VERSION."
    	read -p "Do you have it (y/N)?"
    	if [ "$REPLY" != "y" ] && [ "$REPLY" != "yes" ]; then 
	    	read -p "Do you want me to download it (Y/n)?"
	    	if [ "$REPLY" != "n" ] && [ "$REPLY" != "no" ]; then
			APPLE_DL_URL=$(cat ${HERE}/firmware.list | awk '$1 ~ /'"^${TOOLCHAIN_VERSION}$"'/ && $2 ~ /^iPhone\(3G\)$/ { print $3; }')
			FW_FILE=`basename "${APPLE_DL_URL}"`
			if [ ! $APPLE_DL_URL ] ; then
			    error "Can't find a download url for the toolchain version and platform specified."
			    error "You may have to download it manually.".
			    exit 1;
			else 
			    message_status "Downloading: $FW_FILE"
			    cd $TMP_DIR
			    wget -nc -c $APPLE_DL_URL
			    mv $FW_FILE $FW_DIR
			    FW_FILE=$FW_DIR/$FW_FILE
			fi
		else
			error "I need the firmware image to build the toolchain."
			exit 1
		fi
	else
		while [ ! -a $FW_FILE ] && [ -z $FW_FILE ]; do
			read -p "Location of firmware image: " FW_FILE
			[ ! -a $FW_FILE ] && error "File not found."
		done
		
		if [ ! -a $FW_FILE ]; then
			error "I need the firmware image to build the toolchain."
			exit 1
		fi
	fi
    fi
    
    cd "$FW_DIR"
    unzip -d "${TMP_DIR}" -o "${FW_FILE}" Restore.plist

    # Retrieve information from the firmware image we downloaded so we know
    # which file to decrypt and which key to use to decrypt it
    FW_DEVICE_CLASS=$(plist_key DeviceClass "/" "${TMP_DIR}/Restore.plist")
    FW_PRODUCT_VERSION=$(plist_key ProductVersion "/" "${TMP_DIR}/Restore.plist")
    FW_BUILD_VERSION=$(plist_key ProductBuildVersion "/" "${TMP_DIR}/Restore.plist")
    FW_RESTORE_RAMDISK=$(plist_key User "/RestoreRamDisks/" "${TMP_DIR}/Restore.plist")
    FW_RESTORE_SYSTEMDISK=$(plist_key User "/SystemRestoreImages/" "${TMP_DIR}/Restore.plist")
    
    cecho bold "Firmware Details"
    echo "Device Class: ${FW_DEVICE_CLASS}"
    echo "Product Version: ${FW_PRODUCT_VERSION}"
    echo "Build Version: ${FW_BUILD_VERSION}"
    echo "Restore RamDisk: ${FW_RESTORE_RAMDISK}"
    echo "Restore Image: ${FW_RESTORE_SYSTEMDISK}"
    
    message_status "Unzipping `basename $FW_RESTORE_SYSTEMDISK`..."
    unzip -d "${TMP_DIR}" -o "${FW_FILE}" "${FW_RESTORE_SYSTEMDISK}"

    message_status "Decrypting firmware image..."
    if [ -z "$DECRYPTION_KEY_SYSTEM" ] ; then
        echo "We need the decryption key for `basename $FW_RESTORE_SYSTEMDISK`."
        echo "I'm going to try to fetch it from $IPHONEWIKI_KEY_URL...."
        DECRYPTION_KEY_SYSTEM=$( wget --quiet -O - $IPHONEWIKI_KEY_URL | awk '
            /name=\"'"${FW_PRODUCT_VERSION}"'.*'"${FW_BUILD_VERSION}"'/ { found = 1; IGNORECASE = 1; }
            /<p>.*$/ && found { sub(/.*<p>/, "", $0); print toupper($0); exit; }' )
        if [ ! "$DECRYPTION_KEY_SYSTEM" ] ; then
            error "Sorry, no decryption key for system partition found!"
            exit 1;
        fi
        echo "I found it!"
    fi

    echo "Starting vfdecrypt with decryption key: $DECRYPTION_KEY_SYSTEM"
    cd "${TMP_DIR}"
    $VFDECRYPT -i"${FW_RESTORE_SYSTEMDISK}" -o"${FW_RESTORE_SYSTEMDISK}.decrypted" -k "$DECRYPTION_KEY_SYSTEM" &> /dev/null

    if [ ! -s "${FW_RESTORE_SYSTEMDISK}.decrypted" ]; then
    	error "Decryption of `basename $FW_RESTORE_SYSTEMDISK` failed!"
    	exit 1
    fi
    
    message_status "`basename $FW_RESTORE_SYSTEMDISK` decrypted!"

    FW_VERSION_DIR="${FW_DIR}/${FW_PRODUCT_VERSION}_${FW_BUILD_VERSION}"
    FW_SYSTEM_DIR="${FW_VERSION_DIR}"
    FW_SYSTEM_DMG="${TMP_DIR}/root_system.dmg"

    [ ! -d $FW_VERSION_DIR ] && mkdir "${FW_VERSION_DIR}"
    [ ! -d $FW_SYSTEM_DIR  ] && mkdir "${FW_SYSTEM_DIR}"

    if [ ! -r ${FW_SYSTEM_DMG} ] ; then
    	message_status "Extracting decrypted dmg..."
        $DMG extract "${FW_RESTORE_SYSTEMDISK}.decrypted" ${FW_SYSTEM_DMG} > /dev/null
    fi

    message_status "Trying to mount `basename ${FW_SYSTEM_DMG}`..."
    echo "I am about to mount a file using the command:"
    echo -e "\tsudo mount -t hfsplus -o loop \"${FW_SYSTEM_DMG}\" \"${MNT_DIR}\""
    
    if ! sudo mount -t hfsplus -o loop "${FW_SYSTEM_DMG}" "${MNT_DIR}" ; then
    	error "Failed to mount $(basename "${FW_SYSTEM_DMG}")."
    	exit 1
    fi
    
    cd "${MNT_DIR}"
    message_status "Copying required components of the firmware..."
    sudo cp -Ra * "${FW_SYSTEM_DIR}"
    sudo chown -R `id --user`:`id --group` $FW_SYSTEM_DIR
    cd ${HERE}
    message_status "Unmounting..."
    sudo umount "${MNT_DIR}"
    
    if [ -s "${FW_DIR}/current" ] ; then
        rm "${FW_DIR}/current";
    fi

    ln -s "${FW_SYSTEM_DIR}" "${FW_DIR}/current"
    
    # Cleanup
    rm "${TMP_DIR}/$FW_RESTORE_SYSTEMDISK" "${TMP_DIR}/${FW_RESTORE_SYSTEMDISK}.decrypted" \
    	$FW_SYSTEM_DMG "${TMP_DIR}/Restore.plist"
}

toolchain_download_darwin_sources() {
	mkdir -p $DARWIN_SOURCES_DIR && cd $DARWIN_SOURCES_DIR

	message_status "Trying to log you in to the Darwin sources repository..."
	# Extract an auto-generated session key to make nice with Apple's login script
	echo -n "Getting session key..."
	LOGIN_URL=$(wget --no-check-certificate --quiet -O - $AID_LOGIN | awk '{
		if(match($0,/\/cgi-bin\/WebObjects\/DSAuthWeb\.woa\/[0-9]+\/wo\/[a-zA-Z0-9]*?\/[^"]*/))
			print substr($0, RSTART, RLENGTH);
	}')

	if [ "$LOGIN_URL" == "" ]; then
		error "Oh dear, I can't seem to log you in! There was a problem"
		error "retrieving the login form session ID. Apple probably"
		error "changed something on their site."
		error "Installation of the toolchain cannot proceed."
		exit 1
	fi

	# Attempt to login
	echo -e "Got the session key."
	echo -ne "Logging in..."
	LOGIN_ERROR=$(wget --quiet --save-cookies=cookies.tmp --keep-session-cookies \
			--post-data="theAccountName=${APPLE_ID}&theAccountPW=${APPLE_PASSWORD}&1.Continue.x=1&1.Continue.y=1&theAuxValue=" \
			--no-check-certificate -O - "https://daw.apple.com${LOGIN_URL}" | awk '{
		if(match($0, /<FONT COLOR="#ff0000" SIZE=1>([^<]*)<\/FONT>/)) {
			$0 = substr($0, RSTART, RLENGTH);
			sub(/<\/?FONT.*>/, "", $0);
			print $0;
		}
	}')

	if [ "$LOGIN_ERROR" != "" ]; then
		error "Error!"
		error "Oh dear, I can't seem to log you in! Apple's login server told me:"
		error "\"${LOGIN_ERROR}\""
		error "Installation of toolchain cannot proceed."
		exit
	fi

	echo "Login successful."

	# Need to accept the license agreement
	echo "Accepting APSL agreement on your behalf..."
	wget --quiet --load-cookies=cookies.tmp \
		--keep-session-cookies --post-data="APSLrev=2.0&querystr=&acceptBtn=Yes%2C+I+Accept" \
		-O - "http://www.opensource.apple.com/cgi-bin/apslreg.cgi" &> /dev/null

	# Get what we're here for
	message_status "Attempting to download tool sources..."
	wget --max-redirect=0 --no-clobber --keep-session-cookies --load-cookies=cookies.tmp --input-file=${HERE}/darwin-tools.list
	message_status "Finished downloading!"

	rm cookies.tmp
}

toolchain_extract_headers() {
    convert_dmg_to_img
    extract_headers
}

toolchain_system_files() {
    build_vfdecrypt
    extract_firmware
}

# This is more or less copy/paste from www.saurik.com/id/4
# Modified fairly heavily by m4dm4n for SDK 2.2, fixing some missing
# hardlinks and incorrect patches
toolchain_build() {

    local TOOLCHAIN="${IPHONEDEV_DIR}/toolchain"
    local LEOPARD_SDK="${SDKS_DIR}/MacOSX10.5.sdk"
    local LEOPARD_SDK_INC="${LEOPARD_SDK}/usr/include"
    local LEOPARD_SDK_LIBS="${LEOPARD_SDK}/System/Library/Frameworks"
    local IPHONE_SDK="${SDKS_DIR}/iPhoneOS${TOOLCHAIN_VERSION}.sdk"
    local IPHONE_SDK_INC="${IPHONE_SDK}/usr/include"
    local IPHONE_SDK_LIBS="${IPHONE_SDK}/System/Library/Frameworks"
    local CCTOOLS_DIR="$TOOLCHAIN/src/cctools"
    local GCC_DIR="$TOOLCHAIN/src/gcc"
    local CSU_DIR="$TOOLCHAIN/src/csu"
    export PATH="$TOOLCHAIN/pre/bin":"${PATH}" 
    if [[ $TOOLCHAIN_VERSION > 2.0 ]]; then
    	local TARGET="arm-apple-darwin9"
    else
    	local TARGET="arm-apple-darwin8"
    fi

    [ ! -d "$TOOLCHAIN" ] && mkdir -p "${TOOLCHAIN}"

    cd "${DARWIN_SOURCES_DIR}"
    message_status "Finding and extracting archives..."
    find ./* -name '*.tar.gz' -exec tar --overwrite -xzof {} \;
    
    # Permissions are being extracted along with the gzipped files. I can't seem to get
    # tar to ignore this, and they are constantly in the way so I'll use this hack.
    chmod -R 755 *

    mkdir -p "$(dirname "$TOOLCHAIN/sys")"
    cd "$TOOLCHAIN/sys"

    if [ ! -d "${FW_DIR}/current" ] ; then
        error "I couldn't find an iPhone filesystem at: ${FW_DIR}/current"
        exit 1
    fi

    if [ -d $sysroot ] && [[ `ls -A $sysroot | wc -w` > 0 ]]; then
	    echo "It looks like the iPhone filesystem has already been copied."
	    read -p "Copy again (y/N)? "
	    if [ "${REPLY}" == "y" ]; then
	    	message_status "Copying required iPhone filesystem components..."
	    	# I have tried to avoid copying the permissions (not using -a) because they
	    	# get in the way later down the track. This might be wrong but it seems okay.
	    	cp -rdH ${FW_DIR}/current/* "$TOOLCHAIN/sys"
	    	rm -rf usr/include
	    fi
    else
    	message_status "Copying required iPhone filesystem components..."
    	cp -rdH ${FW_DIR}/current/* "$TOOLCHAIN/sys" # As above
    	rm -rf usr/include
    fi

    # Presently working here and below
    message_status "Copying SDK headers..."
    echo "Leopard"
    cp -a "${LEOPARD_SDK_INC}" usr/include
    cd usr/include
    ln -s . System

    cp -af "${IPHONE_SDK_INC}"/* .
    cp -af "${DARWIN_SOURCES_DIR}"/xnu-*/osfmk/* "${DARWIN_SOURCES_DIR}"/xnu-*/bsd/* .

    echo "mach"
    cp -af "${DARWIN_SOURCES_DIR}"/cctools-*/include/mach .
    cp -af "${DARWIN_SOURCES_DIR}"/cctools-*/include/mach-o .
    cp -af "${IPHONE_SDK_INC}"/mach-o/dyld.h mach-o

    cp -af "${LEOPARD_SDK_INC}"/mach/machine mach
    cp -af "${LEOPARD_SDK_INC}"/mach/machine.h mach
    cp -af "${LEOPARD_SDK_INC}"/machine .
    cp -af "${IPHONE_SDK_INC}"/machine .

    cp -af "${IPHONE_SDK_INC}"/sys/cdefs.h sys
    cp -af "${LEOPARD_SDK_INC}"/sys/dtrace.h sys

    cp -af "${LEOPARD_SDK_LIBS}"/Kernel.framework/Versions/A/Headers/machine/disklabel.h machine
    cp -af "${DARWIN_SOURCES_DIR}"/configd-*/dnsinfo/dnsinfo.h .
    cp -a "${DARWIN_SOURCES_DIR}"/Libc-*/include/kvm.h .
    cp -a "${DARWIN_SOURCES_DIR}"/launchd-*/launchd/src/*.h .

    cp -a i386/disklabel.h arm
    cp -a mach/i386/machine_types.defs mach/arm

    # if you don't have mig, just ignore this for now
    #for defs in clock_reply exc mach_exc notify; do
    #    mig -server /dev/null -user /dev/null -header /dev/null \
    #        -sheader mach/"${defs}"_server.h mach/"${defs}".defs
    #done

    mkdir -p Kernel
    echo "libsa"
    cp -a "${DARWIN_SOURCES_DIR}"/xnu-*/libsa/libsa Kernel

    mkdir -p Security
    echo "libsecurity"
    cp -a "${DARWIN_SOURCES_DIR}"/libsecurity_authorization-*/lib/*.h Security
    cp -a "${DARWIN_SOURCES_DIR}"/libsecurity_cdsa_client-*/lib/*.h Security
    cp -a "${DARWIN_SOURCES_DIR}"/libsecurity_cdsa_utilities-*/lib/*.h Security
    cp -a "${DARWIN_SOURCES_DIR}"/libsecurity_cms-*/lib/*.h Security
    cp -a "${DARWIN_SOURCES_DIR}"/libsecurity_codesigning-*/lib/*.h Security
    cp -a "${DARWIN_SOURCES_DIR}"/libsecurity_cssm-*/lib/*.h Security
    cp -a "${DARWIN_SOURCES_DIR}"/libsecurity_keychain-*/lib/*.h Security
    cp -a "${DARWIN_SOURCES_DIR}"/libsecurity_mds-*/lib/*.h Security
    cp -a "${DARWIN_SOURCES_DIR}"/libsecurity_ssl-*/lib/*.h Security
    cp -a "${DARWIN_SOURCES_DIR}"/libsecurity_utilities-*/lib/*.h Security
    cp -a "${DARWIN_SOURCES_DIR}"/libsecurityd-*/lib/*.h Security

    mkdir -p DiskArbitration
    echo "DiskArbitration"
    cp -a "${DARWIN_SOURCES_DIR}"/DiskArbitration-*/DiskArbitration/*.h DiskArbitration

    echo "iokit"
    cp -a "${DARWIN_SOURCES_DIR}"/xnu-*/iokit/IOKit .
    cp -a "${DARWIN_SOURCES_DIR}"/IOKitUser-*/*.h IOKit

    cp -a "${DARWIN_SOURCES_DIR}"/IOGraphics-*/IOGraphicsFamily/IOKit/graphics IOKit
    cp -a "${DARWIN_SOURCES_DIR}"/IOHIDFamily-*/IOHIDSystem/IOKit/hidsystem IOKit

    for proj in kext ps pwr_mgt; do
        mkdir -p IOKit/"${proj}"
        cp -a "${DARWIN_SOURCES_DIR}"/IOKitUser-*/"${proj}".subproj/*.h IOKit/"${proj}"
    done

    mkdir -p IOKit/storage
    cp -a "${DARWIN_SOURCES_DIR}"/IOStorageFamily-*/*.h IOKit/storage
    cp -a "${DARWIN_SOURCES_DIR}"/IOCDStorageFamily-*/*.h IOKit/storage
    cp -a "${DARWIN_SOURCES_DIR}"/IODVDStorageFamily-*/*.h IOKit/storage

    mkdir -p SystemConfiguration
    echo "configd"
    cp -a "${DARWIN_SOURCES_DIR}"/configd-*/SystemConfiguration.fproj/*.h SystemConfiguration

    mkdir -p WebCore
    echo "WebCore"
    cp -a  "${DARWIN_SOURCES_DIR}"/WebCore*/bindings/objc/*.h WebCore

    echo "CoreFoundation"
    mkdir -p CoreFoundation
    cp -a "${LEOPARD_SDK_LIBS}"/CoreFoundation.framework/Versions/A/Headers/* CoreFoundation
    cp -af "${DARWIN_SOURCES_DIR}"/CF-*/*.h CoreFoundation
    cp -af "${IPHONE_SDK_LIBS}"/CoreFoundation.framework/Headers/* CoreFoundation

    for framework in AudioToolbox AudioUnit CoreAudio QuartzCore Foundation; do
    	echo $framework
    	mkdir -p $framework
        cp -a "${LEOPARD_SDK_LIBS}"/"${framework}".framework/Versions/*/Headers/* "${framework}"
        cp -af "${IPHONE_SDK_LIBS}"/"${framework}".framework/Headers/* "${framework}"
    done

    # UIKit fix (these are only the public framework headers)
    mkdir -p UIKit
    cp -a "${IPHONE_SDK_LIBS}"/UIKit.framework/Headers/* UIKit 

    for framework in AppKit Cocoa CoreData CoreVideo JavaScriptCore OpenGL WebKit; do
    	echo $framework
    	mkdir -p $framework
    	cp -a "${LEOPARD_SDK_LIBS}"/"${framework}".framework/Versions/*/Headers/* $framework
    done

    echo "Application Services"
    mkdir -p ApplicationServices
    cp -a "${LEOPARD_SDK_LIBS}"/ApplicationServices.framework/Versions/A/Headers/* ApplicationServices
    for service in "${LEOPARD_SDK_LIBS}"/ApplicationServices.framework/Versions/A/Frameworks/*.framework; do
    	echo -e "\t$(basename $service .framework)"
    	mkdir -p "$(basename $service .framework)"
        cp -a $service/Versions/A/Headers/* "$(basename $service .framework)"
    done

    echo "Core Services"
    mkdir -p CoreServices
    cp -a "${LEOPARD_SDK_LIBS}"/CoreServices.framework/Versions/A/Headers/* CoreServices
    for service in "${LEOPARD_SDK_LIBS}"/CoreServices.framework/Versions/A/Frameworks/*.framework; do
    	mkdir -p "$(basename $service .framework)"
        cp -a $service/Versions/A/Headers/* "$(basename $service .framework)"
    done
    
    message_status "Applying patches..."

    if [ ! -r "${HERE}/include.diff" ]; then
    	error "Missing include.diff! This file is required to merge the OSX and iPhone SDKs."
    	exit 1
    fi

    # this step may have a bad hunk in CoreFoundation and thread_status while patching
    # these errors are to be ignored, as these are changes for issues Apple has now fixed
    # include.diff is a modified version of saurik's patch to support iPhone 2.2 SDK.
    patch -p3 -N < "${HERE}/include.diff"
    wget -qO arm/locks.h http://svn.telesphoreo.org/trunk/tool/patches/locks.h

    mkdir -p GraphicsServices
    cd GraphicsServices
    wget -q http://svn.telesphoreo.org/trunk/tool/patches/GraphicsServices.h

    cd "$TOOLCHAIN/sys"
    ln -sf gcc/darwin/4.0/stdint.h usr/include
    ln -s libstdc++.6.dylib usr/lib/libstdc++.dylib

    # Changed some of the below commands from sudo; don't know why they were like that
    message_status "Checking out iphone-dev repo..."
    mkdir -p "${CSU_DIR}"
    cd "${CSU_DIR}"
    svn co http://iphone-dev.googlecode.com/svn/trunk/csu .
    cp -a *.o "$TOOLCHAIN/sys"/usr/lib
    cd "$TOOLCHAIN/sys"/usr/lib
    chmod 644 *.o
    cp -af crt1.o crt1.10.5.o
    cp -af dylib1.o dylib1.10.5.o

    if [ ! -d $gcc ]; then
    	message_status "Checking out saurik's llvm-gcc-4.2..."
    	rm -rf "${GCC_DIR}"
    	git clone git://git.saurik.com/llvm-gcc-4.2 "${GCC_DIR}"
    else
    	message_status "Updating llvm-gcc-4.2..."
    	pushd $gcc && git pull git://git.saurik.com/llvm-gcc-4.2 master && popd
    fi
    
    message_status "Checking out odcctools..."
    mkdir -p "${CCTOOLS_DIR}"
    svn co http://iphone-dev.googlecode.com/svn/branches/odcctools-9.2-ld "${CCTOOLS_DIR}"


    message_status "Building cctools-iphone..."
    mkdir -p "$TOOLCHAIN/pre"
    cecho bold "Build progress logged to: toolchain/bld/cctools-iphone/make.log"
    mkdir -p "$TOOLCHAIN/bld/cctools-iphone"
    cd "$TOOLCHAIN/bld/cctools-iphone"
    CFLAGS=-m32 LDFLAGS=-m32 "${CCTOOLS_DIR}"/configure \
        --target="${TARGET}" \
        --prefix="$TOOLCHAIN/pre" \
        --disable-ld64
    make clean
    if ! ( make &>make.log && make install &>install.log ); then
    	error "Build & install failed. Check make.log and install.log"
    fi

    message_status "Building gcc-4.2-iphone..."
    cecho bold "Build progress logged to: toolchain/bld/gcc-4.2-iphone/make.log"
    mkdir -p "$TOOLCHAIN/bld"
    cd "$TOOLCHAIN/bld"
    mkdir gcc-4.2-iphone
    cd gcc-4.2-iphone
    "${GCC_DIR}"/configure \
        --target="${TARGET}" \
        --prefix="$TOOLCHAIN/pre" \
        --with-sysroot="$TOOLCHAIN/sys" \
        --enable-languages=c,c++,objc,obj-c++ \
        --with-as="$TOOLCHAIN/pre"/bin/"${TARGET}"-as \
        --with-ld="$TOOLCHAIN/pre"/bin/"${TARGET}"-ld \
        --enable-wchar_t=no \
        --with-gxx-include-dir=/usr/include/c++/4.0.0
    make clean
    if ! ( make -j2 &>make.log && make install &>install.log ); then
    	error "Build & install failed. Check make.log and install.log"
    fi

    mkdir -p "$TOOLCHAIN/sys"/"$(dirname "$TOOLCHAIN/pre")"
    ln -s "$TOOLCHAIN/pre" "$TOOLCHAIN/sys"/"$(dirname "$TOOLCHAIN/pre")"

}

check_environment() {
	[ $TOOLCHAIN_CHECKED ] && return
	message_action "Preparing the environment"
	cecho bold "Toolchain version: ${TOOLCHAIN_VERSION}"
	check_commands
	check_packages
	message_status "Environment is ready"
}

case $1 in
	all)
		check_environment
		export TOOLCHAIN_CHECKED=1
		./toolchain.sh headers
		./toolchain.sh darwin_sources
		./toolchain.sh firmware
		./toolchain.sh build
		
		read -p "Do you want to clean up the source files used to build the toolchain? (y/N)"
		([ "$REPLY" == "y" ] || [ "$REPLY" == "yes" ]) && ./toolchain.sh clean
		;;
	headers)
		check_environment
		message_action "Getting the header files"
		toolchain_extract_headers
		;;
	    
	darwin_sources)
		check_environment
		# Make sure we have the Apple ID and password
		if [ "$APPLE_ID" == "" ] || [ "$APPLE_PASSWORD" == "" ]; then
			echo "You're going to need an Apple Developer Connection ID and password."
			read -p "Apple ID: " APPLE_ID
			read -s -p "Password: " APPLE_PASSWORD
			echo
		fi

		if [ "$APPLE_ID" != "" ] && [ "$APPLE_PASSWORD" != "" ]; then
		message_action "Downloading Darwin sources"
		echo "Apple ID: $APPLE_ID"
		toolchain_download_darwin_sources
		else
		error "You must provide a valid Apple ID and password combination in order "
		error "to automatically download the required Darwin sources."
		fi
		;;

	firmware)
		check_environment
		message_action "Extracting firmware files"
		toolchain_system_files
		;;

	build)
		check_environment
		message_action "Building the toolchain"
		toolchain_build
		;;

	clean)
		message_status "Cleaning up..."
		
		for file in ${FW_DIR}/*; do
			[ -d "${file}" ] && rm -Rf "${file}"
		done
		rm -f "${FW_DIR}/current"	
		rm -Rf "${MNT_DIR}"
		rm -Rf "${DARWIN_SOURCES_DIR}"
		rm -Rf "${SDKS_DIR}"
		rm -Rf "${TOOLS_DIR}"
		rm -Rf "${TMP_DIR}"
		rm -Rf "${TOOLCHAIN}/src"
		rm -Rf "$TOOLCHAIN/bld"
		
		read -p "Do you want me to remove the SDK dmg (y/N)? "
		( [ "$REPLY" == "yes" ] || [ "$REPLY" == "y" ] ) && rm "${IPHONE_SDK_DMG}"
		
		read -p "Do you want me to remove the firmware image(s) (y/N)? "
		( [ "$REPLY" == "yes" ] || [ "$REPLY" == "y" ] ) && rm -Rf "${FW_DIR}"
		;;

	*)
		# Shows usage information to the user
		BOLD=$(tput bold)
		ENDF=$(tput sgr0)
		echo    "toolchain.sh [ all | headers | darwin_sources | firmware | build | clean ]"
		echo
		echo    "    ${BOLD}all${ENDF}"
		echo -e "    \tPerform all steps in order: headers, darwin_sources,"
		echo -e "    \tfirmware, build and clean."
		echo
		echo    "    ${BOLD}headers${ENDF}"
		echo -e "    \tExtract headers from an iPhone SDK dmg provided by"
		echo -e "    \tthe user in <toolchain>/files/<sdk>.dmg."
		echo
		echo    "    ${BOLD}darwin_sources${ENDF}"
		echo -e "    \tRetrieve required Apple OSS components using a valid"
		echo -e "    \tApple ID and password."
		echo
		echo    "    ${BOLD}firmware${ENDF}"
		echo -e "    \tDownloads (optional) and extracts iPhone an firmware"
		echo -e "    \timage for the specified toolchain version."
		echo
		echo    "    ${BOLD}build${ENDF}"
		echo -e "    \tAcquires and builds the toolchain sources."
		echo
		echo    "    ${BOLD}clean${ENDF}"
		echo -e "    \tRemove source files, extracted dmgs and ipsws and"
		echo -e "    \ttemporary files, leaving only the compiled toolchain"
		echo -e "    \tand headers."
		;;
esac