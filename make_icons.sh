#!/bin/bash
# Generates the Anti SleepIn channel artwork (Apple-style squircle icon)
# at all the sizes Roku's manifest references. Requires rsvg-convert.
set -e
cd "$(dirname "$0")"
mkdir -p images

# emit_svg WIDTH HEIGHT SQUIRCLE_RATIO  -> prints an SVG to stdout
emit_svg() {
  local W=$1 H=$2 RATIO=$3
  # squircle is a centered square sized to a fraction of the height
  local S X Y R
  S=$(awk "BEGIN{printf \"%.2f\", $H*$RATIO}")
  X=$(awk "BEGIN{printf \"%.2f\", ($W-$S)/2}")
  Y=$(awk "BEGIN{printf \"%.2f\", ($H-$S)/2}")
  R=$(awk "BEGIN{printf \"%.2f\", $S*0.225}")
  local SCALE
  SCALE=$(awk "BEGIN{printf \"%.5f\", $S/240.0}")

cat <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#121728"/>
      <stop offset="1" stop-color="#05070E"/>
    </linearGradient>
    <linearGradient id="sq" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0"   stop-color="#5BB0FF"/>
      <stop offset="0.5" stop-color="#1E79F0"/>
      <stop offset="1"   stop-color="#0A47C4"/>
    </linearGradient>
    <linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0"    stop-color="#ffffff" stop-opacity="0.45"/>
      <stop offset="0.45" stop-color="#ffffff" stop-opacity="0.08"/>
      <stop offset="0.5"  stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="ring" cx="0.5" cy="0.38" r="0.7">
      <stop offset="0" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#DCE7F5"/>
    </radialGradient>
  </defs>

  <rect width="$W" height="$H" fill="url(#bg)"/>

  <!-- squircle -->
  <rect x="$X" y="$Y" width="$S" height="$S" rx="$R" ry="$R" fill="url(#sq)"/>
  <rect x="$X" y="$Y" width="$S" height="$S" rx="$R" ry="$R" fill="url(#gloss)"/>

  <!-- alarm clock + label, drawn in a 240x240 space then scaled -->
  <g transform="translate($X,$Y) scale($SCALE)">
    <!-- legs -->
    <line x1="80" y1="150" x2="62" y2="184" stroke="#ffffff" stroke-width="13" stroke-linecap="round"/>
    <line x1="160" y1="150" x2="178" y2="184" stroke="#ffffff" stroke-width="13" stroke-linecap="round"/>
    <!-- bells -->
    <circle cx="84"  cy="44" r="19" fill="#ffffff"/>
    <circle cx="156" cy="44" r="19" fill="#ffffff"/>
    <rect x="112" y="22" width="16" height="16" rx="6" fill="#ffffff"/>
    <!-- clock body -->
    <circle cx="120" cy="104" r="62" fill="#ffffff"/>
    <circle cx="120" cy="104" r="54" fill="url(#ring)"/>
    <circle cx="120" cy="104" r="46" fill="#F5F9FF"/>
    <!-- hands -->
    <line x1="120" y1="104" x2="120" y2="66"  stroke="#0C1C36" stroke-width="7" stroke-linecap="round"/>
    <line x1="120" y1="104" x2="150" y2="116" stroke="#0C1C36" stroke-width="7" stroke-linecap="round"/>
    <circle cx="120" cy="104" r="6" fill="#0C1C36"/>
    <!-- label -->
    <text x="120" y="214" text-anchor="middle" textLength="196" lengthAdjust="spacingAndGlyphs"
          font-family="Helvetica, Arial, sans-serif" font-weight="700" font-size="30"
          fill="#ffffff">Anti SleepIn</text>
  </g>
</svg>
SVG
}

render() { # W H RATIO OUT
  emit_svg "$1" "$2" "$3" > /tmp/_antisleepin.svg
  rsvg-convert -w "$1" -h "$2" /tmp/_antisleepin.svg -o "images/$4"
  echo "wrote images/$4 (${1}x${2})"
}

render 290  218  0.90 icon_focus_hd.png
render 246  140  0.95 icon_focus_sd.png
render 1280 720  0.55 splash_hd.png
render 1920 1080 0.55 splash_fhd.png

rm -f /tmp/_antisleepin.svg
echo "done."
