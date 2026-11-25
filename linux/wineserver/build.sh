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

# Where GE-Proton11-14 is: the argument, or the usual places for Steam's
# compatibility tools (native Steam, Flatpak Steam, system packages).
find_ge() {
    local d
    for d in \
        "$HOME/.steam/root/compatibilitytools.d" \
        "$HOME/.steam/steam/compatibilitytools.d" \
        "$HOME/.local/share/Steam/compatibilitytools.d" \
        "$HOME/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d" \
        /usr/share/steam/compatibilitytools.d \
        /usr/local/share/steam/compatibilitytools.d; do
        [ -d "$d" ] || continue
        for g in "$d"/*/; do
            g=${g%/}
            case "$g" in *-viewtree) continue ;; esac
            if [ -x "$g/files/bin/wineserver" ] && grep -qs "$TAG" "$g/version" "$g/compatibilitytool.vdf"; then
                echo "$g"; return
            fi
        done
    done
}
GE=${1:-$(find_ge)}
[ -n "$GE" ] && [ -x "$GE/files/bin/wineserver" ] || {
    echo "could not find $TAG. Pass its folder: bash build.sh /path/to/$TAG"
    exit 1
}
grep -qs "$TAG" "$GE/version" || echo "warning: $GE/version does not say $TAG; the server must match that Proton exactly"
echo "using $GE"

# The copy goes in the user's own compatibility tools folder, beside Steam's.
if [ -z "${OUT:-}" ]; then
    case "$GE" in
        "$HOME"/*) OUT=$(dirname "$GE")/$TAG-viewtree ;;
        *) for d in "$HOME/.steam/root" "$HOME/.local/share/Steam"; do
               [ -d "$d" ] && { OUT=$d/compatibilitytools.d/$TAG-viewtree; break; }
           done ;;
    esac
fi
[ -n "${OUT:-}" ] || { echo "no Steam folder found for the copy; set OUT=/path/to/compatibilitytools.d/$TAG-viewtree"; exit 1; }
mkdir -p "$(dirname "$OUT")"

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
fi
cat > "$OUT/compatibilitytool.vdf" <<VDF
"compatibilitytools"
{
  "compat_tools"
  {
    "$TAG-viewtree"
    {
      "install_path" "."
      "display_name" "$TAG-viewtree"
      "from_oslist"  "windows"
      "to_oslist"    "linux"
    }
  }
}
VDF
[ -f "$OUT/files/bin/wineserver.ge" ] || cp "$OUT/files/bin/wineserver" "$OUT/files/bin/wineserver.ge"
install -m755 ../../wineserver "$OUT/files/bin/wineserver"
echo "done: $OUT (restart Steam, then pick $TAG-viewtree)"
