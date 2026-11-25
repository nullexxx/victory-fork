#!/usr/bin/env bash
# Builds GE-Proton11-14's wineserver with view-tree.patch, from GE's own Wine
# source with GE's own patches, and puts it in a copy of the GE-Proton folder.
#
#   bash build.sh [path to GE-Proton11-14]
#
# Needs: git base-devel autoconf flex bison perl python bluez-libs (Arch names).
set -euo pipefail

TAG=GE-Proton11-14
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${WORK:-$HOME/.cache/wineserver-view-tree}
GE=${1:-$HOME/.steam/root/compatibilitytools.d/$TAG}
OUT=${OUT:-$HOME/.steam/root/compatibilitytools.d/$TAG-viewtree}

[ -x "$GE/files/bin/wineserver" ] || { echo "no $GE/files/bin/wineserver: pass the GE-Proton folder"; exit 1; }

mkdir -p "$WORK" && cd "$WORK"
if [ ! -d pge ]; then
    git clone --depth 1 --branch "$TAG" https://github.com/GloriousEggroll/proton-ge-custom pge
fi
cd pge
# Only Wine and wine-staging are needed for the server. Wine needs history:
# GE's script reverts a commit.
git submodule update --init --filter=blob:none wine wine-staging

# The Wine part of GE's own patch script (section 2), unchanged.
script=patches/protonprep-valve-staging.sh
start=$(grep -n '^### (2) WINE PATCHING ###' "$script" | cut -d: -f1)
end=$(grep -n '^### END WINE PATCHING ###' "$script" | cut -d: -f1)
{ sed -n 1,15p "$script"; sed -n "${start},${end}p" "$script"; } > ../wineprep.sh
bash ../wineprep.sh > ../wineprep.log 2>&1
if grep -qi 'hunk.*failed' ../wineprep.log; then echo "GE's patches did not apply, see $WORK/wineprep.log"; exit 1; fi

cd wine
patch -Np1 < "$HERE/view-tree.patch"

# configure only to get config.h; the full Makefile needs generated Vulkan
# files the server does not use, so configure's last step may fail.
./configure --enable-win64 --without-x --without-freetype --disable-tests --without-mingw \
    --without-wayland --without-vulkan > ../../configure.log 2>&1 || true
[ -f include/config.h ] || { echo "configure failed, see $WORK/configure.log"; exit 1; }

rm -rf ../../obj && mkdir ../../obj
for f in $(sed -n '/^SOURCES/,/^$/p' server/Makefile.in | grep -o '[a-z_0-9]*\.c'); do
    gcc -c -O2 -fno-strict-aliasing -Wall -Wno-unused-result -D__WINESRC__ -D_REENTRANT \
        -Iinclude -Iserver '-DBINDIR="/usr/bin"' '-DDATADIR="/usr/share"' \
        "server/$f" -o "../../obj/${f%.c}.o"
done
gcc -o ../../wineserver ../../obj/*.o -lm
strip ../../wineserver

if [ ! -d "$OUT" ]; then
    cp -a "$GE" "$OUT"
    sed -i "s/\"$TAG\"/\"$TAG-viewtree\"/g" "$OUT/compatibilitytool.vdf"
fi
[ -f "$OUT/files/bin/wineserver.ge" ] || cp "$OUT/files/bin/wineserver" "$OUT/files/bin/wineserver.ge"
install -m755 ../../wineserver "$OUT/files/bin/wineserver"
echo "done: $OUT (restart Steam, then pick $TAG-viewtree)"
