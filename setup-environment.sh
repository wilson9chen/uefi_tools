#!/bin/bash

CONFIGDIR=~/.tianocore
SRCDIR=`dirname $0`

FORCE=false
NUMWARNINGS=0

SCRIPTNAME=`basename $0`

printusage()
{
    echo "$SCRIPTNAME - initialize and verifyTianoCore development environment"
    echo "Verifies git configuration, installs git hooks, etc."
    echo "To be executed from one of your cloned git directories"
    echo
    echo "usage: $SCRIPTNAME [-f]"
    echo
    echo "  -f  Force sucessful completion for non-typical situations"
}

while [ $# -ge 1 ]; do
    case $1 in
	-f)
	    FORCE=true
	    ;;
	*)
	    echo "Unknown parameter '$1' - aborting"
	    echo
	    printusage
	    exit 1
	    ;;
    esac

    shift
done

checkrepo()
{
    if [ ! -d .git ]; then
	echo "$PWD is not a git repository" >&2
	exit 1
    fi

    ORIGINPATTERN=".*://github.com/tianocore/.*"
    if [ -z `git remote get-url origin | grep -i "$ORIGINPATTERN"` ]; then
	echo
	echo "origin is not github.com/tianocore/ - is this intentional?"
	if [ $FORCE == "true" ]; then
	    return
	fi
	echo "Aborting - Override with -f to force."
    echo
    fi
}

checkgitconfig()
{
    checkrepo

    GITUSER=`git config user.name`
    GITEMAIL=`git config user.email`
    if [ -z "$GITUSER" -o -z "$GITEMAIL" ]; then
	echo "git user and/or email not configured"
	echo "please run"
	echo "  git config --global user.name=<your name as displayed in email clients>"
	echo "  git config --global user.email=<your email address>"
	echo "(omit the '--global' if using different name/email for other development)"
	exit 1
    fi

    git config sendemail.smtpserver >/dev/null
    if [ $? -ne 0 ]; then
	echo "WARNING: no SMTP server configured, git send-email will not work!"
	NUMWARNINGS=$(($NUMWARNINGS + 1))
    fi
}

# checkmakedir <directory>
checkmakedir()
{
    if [ ! -d "$1" ]; then
	echo "Creating $1"
	mkdir "$1"
    fi
}

# checkcopyfile <source file> <destination file>
checkcopyfile()
{
    if [ -e $2 ]; then
	if cmp -s "$1" "$2"; then
	    echo "  Not overwriting existing identical file '$2'"
	    return
	else
	    echo "  Updating '$2'"
	fi
    fi

    if [ $FORCE == "true" ]; then
	COPYFLAGS=
    else
	COPYFLAGS=-i
    fi
    cp -p $COPYFLAGS "$1" "$2"
}

copyfiles()
{
    echo "Installing GIT hooks:"
    for file in $SRCDIR/git-hooks/*; do
	checkcopyfile $file .git/hooks/`basename $file`
    done
    echo "done."

    echo

    checkmakedir "$CONFIGDIR"
    echo "Installing TianoCore templates and configuration:"
    for file in $SRCDIR/git-config/*; do
	checkcopyfile $file $CONFIGDIR/`basename $file`
    done
    echo "done."
}

configuregit()
{
    GITTEMPLATE=`git config commit.template`
    if [ -z $GITTEMPLATE ]; then
	git config --add commit.template $CONFIGDIR/git.template
    elif [ $GITTEMPLATE != $CONFIGDIR/git.template ]; then
	echo "WARNING: commit.template already configured in other location than '$GITTEMPLATE'"
	NUMWARNINGS=$(($NUMWARNINGS + 1))
    fi

    ORDERFILE=`git config diff.orderfile`
    if [ -z $ORDERFILE ]; then
	git config --add diff.orderfile $CONFIGDIR/sort.order
    elif [ $ORDERFILE !=  $CONFIGDIR/sort.order ]; then
	echo "WARNING: diff.orderfile already configured in other location than '$ORDERFILE'"
	NUMWARNINGS=$(($NUMWARNINGS + 1))
    fi
}

checkgitconfig
copyfiles
configuregit

echo
echo "Successfully installed/updated configuration!"
if [ $NUMWARNINGS -gt 0 ]; then
    echo "(with $NUMWARNINGS warnings)"
fi
