#!/bin/bash
# HDR Calibration for Samsung ATNA60HU01-0 (Legion Pro 7 16IAX10H)
# Re-run after KWin/KDE updates that may reset HDR settings
#
# Panel specs (from EDID):
#   Peak brightness (10% window): 1107 nits
#   Full-screen sustained:        500 nits
#   Min luminance:                 0.001 nits
#   Color gamut:                   DCI-P3 / BT.2020
#   SDR max suggested:             500 nits

set -euo pipefail

# Enable HDR + Wide Color Gamut
kscreen-doctor output.eDP-1.hdr.enable output.eDP-1.wcg.enable

# Calibrate to panel's actual capabilities
kscreen-doctor output.eDP-1.maxBrightnessOverride.1100
kscreen-doctor output.eDP-1.maxAverageBrightnessOverride.500
kscreen-doctor output.eDP-1.minBrightnessOverride.0
kscreen-doctor output.eDP-1.sdr-brightness.300
kscreen-doctor output.eDP-1.sdrGamut.0

echo "HDR calibrated:"
kscreen-doctor -o | grep -E "HDR|Wide Color|SDR|Peak|brightness|gamut|Min"
