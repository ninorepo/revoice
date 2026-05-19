#!/bin/bash

# ========================
# USAGE:
# ./burn_subs.sh input.mp4 input.srt font.ttf output.mp4
# ========================

INPUT_VIDEO="$1"
INPUT_SRT="$2"
OUTPUT_VIDEO="$3"
FONT="$global_path/font/Montserrat/static/Montserrat-ExtraBold.ttf"


# ========================
# VALIDATION
# ========================
if [ -z "$INPUT_VIDEO" ] || [ -z "$INPUT_SRT" ] || [ -z "$FONT" ] || [ -z "$OUTPUT_VIDEO" ]; then
    echo "Usage: $0 input.mp4 input.srt font.ttf output.mp4"
    exit 1
fi

# ========================
# SUBTITLE STYLE
# ========================
SUBSTYLE="Fontsize=17,\
PrimaryColour=&HFFFFFF&,\
OutlineColour=&H000000&,\
BorderStyle=1,\
Outline=1,\
Shadow=1,\
Alignment=2,\
MarginV=50"

# If font exists use it
if [ -f "$FONT" ]; then
    SUBSTYLE="$SUBSTYLE,FontFile=$FONT"
else
    echo "Font not found: $FONT"
    exit 1
fi

# ========================
# BURN SUBTITLES
# ========================
ffmpeg -y \
  -i "$INPUT_VIDEO" \
  -vf "subtitles=$INPUT_SRT:force_style='$SUBSTYLE'" \
  -c:v libx264 \
  -preset ultrafast \
  -crf 23 \
  -pix_fmt yuv420p \
  -c:a copy \
  "$OUTPUT_VIDEO"

echo "DONE -> $OUTPUT_VIDEO"

