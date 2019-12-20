#!/bin/bash
#
# Builds OP-TEE Trusted OS.
# Not intended to be called directly, invoked from tos-build.sh.
#
# Board configuration is extracted from
# parse-platforms.py and platforms.config.
#
# Copyright (c) 2015-2019, Linaro Ltd. All rights reserved.
#
# SPDX-License-Identifier: ISC
#

. "$TOOLS_DIR"/common-functions

export CFG_TEE_CORE_LOG_LEVEL=2  # 0=none 1=err 2=info 3=debug 4=flow

function usage
{
	echo "usage:"
	echo "opteed-build.sh -e <EDK2 source directory> -t <UEFI build profile/toolchain> <platform>"
	echo
}

function build_platform
{
	unset CFG_ARM64_core PLATFORM PLATFORM_FLAVOR DEBUG
	TOS_ARCH="`$TOOLS_DIR/parse-platforms.py $PLATFORM_CONFIG -p $1 get -o tos_arch`"
	if [ X"$TOS_ARCH" = X"" ]; then
		TOS_ARCH=arm
	fi
	TOS_PLATFORM="`$TOOLS_DIR/parse-platforms.py $PLATFORM_CONFIG -p $1 get -o tos_platform`"
	if [ X"$TOS_PLATFORM" = X"" ]; then
		TOS_PLATFORM="`$TOOLS_DIR/parse-platforms.py $PLATFORM_CONFIG -p $1 get -o atf_platform`"
		if [ X"$TOS_PLATFORM" = X"" ]; then
			TOS_PLATFORM=$1
		fi
	fi
	TOS_PLATFORM_FLAVOR="`$TOOLS_DIR/parse-platforms.py $PLATFORM_CONFIG -p $1 get -o tos_platform_flavor`"

	#
	# Read platform configuration
	#
	PLATFORM_ARCH="`$TOOLS_DIR/parse-platforms.py $PLATFORM_CONFIG -p $1 get -o arch`"
	PLATFORM_IMAGE_DIR="`$TOOLS_DIR/parse-platforms.py $PLATFORM_CONFIG -p $1 get -o uefi_image_dir`"
	PLATFORM_BUILDFLAGS="`$TOOLS_DIR/parse-platforms.py $PLATFORM_CONFIG -p $1 get -o tos_buildflags`"

	if [ $VERBOSE -eq 1 ]; then
		echo "PLATFORM_ARCH=$PLATFORM_ARCH"
		echo "PLATFORM_IMAGE_DIR=$PLATFORM_IMAGE_DIR"
		echo "PLATFORM_BUILDFLAGS=$PLATFORM_BUILDFLAGS"
	fi

	#
	# Set up cross compilation variables (if applicable)
	#
	# OP-TEE requires both 64- and 32-bit compilers for a 64-bit build
	# For details, visit
	# https://optee.readthedocs.io/building/gits/optee_os.html?#cross-compile
	#
	set_cross_compile
	if [ "$PLATFORM_ARCH" = "AARCH64" ]; then
		export CFG_ARM64_core=y
		export CROSS_COMPILE_core="$TEMP_CROSS_COMPILE"
		export CROSS_COMPILE_ta_arm64="$TEMP_CROSS_COMPILE"
		PLATFORM_ARCH="ARM"
		set_cross_compile
		PLATFORM_ARCH="AARCH64"
		echo "CFG_ARM64_core=$CFG_ARM64_core"
		echo "CROSS_COMPILE_ta_arm64=$CROSS_COMPILE_ta_arm64"
	else
		export CFG_ARM64_core=n
	fi
	export CROSS_COMPILE="$TEMP_CROSS_COMPILE"
	echo "CROSS_COMPILE=$CROSS_COMPILE"
	echo "CROSS_COMPILE_core=$CROSS_COMPILE_core"

	#
	# Set up build variables
	#
	BUILD_TOS="`$TOOLS_DIR/parse-platforms.py $PLATFORM_CONFIG -p $1 get -o build_tos`"
	case "$BUILD_TOS" in
	debug*)
		export DEBUG=1
		echo "PROFILE=DEBUG"
		;;
	*)
		export DEBUG=0
		echo "PROFILE=RELEASE"
		;;
	esac

	export PLATFORM=$TOS_PLATFORM
	export PLATFORM_FLAVOR=$TOS_PLATFORM_FLAVOR
	echo "PLATFORM=$PLATFORM"
	echo "PLATFORM_FLAVOR=$PLATFORM_FLAVOR"
	echo "CFG_TEE_CORE_LOG_LEVEL=$CFG_TEE_CORE_LOG_LEVEL"

	#
	# Build OP-TEE
	#
	if [ $VERBOSE -eq 1 ]; then
		echo "Calling OP-TEE build:"
	fi
	make ARCH=$TOS_ARCH -j$NUM_THREADS ${PLATFORM_BUILDFLAGS}
	if [ $? -eq 0 ]; then
		#
		# Copy resulting images to UEFI image dir
		#
		TOS_BIN="`$TOOLS_DIR/parse-platforms.py $PLATFORM_CONFIG -p $1 get -o tos_bin`"
		TOS_BIN_EXTRA1="`$TOOLS_DIR/parse-platforms.py $PLATFORM_CONFIG -p $1 get -o tos_bin_extra1`"
		TOS_BIN_EXTRA2="`$TOOLS_DIR/parse-platforms.py $PLATFORM_CONFIG -p $1 get -o tos_bin_extra2`"
		DESTDIR="$EDK2_DIR/Build/$PLATFORM_IMAGE_DIR/$BUILD_PROFILE/FV/"
		COREDIR="out/$TOS_ARCH-plat-$TOS_PLATFORM/core"
		if [ $VERBOSE -eq 1 ]; then
			echo "Copying TOS binaries to '$DESTDIR'"
			CPFLAGS="-v"
		else
			CPFLAGS=""
		fi
		for file in $COREDIR/{"$TOS_BIN","$TOS_BIN_EXTRA1","$TOS_BIN_EXTRA2"}; do
			if [ -f "$file" ]; then
				cp -a $CPFLAGS $file "$DESTDIR"
			fi
		done
	else
		return 1
	fi
}

# Check to see if we are in a trusted OS directory
# refuse to continue if we aren't
if [ ! -f core/tee/tee_svc.c ]
then
	echo "ERROR: we aren't in the optee_os directory."
	usage
	exit 1
fi

build=

if [ $# = 0 ]
then
	usage
	exit 1
else
	while [ "$1" != "" ]; do
		case $1 in
			"-e" )
				shift
				EDK2_DIR="$1"
				;;
			"/h" | "/?" | "-?" | "-h" | "--help" )
				usage
				exit
				;;
			"-t" )
				shift
				BUILD_PROFILE="$1"
				;;
			* )
				build="$1"
				;;
		esac
		shift
	done
fi

if [ X"$build" = X"" ]; then
	echo "No platform specified!" >&2
	echo
	usage
	exit 1
fi

build_platform $build
exit $?
