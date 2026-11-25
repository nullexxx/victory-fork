#!/usr/bin/env bash
# Launch wrapper for AnyXboxX's VIctory copy (Neptune base) under Proton.
# Steam launch options:  /path/to/neptune-env.sh %command% run "<game exe>" --execute
# Sets the switch set of AnyXboxX's tools/lancer_victory.ps1 (Neptune
# 2026-11-25c, Series X path, 16 GB card), plus what Proton needs, then runs
# the rest of the line. Set GAME_DIR to the game folder as Wine sees it.

: "${GAME_DIR:?set GAME_DIR to the game folder as Wine sees it, e.g. Z:\\games\\title}"

export VICTORY_GAME_DIR="$GAME_DIR"
export VICTORY_DISCORD=0

# AnyXboxX's launcher values
export VICTORY_CARD_WINDOWS_MB=4096
export VICTORY_BAKE_TEXTURES_MS=10000
export VICTORY_EARLY_TEXTURES_MS=40
export VICTORY_WIDE_MERGE=1
export VICTORY_RELAY_OWN_QUEUE=1
export VICTORY_UNDER_WRITES_WORDS=1
export VICTORY_UNDER_WRITES_RUNS=100000
export VICTORY_UNDER_WRITES_MASKS=1
export VICTORY_RELAY=2
export VICTORY_WIDE_REFRESH=1
export VICTORY_ASK_ONCE=1
export VICTORY_TEXTURE_NO_WAIT=1
export VICTORY_CARD_REHASH_RUNS=1
export VICTORY_JOIN_COPIES=1
export VICTORY_D3D12_BACKGROUND=0
export VICTORY_LATE_WAIT_LISTS=1024
export VICTORY_WINDOW_TAILS=1
export VICTORY_TEXTURE_STAGE_MB=512
export VICTORY_CARD_BUFFERS_MIN_KB=64
export VICTORY_ASK_QUIET=8
export VICTORY_COPY_CHANGED=1
export VICTORY_QUIET_BACK=1
export VICTORY_LIST_POOL_MOST=2048
export VICTORY_LIST_POOL_MB=2048
export VICTORY_WIDE_THREADS=12
export VICTORY_UNDER_WRITES_MASKS_LEAST=1
export VICTORY_INDIRECT_RAW=2
export VICTORY_TEXTURE_HASH_EVERY=32
export VICTORY_LEVELS_ON_DEMAND=1
export VICTORY_WINDOW_KB=1024
export VICTORY_CARD_BUFFERS_MB=1536
export VICTORY_CARD_WINDOW_UPLOAD=1
export VICTORY_DROP_DXIL=1
export VICTORY_DESC_DATA=1
export VICTORY_VRAM_IDLE_MS=15000,2500,1000
export VICTORY_PIPELINE_WAIT_MS=2500

# Proton (NVIDIA: NV_CACHE=<dir> for the driver's shader cache)
export WINEDLLOVERRIDES="d3dcompiler_47=n"
export VKD3D_CONFIG=no_upload_hvv
[ -n "${NV_CACHE:-}" ] && export __GL_SHADER_DISK_CACHE_PATH="$NV_CACHE"
export __GL_SHADER_DISK_CACHE_SIZE=10737418240
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
export PROTON_ENABLE_WAYLAND=1

exec "$@"
