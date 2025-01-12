#!/usr/bin/env bash

msg(){
    echo
    echo "==> $*"
    echo
}

set_output(){
    echo "$1=$2" >> $GITHUB_OUTPUT
}

bc bison build-essential curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev
lib32readline-gplv2-dev lib32z1-dev libesd0-dev liblz4-tool libncurses5-dev libsdl1.2-dev libwxgtk3.0-dev
libxml2 libxml2-utils lzop pngcrush schedtool squashfs-tools xsltproc zip zlib1g-dev openjdk-8-jdk

mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo

if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

source ~/.profile



echo
echo "--------------------------------------"
echo "    Pixel Experience 13.0 Buildbot    "
echo "                  by                  "
echo "                ponces                "
echo "--------------------------------------"
echo

set -e

BL=$PWD/treble_build_pe
BD=$HOME/builds

initRepos() {
    if [ ! -d .repo ]; then
        echo "--> Initializing workspace"
        repo init -u https://github.com/PixelExperience/manifest -b thirteen
        echo

        echo "--> Preparing local manifest"
        mkdir -p .repo/local_manifests
        cp $BL/manifest.xml .repo/local_manifests/pixel.xml
        echo
    fi
}

syncRepos() {
    echo "--> Syncing repos"
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
    echo
}

applyPatches() {
    echo "--> Applying prerequisite patches"
    bash $BL/apply-patches.sh $BL prerequisite
    echo

    echo "--> Applying TrebleDroid patches"
    cd device/phh/treble
    cp $BL/pe.mk .
    bash generate.sh pe
    cd ../../..
    bash $BL/apply-patches.sh $BL trebledroid
    echo

    echo "--> Applying personal patches"
    bash $BL/apply-patches.sh $BL personal
    echo
}

setupEnv() {
    echo "--> Setting up build environment"
    source build/envsetup.sh &>/dev/null
    mkdir -p $BD
    echo
}

buildTrebleApp() {
    echo "--> Building treble_app"
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ..
    echo
}

buildVariant() {
    echo "--> Building treble_arm64_bvN"
    lunch treble_arm64_bvN-userdebug
    make -j$(nproc --all) installclean
    make -j$(nproc --all) systemimage
    mv $OUT/system.img $BD/system-treble_arm64_bvN.img
    echo
}

buildSlimVariant() {
    echo "--> Building treble_arm64_bvN-slim"
    (cd vendor/gms && git am $BL/patches/slim.patch)
    make -j$(nproc --all) systemimage
    (cd vendor/gms && git reset --hard HEAD~1)
    mv $OUT/system.img $BD/system-treble_arm64_bvN-slim.img
    echo
}

buildVndkliteVariant() {
    echo "--> Building treble_arm64_bvN-vndklite"
    cd sas-creator
    sudo bash lite-adapter.sh 64 $BD/system-treble_arm64_bvN.img
    cp s.img $BD/system-treble_arm64_bvN-vndklite.img
    sudo rm -rf s.img d tmp
    cd ..
    echo
}

generatePackages() {
    echo "--> Generating packages"
    xz -cv $BD/system-treble_arm64_bvN.img -T0 > $BD/PixelExperience_arm64-ab-13.0-$BUILD_DATE-UNOFFICIAL.img.xz
    xz -cv $BD/system-treble_arm64_bvN-vndklite.img -T0 > $BD/PixelExperience_arm64-ab-vndklite-13.0-$BUILD_DATE-UNOFFICIAL.img.xz
    xz -cv $BD/system-treble_arm64_bvN-slim.img -T0 > $BD/PixelExperience_arm64-ab-slim-13.0-$BUILD_DATE-UNOFFICIAL.img.xz
    rm -rf $BD/system-*.img
    echo
}

START=`date +%s`
BUILD_DATE="$(date +%Y%m%d)"

initRepos
syncRepos
applyPatches
setupEnv
buildTrebleApp
buildVariant
buildSlimVariant
buildVndkliteVariant
generatePackages

END=`date +%s`
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo



















set_output outfile $BD/PixelExperience_arm64-ab-vndklite-13.0-$BUILD_DATE-UNOFFICIAL.img.xz

exit 0

msg "Hello world"
