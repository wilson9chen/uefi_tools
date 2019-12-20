#!/bin/sh
#
# Copyright (c) 2018, Linaro Ltd. All rights reserved.
#
# SPDX-License-Identifier: ISC
#

TOOLS_DIR="`dirname $0`"
TOOLS_DIR="`readlink -f \"$TOOLS_DIR\"`"

REPO_DIR=../edk2-platforms
GIT="git -C $REPO_DIR"

START_HASH=`$GIT rev-parse HEAD`
STOP_HASH=`$GIT rev-parse origin/master`

$GIT merge-base --is-ancestor $STOP_HASH $START_HASH 2>/dev/null
if [ $? -eq 0 ]; then
    echo "$STOP_HASH is an ancestor - proceeding."
else
    echo "$STOP_HASH is not an ancestor - aborting!" >&2
    exit 1
fi

PLATFORMS=$*

echo $PLATFORMS

while [ `$GIT rev-parse HEAD` != $STOP_HASH ]; do
    $TOOLS_DIR/edk2-build.sh --strict -e ../edk2 -p ../edk2-platforms -n ../edk2-non-osi -b DEBUG -b RELEASE $PLATFORMS
    if [ $? -ne 0 ]; then
	echo "`$GIT rev-parse HEAD` failed to build" >&2
	exit 2
    fi
    $GIT reset --hard HEAD^
done

echo "SUCCESS: all commits from"
echo "  $START_HASH to"
echo "  $STOP_HASH"
echo "built successfully for $PLATFORMS!"
