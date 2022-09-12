#!/bin/bash

# set timeout in seconds
TIMEOUT=60

if [ -z $1 ]; then
    echo "usage: $0 <filename of offline bootproject (*.app)> [<artifact 1> <artifact 2>]"
    exit -1
fi

# create temporary working directory
tmpdir=$(mktemp -d)

# just a hacky workaround for bad test-applications, writing to "C:" ;)
mkdir ${tmpdir}/C:

# create config file
appname=$(dirname ${1})/$(basename ${1} .app)
cp ${appname}.app ${tmpdir}/Application.app
cp ${appname}.crc ${tmpdir}/Application.crc

cat > ${tmpdir}/CODESYSControl.cfg <<EOF
[CmpApp]
Application.1=Application

[SysFile]
FilePath.1=/etc/, 3S.dat
EOF

# run codesys control
(
    cd ${tmpdir};
    timeout ${TIMEOUT} /opt/codesys/bin/codesyscontrol.bin CODESYSControl.cfg;
)

# copy artifacts
for i in ${@:2}; do
    mkdir -p $(dirname ".drone-artifacts/$i")
    cp "${tmpdir}/$i" ".drone-artifacts/$i"
done


# remove temporary working directory
[ -d ${tmpdir} ] && rm -rf ${tmpdir}
