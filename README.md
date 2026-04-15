# KDE Wayland HDR Fixes for NVIDIA Laptop GPUs

Workarounds for enabling HDR on KDE Plasma Wayland with NVIDIA laptop (eDP) panels, and fixing game crashes caused by invalid HDR metadata.

## Disclaimer

**Use these scripts at your own risk.** The KWin binary patch modifies a system library (`/usr/lib/libkwin.so`) and makes your compositor non-spec-compliant. Always back up your system before applying. A backup of the original `libkwin.so` is created automatically by the patch script, but you should also have system snapshots (e.g. btrfs/snapper, timeshift) in case something goes wrong. These are unofficial workarounds, not supported by KDE, NVIDIA, or Valve.

## The Problems

### 1. KDE reports "HDR: incapable" on NVIDIA laptops

NVIDIA's DRM driver doesn't expose `max_bpc` on eDP connectors. KWin uses this property to detect HDR capability, so it reports "incapable" even when the panel's EDID confirms full HDR support.

**Fix:** Two undocumented KWin environment variables bypass the check. See [nvidia-laptop-hdr-kde-wayland-fix.md](nvidia-laptop-hdr-kde-wayland-fix.md).

### 2. Games crash when enabling HDR in-game

Games running through Proton send HDR mastering display metadata with invalid luminance values (`min_luminance >= max_luminance`). Mesa's Vulkan WSI filters these out, but NVIDIA's driver passes them through to the Wayland compositor. KWin rejects them per the `wp_color_management_v1` protocol spec, raising `invalid_luminance` and killing the game.

```
[destroyed object]: error 5: min_lum can't be higher or equal to max_lum
```

**Fix:** Binary patch KWin to skip the validation. See [patch-kwin-hdr.sh](patch-kwin-hdr.sh).

## Files

| File | Description |
|------|-------------|
| [patch-kwin-hdr.sh](patch-kwin-hdr.sh) | Binary patches `libkwin.so` to accept invalid HDR luminance metadata |
| [calibrate-hdr.sh](calibrate-hdr.sh) | Calibrates KDE HDR settings to match panel EDID specs |
| [nvidia-laptop-hdr-kde-wayland-fix.md](nvidia-laptop-hdr-kde-wayland-fix.md) | Guide for enabling HDR on NVIDIA laptop eDP panels |

## Quick Start

```bash
# 1. Enable HDR on NVIDIA laptop
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/kwin-hdr.conf << 'EOF'
KWIN_FORCE_ASSUME_HDR_SUPPORT=1
KWIN_DRM_ALLOW_NVIDIA_COLORSPACE=1
EOF
# Log out and back in

# 2. Patch KWin to accept invalid HDR metadata from games
sudo ./patch-kwin-hdr.sh
# Log out and back in

# 3. Launch game with HDR
# Steam launch options:
# PROTON_ENABLE_NVAPI=1 DXVK_ENABLE_NVAPI=1 PROTON_ENABLE_WAYLAND=1 PROTON_ENABLE_HDR=1 ENABLE_HDR_WSI=1 %command%
```

## Upstream Bug Reports

These workarounds are temporary. The proper fixes belong upstream:

- **Proton** (sanitize HDR metadata in Wine Wayland driver): [ValveSoftware/Proton#9672](https://github.com/ValveSoftware/Proton/issues/9672)
- **KDE/KWin** (consider clamping instead of disconnecting): [bugs.kde.org #519000](https://bugs.kde.org/show_bug.cgi?id=519000)

## Tested On

| Component | Version |
|-----------|---------|
| KDE Plasma / KWin | 6.6.4 |
| NVIDIA Driver | 595.58.03 (Open Kernel Module) |
| CPU | Intel Core Ultra 9 275HX |
| GPU | NVIDIA GeForce RTX 5080 Laptop GPU |
| Laptop | Lenovo Legion Pro 7 16IAX10H |
| Panel | Samsung ATNA60HU01-0, 2560x1600@240Hz, 1107 nits peak |
| Proton | proton-cachyos-10.0-20260408-slr |
| Game | Crimson Desert (AppID 3321460) |
| Distro | CachyOS (Arch-based), kernel 7.0.0 |

## License

MIT
