#!/bin/bash
################################################################################
# Copyright 2017 Ingo Hornberger <ingo_@gmx.net>
#
# This software is licensed under the MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be included in all copies
# or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
# OR OTHER DEALINGS IN THE SOFTWARE.
#
################################################################################

WINE=wine
WINESERVER=wineserver
CDS_LINK="https://store.codesys.com/ftp_download/3S/CODESYS/300000/3.5.16.0/CODESYS%203.5.16.0.exe"
TRICKS_LINK="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
ADDITIONAL_PACKAGES=https://forge.codesys.com/svn/tol,cforge,code/trunk/cforge.package
export WINEPREFIX=~/.wine.cds
export WINEARCH=win32

# kill current and subprocesses on exit
trap "kill 0" EXIT

function get
{
    wget --no-verbose --output-document=setup.exe -c "${CDS_LINK}"
    wget --no-verbose --output-document=winetricks -c "${TRICKS_LINK}" 
    chmod 755 winetricks 
    (
	mkdir -p Packages
	cd Packages
	for i in ${ADDITIONAL_PACKAGES}; do
		wget --no-verbose -c "${i}" 
	done
    )
}

function prereq
{
    echo -n "Checking prerequisite '${WINE}'"
    if which ${WINE}; then
	echo "=> OK"
    else
	echo "ERROR: Please install wine32 and wine64"
	exit 1
    fi
    echo -n "Checking prerequisite 'msiextract'"
    if which msiextract; then
	echo "=> OK"
    else
	echo "ERROR: Please install msitools"
	exit 1
    fi
}

function switch_to_win7
{
    # call wine to create new WINEPREFIX
    ${WINE} dir
    sleep 5
    # patch win version
    cp system.reg ${WINEPREFIX}
}

function winetricks
{
    ./winetricks nocrashdialog
    ${WINESERVER} -w
    ./winetricks dotnet46
    ${WINESERVER} -w
}

function winetricks_silent
{
    ./winetricks nocrashdialog
    ${WINESERVER} -w
    ./winetricks -q dotnet46
    ${WINESERVER} -w
}

function install
{
    WINEPREFIX=~/.wine.cds wine ./setup.exe /s /x /b"C:\tmp" /v"/qn"
    (
	${WINESERVER} -w
	cd ~/.wine.cds/drive_c/tmp
	msiextract *.msi
	mv Program*/CODESYS* ../CODESYS
	mv CommonAppData/CODESYS/* ../CODESYS/CODESYS/
    )
}

function post_install
{
    ${WINE} reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\ProfileList\\S-1-5-21-0-0-0-1000"
    ${WINESERVER} -w
}

no_check="y"
no_dl="y"
no_winetricks="y"
no_install="y"
no_postinstall="y"
no_xvfb="y"
case ${1} in
    --winetricks)
	no_winetricks=""
	;;
    --install)
	no_install=""
	;;
    --postinstall)
	no_postinstall=""
	;;
    --silent)
	no_check=""
	no_dl=""
	no_winetricks=""
	no_install=""
	no_postinstall=""
	no_xvfb=""
	;;
    -h)
	echo "usage: $0 <param>"
	echo "params:"
	echo "    --winetricks"
	echo "    --install"
	echo "    --postinstall"
	;;
    *)
	no_check=""
	no_dl=""
	no_winetricks=""
	no_install=""
	no_postinstall=""
	no_xvfb=""
	;;
esac

if [ -z ${no_xvfb} ]; then
    echo "=== Start XVFB ==="
    export DISPLAY=:98
    Xvfb :98 &
    sleep 3
    jwm &
fi
if [ -z ${no_check} ]; then
    echo "=== Checking Prerequisites ==="
    prereq
fi
if [ -z ${no_dl} ]; then
    echo "=== Downloading packets ==="
    get
fi
if [ -z ${no_winetricks} ]; then
    echo "=== Installing Prerequisites w/ winetricks ==="
    if [ -z ${no_xvfb} ]; then
	winetricks_silent
    else
	winetricks
    fi
fi
if [ -z ${no_install} ]; then
    echo "=== Installing CODESYS ==="
    install
fi
if [ -z ${no_postinstall} ]; then
    echo "=== Postinstall Fixups ==="
    post_install
fi
if [ -z ${no_xvfb} ]; then
    echo "=== Kill XVFB ==="
    # killall -9 Xvfb
fi

exit
