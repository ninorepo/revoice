#!/usr/bin/env bash

set -euo pipefail

AUDIO="$1"
SUBTITLE="$2"
VIDEO_DIR="$3"
OUTPUT="$4"

# ============================================
# CONFIG
# ============================================

INTERVAL=5                  # seconds
TARGET_W=1080
TARGET_H=1920
FPS=30

# ============================================
# SUBTITLE STYLE CONFIG
# ============================================

FONT_NAME="Montserrat ExtraBold"
FONT_DIR="$global_path/font/Montserrat/static"

FONT_SIZE=15

MARGIN_L=50
MARGIN_R=50
MARGIN_V=50

ALIGNMENT=1
OUTLINE=1
SHADOW=1

PRIMARY_COLOUR="&H00FFFFFF"
OUTLINE_COLOUR="&H00000000"
BACK_COLOUR="&H80000000"

WORKDIR="$(mktemp -d)"
SPLIT_DIR="$WORKDIR/splits"
LIST_FILE="$WORKDIR/list.txt"

mkdir -p "$SPLIT_DIR"

cleanup() {
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

# ============================================
# CHECK DEPENDENCIES
# ============================================

for cmd in ffmpeg ffprobe shuf bc; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Missing dependency: $cmd"
        exit 1
    }
done

# ============================================
# GET AUDIO DURATION
# ============================================

AUDIO_DURATION=$(ffprobe \
    -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$AUDIO")

AUDIO_DURATION=${AUDIO_DURATION%.*}

echo "Audio duration: ${AUDIO_DURATION}s"

# ============================================
# SPLIT VIDEOS
# ============================================

# needed scenes (+3 safety buffer)
NEEDED_SCENES=$(( (AUDIO_DURATION / INTERVAL) + 3 ))

INDEX=0

# load all videos first (for fair distribution)
mapfile -t VIDEO_FILES < <(find "$VIDEO_DIR" -type f)

FILE_COUNT=${#VIDEO_FILES[@]}
FILE_INDEX=0

while [ "$FILE_INDEX" -lt "$FILE_COUNT" ]; do

    VIDEO="${VIDEO_FILES[$FILE_INDEX]}"
    FILE_INDEX=$((FILE_INDEX + 1))

    EXT="${VIDEO##*.}"

    case "${EXT,,}" in
        mp4|mkv|mov|webm|avi)
            ;;
        *)
            continue
            ;;
    esac

    echo "Processing: $VIDEO"

    DURATION=$(ffprobe \
        -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 \
        "$VIDEO")

    DURATION=${DURATION%.*}

    # skip first 5s and last 5s
    EFFECTIVE_START=5
    EFFECTIVE_END=$((DURATION - 5))
    EFFECTIVE_DURATION=$((EFFECTIVE_END - EFFECTIVE_START))

    if [ "$EFFECTIVE_DURATION" -lt "$INTERVAL" ]; then
        echo "Skipped (too short after trim)"
        continue
    fi

    START=$EFFECTIVE_START

    # distribute clips across timeline instead of full consumption
    while [ "$START" -lt "$EFFECTIVE_END" ]; do

        # stop when enough scenes generated
        if [ "$INDEX" -ge "$NEEDED_SCENES" ]; then
            break 2
        fi

        REMAIN=$((EFFECTIVE_END - START))

        if [ "$REMAIN" -lt "$INTERVAL" ]; then
            break
        fi

        OUTFILE="$SPLIT_DIR/clip_$(printf "%06d" "$INDEX").mp4"

        ffmpeg -y -nostdin \
            -ss "$START" \
            -i "$VIDEO" \
            -t "$INTERVAL" \
            -r "$FPS" \
            -an \
            -filter_complex "
                [0:v]scale=${TARGET_W}:${TARGET_H}:force_original_aspect_ratio=increase,boxblur=20:10,crop=${TARGET_W}:${TARGET_H}[bg];
		[0:v]scale=${TARGET_W}:${TARGET_H}:force_original_aspect_ratio=decrease[fg];
		[bg][fg]overlay=(W-w)/2:(H-h)/2[vout]" \
            -map "[vout]" \
            -c:v libx264 \
            -preset veryfast \
            -crf 23 \
            "$OUTFILE"

        INDEX=$((INDEX + 1))
        START=$((START + INTERVAL))

    done

done

# ============================================
# BUILD SHUFFLED CONCAT LIST
# ============================================

TOTAL=0

find "$SPLIT_DIR" -type f | shuf | while read -r FILE; do

    if [ "$TOTAL" -ge "$AUDIO_DURATION" ]; then
        break
    fi

    echo "file '$FILE'" >> "$LIST_FILE"

    TOTAL=$((TOTAL + INTERVAL))

done

# ============================================
# ASS STYLE
# ============================================

ASS_STYLE="\
FontName=${FONT_NAME},\
FontSize=${FONT_SIZE},\
PrimaryColour=${PRIMARY_COLOUR},\
OutlineColour=${OUTLINE_COLOUR},\
BackColour=${BACK_COLOUR},\
BorderStyle=1,\
Outline=${OUTLINE},\
Shadow=${SHADOW},\
Alignment=${ALIGNMENT},\
MarginL=${MARGIN_L},\
MarginR=${MARGIN_R},\
MarginV=${MARGIN_V}"

# ============================================
# CONCAT + AUDIO + SUBTITLE
# ============================================

ffmpeg -y \
    -f concat \
    -safe 0 \
    -i "$LIST_FILE" \
    -i "$AUDIO" \
    -vf "subtitles='${SUBTITLE}':fontsdir='${FONT_DIR}':force_style='${ASS_STYLE}'" \
    -map 0:v \
    -map 1:a \
    -t "$AUDIO_DURATION" \
    -c:v libx264 \
    -preset veryfast \
    -crf 23 \
    -c:a aac \
    -shortest \
    "$OUTPUT"

echo ""
echo "Done:"
echo "$OUTPUT"

