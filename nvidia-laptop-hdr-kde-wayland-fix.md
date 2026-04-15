# Enabling HDR on KDE Plasma Wayland with NVIDIA Laptop GPUs (eDP)

## The Problem

KDE Plasma (KWin) reports your laptop display as **"HDR: incapable"** even though the panel's EDID confirms full HDR support (HDR Static Metadata, BT.2020, ST 2084/PQ).

This happens because the NVIDIA proprietary DRM/KMS driver does not expose the `max_bpc` property on internal eDP (laptop) panels. KWin uses `max_bpc` as the primary check for HDR capability. Without it, KWin refuses to enable HDR — regardless of what the EDID says or what other DRM properties are available.

You can verify this yourself:

```bash
# Check if your panel actually supports HDR (look for HDR Static Metadata, BT.2020, ST 2084)
edid-decode /sys/class/drm/card*/card*-eDP-*/edid | grep -iE "HDR|BT2020|ST 2084"

# Check what DRM properties NVIDIA exposes on your eDP connector
modetest -c -M nvidia-drm | sed -n '/eDP/,/^[0-9]/p' | grep -P '^\t\d+ \w'
```

You'll likely see `HDR_OUTPUT_METADATA` and `Colorspace` are present, but `max_bpc` is missing.

## The Fix

KWin 6.5+ has two undocumented environment variables that bypass the `max_bpc` check:

```
KWIN_FORCE_ASSUME_HDR_SUPPORT=1
KWIN_DRM_ALLOW_NVIDIA_COLORSPACE=1
```

- `KWIN_FORCE_ASSUME_HDR_SUPPORT` — tells KWin to assume HDR is supported even without `max_bpc`
- `KWIN_DRM_ALLOW_NVIDIA_COLORSPACE` — allows KWin to set the `Colorspace` DRM property on NVIDIA connectors (BT2020_RGB, etc.)

### Step 1: Create the environment file

```bash
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/kwin-hdr.conf << 'EOF'
KWIN_FORCE_ASSUME_HDR_SUPPORT=1
KWIN_DRM_ALLOW_NVIDIA_COLORSPACE=1
EOF
```

The `~/.config/environment.d/` directory is read by systemd at login and the variables are injected into your session before KWin starts.

### Step 2: Log out and back in

KWin reads these at startup. You cannot hot-reload them into a running session — you must log out and log back in (or reboot).

### Step 3: Enable HDR in KDE Settings

After logging back in:

1. Open **System Settings > Display & Monitor**
2. Select your display
3. The **HDR** toggle should now be available — enable it
4. **Wide Color Gamut** should also be available

### Step 4: Verify

```bash
kscreen-doctor -o | grep -E "HDR|Wide Color"
```

You should see:

```
HDR: enabled
Wide Color Gamut: enabled
```

## Tested On

| Component | Version |
|-----------|---------|
| Distro | CachyOS (Arch-based) |
| Kernel | 7.0.0-1-cachyos-gcc |
| KDE Plasma / KWin | 6.6.4 |
| NVIDIA Driver | 595.58.03 (Open Kernel Module) |
| GPU | NVIDIA GeForce RTX 5080 Laptop GPU |
| Panel | Samsung ATNA60HU01-0, 2560x1600@240Hz |
| Panel HDR | HDR Static Metadata, BT.2020, ST 2084/PQ, 1107 nits peak |

## Applies To

- **Any NVIDIA laptop** where the eDP panel supports HDR but KWin reports "incapable"
- **KWin 6.5+** (the env vars were added in the KDE 6.x series)
- **NVIDIA proprietary driver 535+** (must have `HDR_OUTPUT_METADATA` and `Colorspace` DRM properties on the eDP connector — check with `modetest -c -M nvidia-drm`)
- Works with both the proprietary and open kernel modules

## Does NOT Apply To

- External monitors on HDMI/DP — these typically expose `max_bpc` correctly and HDR works without this fix
- AMD/Intel GPUs — their DRM drivers expose `max_bpc` on eDP, so KWin detects HDR natively
- X11 sessions — HDR on KDE requires Wayland

## For Gaming (Proton/Steam)

Once KDE HDR is enabled at the desktop level, games running through Proton can use it. Add the HDR flags to your Steam launch options:

```
PROTON_ENABLE_HDR=1 ENABLE_HDR_WSI=1 %command%
```

Then enable HDR in the game's settings. The Proton HDR pipeline will output to KWin's HDR-enabled compositor.

## How It Was Diagnosed

1. `kscreen-doctor -o` reported "HDR: incapable"
2. `edid-decode` confirmed the panel has full HDR metadata in its EDID
3. `modetest -c -M nvidia-drm` showed `HDR_OUTPUT_METADATA` and `Colorspace` properties exist but `max_bpc` is missing
4. `strings /usr/lib/libkwin.so | grep KWIN_FORCE` revealed the override env vars
5. Setting both env vars and restarting the session resolved the issue

## Reverting

To disable the override and go back to default behavior:

```bash
rm ~/.config/environment.d/kwin-hdr.conf
```

Then log out and back in.
