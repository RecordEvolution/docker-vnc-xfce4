#!/bin/bash

WINE=wine

if [ -d /usr/local/share/codesys ]; then
    BASEPATH=/usr/local/share/codesys
else
    BASEPATH=$(dirname ${0})/scripts
fi

# get first CODESYS profile and start the script with it
profile=$(basename "$(ls -1 ~/.wine.cds/drive_c/CODESYS/CODESYS/Profiles/*.profile* | head -n 1 | sed 's,\.profile.*,,')")
libdoc=$(ls -1 ${HOME}/.wine.cds/drive_c/CODESYS/CODESYS/DocScripting/*/libdoc.exe)

# start ide?
if [ "${1}" == "ide" ]; then
    export WINEPREFIX=~/.wine.cds
#    export WINEDEBUG=-all
    ${WINE} ~/.wine.cds/drive_c/CODESYS/CODESYS/Common/CODESYS.exe --culture=en --profile="'"${profile}"'" --runscript="z:${BASEPATH}/noop.py" --noUI 
    ${WINE} ~/.wine.cds/drive_c/CODESYS/CODESYS/Common/CODESYS.exe --culture=en --profile="'"${profile}"'"
elif [ "${1}" == "export-libdoc" ]; then
    export WINEPREFIX=~/.wine.cds
    export WINEDEBUG=-all
    export LIBDOC_CODESYS="c:/CODESYS/CODESYS/Common/CODESYS.exe --profile=\"${profile}\""

    for i in $(find -iname \*.library); do
	${WINE}  ${libdoc} make ${i} html
	libbase=$(basename $i .library)
	libdir=$(dirname $i)
	if [ -d ${libdir}/${libbase}-html ]; then
	    mkdir -p .drone-artifacts/${libdir}
	    zip -r .drone-artifacts/${libdir}/${libbase}.zip ${libdir}/${libbase}-html
	fi
    done
elif [ "${1}" == "export-libdoc-pdf" ]; then
    export WINEPREFIX=~/.wine.cds
    export WINEDEBUG=-all
    export LIBDOC_CODESYS="c:/CODESYS/CODESYS/Common/CODESYS.exe --profile=\"${profile}\""

    for i in $(find -iname \*.library); do
	${WINE}  ${libdoc} make ${i} chm
	libbase=$(basename $i .library)
	libdir=$(dirname $i)
	if [ -f ${libdir}/${libbase}.pdf ]; then
	    mkdir -p .drone-artifacts/${libdir}
	    cp ${libdir}/${libbase}.pdf .drone-artifacts/${libdir}/${libbase}.pdf
	fi
    done
elif [ "${1}" == "install" ]; then
    # check if file exists, before we call PackageManager with it
    url=${2}
    filename=${url}
    tmpfile=$(mktemp --suffix=.package)
    if [ "${url%:*}" == "https" ]; then
	filename=${tmpfile}
	wget --output-document=${filename} "${url}"
    elif [ ! -f ${filename} ]; then
	echo "error: package '${filename}' not found."
	exit -1
    fi
    export DISPLAY=:91
    Xvfb :91 &> /dev/zero &
    sleep 1
    export WINEPREFIX=~/.wine.cds
    ${WINE} ~/.wine.cds/drive_c/CODESYS/CODESYS/Common/PackageManagerCLI.exe --culture=en --profile="'"${profile}"'" --components="typical" --verbose --install="${filename}"

    result=$?

    rm ${tmpfile}
    
    sleep 1
    killall Xvfb
    rm -rf /tmp/.X91*
    
    if [ "${result}" == "0" ]; then
	true
    else
	false
    fi
else
    # check if file exists, before we call CODESYS with it
    if [ ! -f ${BASEPATH}/${1}.py ]; then
	echo "error: script '${BASEPATH}/${1}.py' not found."
	exit -1
    fi
    
    export DISPLAY=:91
    Xvfb :91 &> /dev/zero &
    sleep 1
    export WINEPREFIX=~/.wine.cds
    ${WINE} ~/.wine.cds/drive_c/CODESYS/CODESYS/Common/CODESYS.exe --culture=en --profile="'"${profile}"'" --runscript="z:${BASEPATH}/noop.py" --noUI 2> /dev/zero
    # remove output log
    [ -f .codesys.output.txt ] && rm -f .codesys.output.txt
    # check if script runs with or without UI
    if grep '# CODESYS with UI' "${BASEPATH}/${1}.py" 2>&1 > /dev/zero; then
	${WINE} ~/.wine.cds/drive_c/CODESYS/CODESYS/Common/CODESYS.exe --culture=en --profile="'"${profile}"'" --runscript="z:${BASEPATH}/${1}.py" 2> /dev/zero
    else
	${WINE} ~/.wine.cds/drive_c/CODESYS/CODESYS/Common/CODESYS.exe --culture=en --profile="'"${profile}"'" --runscript="z:${BASEPATH}/${1}.py" --noUI 2> /dev/zero
    fi
    result=$?

    # flush output log
    [ -f .codesys.output.txt ] && cat .codesys.output.txt
     sleep 1
    killall Xvfb
    rm -rf /tmp/.X91*
    
    if [ "${result}" == "0" ]; then
	true
    else
	false
    fi
fi
