#!/bin/bash
# Patch KWin to skip min_lum >= max_lum validation in HDR metadata
# Fixes: [destroyed object]: error 5: min_lum can't be higher or equal to max_lum
#
# KWin rejects HDR metadata from games (via Proton Wayland HDR WSI) when
# min_luminance >= max_luminance, killing the Wayland connection and crashing
# the game. This patch NOPs out the validation so KWin accepts the metadata.
#
# Re-run after every KWin update (pacman -S kwin)

set -euo pipefail

LIBKWIN="/usr/lib/libkwin.so"
BACKUP="${LIBKWIN}.bak"
PATCH_OFFSET=""
PATCH_FROM="735f"  # jae (jump if above or equal)
PATCH_TO="9090"    # NOP NOP

# Find the patch location by searching for the exact byte sequence around the error string reference
find_patch_offset() {
    # Search for the pattern: comisd + jae that guards the "min_lum" error
    # The jae instruction (73 xx) follows comisd (%xmm1,%xmm0 = 66 0f 2f c1)
    # and precedes movb $0x1 to mark the field as set
    python3 -c "
import re, struct, sys

with open('${LIBKWIN}', 'rb') as f:
    data = f.read()

# Find the error string offset
errstr = b'min_lum can\x27t be higher or equal to max_lum'
str_offset = data.find(errstr)
if str_offset == -1:
    print('ERROR: error string not found - KWin version may not have this validation', file=sys.stderr)
    sys.exit(1)

# Search for comisd (%xmm1,%xmm0 = 66 0f 2f c1) followed by either:
#   73 xx (jae) = unpatched
#   90 90 (nop nop) = already patched
search_start = max(0, str_offset - 0x200000)
search_end = str_offset
comisd = b'\x66\x0f\x2f\xc1'

candidates = []
pos = search_start
while True:
    idx = data.find(comisd, pos, search_end)
    if idx == -1:
        break
    patch_offset = idx + 4  # offset of the 2 bytes after comisd
    next_bytes = data[patch_offset:patch_offset + 2]

    if next_bytes == b'\x90\x90':
        # Already patched
        candidates.append(patch_offset)
    elif next_bytes[0] == 0x73:
        # jae - check if jump target leads to our error (mov $0x5,%esi)
        jae_target = patch_offset + 2 + next_bytes[1]
        target_area = data[jae_target:jae_target + 30]
        if b'\xbe\x05' in target_area:
            candidates.append(patch_offset)
    pos = idx + 1

if not candidates:
    print('ERROR: patch location not found - KWin binary layout may have changed', file=sys.stderr)
    sys.exit(1)

# Use the last candidate (closest to the string)
offset = candidates[-1]
current = data[offset:offset+2].hex()
print(f'{offset:#x} {current}')
"
}

echo "=== KWin HDR min_lum Patch ==="
echo ""

# Check if already patched
RESULT=$(find_patch_offset)
if [ $? -ne 0 ]; then
    echo "$RESULT"
    exit 1
fi

PATCH_OFFSET=$(echo "$RESULT" | awk '{print $1}')
CURRENT_BYTES=$(echo "$RESULT" | awk '{print $2}')

echo "Location: ${PATCH_OFFSET}"
echo "Current:  ${CURRENT_BYTES}"

if [ "$CURRENT_BYTES" = "$PATCH_TO" ]; then
    echo "Already patched. Nothing to do."
    exit 0
fi

if [ "$CURRENT_BYTES" != "$PATCH_FROM" ]; then
    echo "ERROR: unexpected bytes '${CURRENT_BYTES}' (expected '${PATCH_FROM}')"
    echo "KWin binary layout may have changed. Manual inspection needed."
    exit 1
fi

# Backup
if [ ! -f "$BACKUP" ] || ! cmp -s "$LIBKWIN" "$BACKUP" 2>/dev/null; then
    echo "Backing up to ${BACKUP}"
    sudo cp "$LIBKWIN" "$BACKUP"
fi

# Patch
echo "Patching: ${PATCH_FROM} -> ${PATCH_TO}"
sudo python3 -c "
with open('${LIBKWIN}', 'r+b') as f:
    f.seek(${PATCH_OFFSET})
    old = f.read(2)
    assert old == bytes.fromhex('${PATCH_FROM}'), f'Mismatch: {old.hex()}'
    f.seek(${PATCH_OFFSET})
    f.write(bytes.fromhex('${PATCH_TO}'))
"

echo "Done. Log out and back in to apply."
