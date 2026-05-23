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

for cmd in ffmpeg ffprobe bc; do
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
# INITIALIZE VIDEO FILES & TRACKERS
# ============================================

# Load valid video files into an array
mapfile -t ALL_FILES < <(find "$VIDEO_DIR" -type f)
VIDEO_FILES=()

for FILE in "${ALL_FILES[@]}"; do
    EXT="${FILE##*.}"
    case "${EXT,,}" in
        mp4|mkv|mov|webm|avi)
            VIDEO_FILES+=("$FILE")
            ;;
    esac
done

FILE_COUNT=${#VIDEO_FILES[@]}

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No valid video files found in $VIDEO_DIR"
    exit 1
fi

# Track current read time pointer for each video index
declare -a VIDEO_TIMESTAMPS
for ((i=0; i<FILE_COUNT; i++)); do
    VIDEO_TIMESTAMPS[$i]=5
done

# Calculate exact number of clips needed to cover audio
NEEDED_CLIPS=$(( (AUDIO_DURATION + (INTERVAL + 3) ) / INTERVAL ))
INDEX=0

# ============================================
# ROUND-ROBIN CLIP GENERATION & LIST BUILDING
# ============================================

while [ "$INDEX" -lt "$NEEDED_CLIPS" ]; do
    
    CLIP_ADDED_THIS_CYCLE=false

    for ((i=0; i<FILE_COUNT; i++)); do
        
        # Stop immediately if we reached our target clip count
        if [ "$INDEX" -ge "$NEEDED_CLIPS" ]; then
            break 2
        fi

        VIDEO="${VIDEO_FILES[$i]}"
        START="${VIDEO_TIMESTAMPS[$i]}"

        # Skip this specific video on this pass if it was marked exhausted
        if [ "$START" -eq -1 ]; then
            continue
        fi

        # Get total video duration
        DURATION=$(ffprobe \
            -v error \
            -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 \
            "$VIDEO")
        DURATION=${DURATION%.*}

        EFFECTIVE_END=$((DURATION - 5))
        REMAIN=$((EFFECTIVE_END - START))

        # Mark video as exhausted if there isn't enough time left
        if [ "$REMAIN" -lt "$INTERVAL" ]; then
            VIDEO_TIMESTAMPS[$i]=-1
            continue
        fi

        echo "Round Robin - Pulling clip from: $VIDEO (at ${START}s)"

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

        # Record file into sequential list
        echo "file '$OUTFILE'" >> "$LIST_FILE"
        
        # Advance pointers
        VIDEO_TIMESTAMPS[$i]=$((START + INTERVAL))
        INDEX=$((INDEX + 1))
        CLIP_ADDED_THIS_CYCLE=true

    done

    # RESET LOGIC: If a full pass yielded 0 clips, all videos are exhausted.
    # Reset timestamps to 5 seconds and repeat the loop.
    if [ "$CLIP_ADDED_THIS_CYCLE" = false ]; then
        echo "--- All video footage exhausted. Resetting timelines to start over ---"
        for ((i=0; i<FILE_COUNT; i++)); do
            VIDEO_TIMESTAMPS[$i]=5
        done
    fi
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

