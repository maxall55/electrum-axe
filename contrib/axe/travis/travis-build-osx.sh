#!/bin/bash
set -ev

if [[ -z $TRAVIS_TAG ]]; then
  echo TRAVIS_TAG unset, exiting
  exit 1
fi

BUILD_REPO_URL=https://github.com/axerunners/electrum-axe.git

cd build

git clone --branch $TRAVIS_TAG $BUILD_REPO_URL electrum-axe

cd electrum-axe

export PY36BINDIR=/Library/Frameworks/Python.framework/Versions/3.6/bin/
export PATH=$PATH:$PY36BINDIR
source ./contrib/axe/travis/electrum_axe_version_env.sh;
echo osx build version is $AXE_ELECTRUM_VERSION


git submodule init
git submodule update

info "Building CalinsQRReader..."
d=contrib/CalinsQRReader
pushd $d
rm -fr build
xcodebuild || fail "Could not build CalinsQRReader"
popd

sudo pip3 install -r contrib/deterministic-build/requirements.txt
sudo pip3 install -r contrib/deterministic-build/requirements-hw.txt
sudo pip3 install -r contrib/deterministic-build/requirements-binaries.txt
sudo pip3 install x11_hash>=1.4
sudo pip3 install PyInstaller==3.4 --no-use-pep517

export PATH="/usr/local/opt/gettext/bin:$PATH"
./contrib/make_locale
find . -name '*.po' -delete
find . -name '*.pot' -delete

cp contrib/axe/osx.spec .
cp contrib/axe/pyi_runtimehook.py .
cp contrib/axe/pyi_tctl_runtimehook.py .

pyinstaller \
    -y \
    --name electrum-axe-$AXE_ELECTRUM_VERSION.bin \
    osx.spec

info "Adding Axe URI types to Info.plist"
plutil -insert 'CFBundleURLTypes' \
   -xml '<array><dict> <key>CFBundleURLName</key> <string>axe</string> <key>CFBundleURLSchemes</key> <array><string>axe</string></array> </dict></array>' \
   -- dist/Axe\ Electrum.app/Contents/Info.plist \
   || fail "Could not add keys to Info.plist. Make sure the program 'plutil' exists and is installed."

sudo hdiutil create -fs HFS+ -volname "Axe Electrum" \
    -srcfolder dist/Axe\ Electrum.app \
    dist/Axe-Electrum-$AXE_ELECTRUM_VERSION-macosx.dmg
