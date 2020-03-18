#!/bin/bash

set -xe
shopt -s extglob

env

PPA=ppa:nextcloud-devs/client
PPA_BETA=ppa:nextcloud-devs/client-beta

OBS_PROJECT=home:ivaradi
OBS_PROJECT_BETA=home:ivaradi:beta
OBS_PACKAGE=nextcloud-client

pull_request=${DRONE_PULL_REQUEST:=master}

if test -z "${DRONE_WORKSPACE}"; then
    DRONE_WORKSPACE=`pwd`
fi

if test -z "${DRONE_DIR}"; then
    DRONE_DIR=`dirname ${DRONE_WORKSPACE}`
fi

set +x
if test "$DEBIAN_SECRET_KEY" -a "$DEBIAN_SECRET_IV"; then
    openssl aes-256-cbc -K $DEBIAN_SECRET_KEY -iv $DEBIAN_SECRET_IV -in admin/linux/debian/signing-key.txt.enc -d | gpg --import

    openssl aes-256-cbc -K $DEBIAN_SECRET_KEY -iv $DEBIAN_SECRET_IV -in admin/linux/debian/oscrc.enc -out ~/.oscrc -d

    touch ~/.has_ppa_keys
fi
set -x

cd "${DRONE_WORKSPACE}"
read basever revdate kind <<<$(admin/linux/debian/scripts/git2changelog.py /tmp/tmpchangelog stable)
echo "basever=$basever, revdate=$revdate"

cd "${DRONE_DIR}"

echo "$kind" > kind

if test "$kind" = "alpha"; then
    repo=nextcloud-devs/client-alpha
elif test "$kind" = "beta"; then
    repo=nextcloud-devs/client-beta
else
    repo=nextcloud-devs/client
fi

origsourceopt=""

cp -a ${DRONE_WORKSPACE} nextcloud-desktop_${basever}-${revdate}
tar cjf nextcloud-desktop_${basever}-${revdate}.orig.tar.bz2 --exclude .git nextcloud-desktop_${basever}-${revdate}

cd "${DRONE_WORKSPACE}"
git config --global user.email "abc@def.com"
git config --global user.name "Drone User"

for distribution in eoan; do
    git checkout -- .
    git clean -xdf

    git fetch origin debian/ubuntu/${distribution}/master
    git checkout origin/debian/ubuntu/${distribution}/master

    git merge ${DRONE_COMMIT}

    admin/linux/debian/scripts/git2changelog.py /tmp/tmpchangelog ${distribution} ${revdate}
    cp /tmp/tmpchangelog debian/changelog

    fullver=`head -1 debian/changelog | sed "s:nextcloud-package (\([^)]*\)).*:\1:"`

    echo "============================================================================"
    cat CMakeLists.txt
    echo "============================================================================"
    ls -al
    echo "============================================================================"

    EDITOR=true dpkg-source --commit . local-changes

    dpkg-source --build .
    dpkg-genchanges -S -sa > "../nextcloud-package_${fullver}_source.changes"

    if test -f ~/.has_ppa_keys; then
        debsign -k7D14AA7B -S
    fi
done
cd ..
ls -al

exit 0

if test "${pull_request}" = "master"; then
    kind=`cat kind`

    if test "$kind" = "beta"; then
        PPA=$PPA_BETA
        OBS_PROJECT=$OBS_PROJECT_BETA
    fi

    if test -f ~/.has_ppa_keys; then
        for changes in nextcloud-client_*~+([a-z])1_source.changes; do
            case "${changes}" in
                *oldstable1*)
                    ;;
                *)
                    dput $PPA $changes > /dev/null
                    ;;
            esac
        done

        for distribution in stable oldstable; do
            if test "${distribution}" = "oldstable"; then
                pkgsuffix=".${distribution}"
                pkgvertag="~${distribution}1"
            else
                pkgsuffix=""
                pkgvertag=""
            fi

            package="${OBS_PACKAGE}${pkgsuffix}"
            OBS_SUBDIR="${OBS_PROJECT}/${package}"

            mkdir -p osc
            pushd osc
            osc co ${OBS_PROJECT} ${package}
            if test "$(ls ${OBS_SUBDIR})"; then
                osc delete ${OBS_SUBDIR}/*
            fi

            cp ../nextcloud-client*.orig.tar.* ${OBS_SUBDIR}/
            cp ../nextcloud-client_*[0-9.][0-9]${pkgvertag}.dsc ${OBS_SUBDIR}/
            cp ../nextcloud-client_*[0-9.][0-9]${pkgvertag}.debian.tar* ${OBS_SUBDIR}/
            cp ../nextcloud-client_*[0-9.][0-9]${pkgvertag}_source.changes ${OBS_SUBDIR}/
            osc add ${OBS_SUBDIR}/*

            cd ${OBS_SUBDIR}
            osc commit -m "Travis update"
            popd
        done
    fi
fi
