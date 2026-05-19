#!/bin/bash

VIDEO="$project_path/original.mp4"
AUDIO="$project_path/scene.wav"
SCENE="$project_path/scene.txt"
OUT="$project_path/scene.mp4"

WIDTH=1080
HEIGHT=1920
FPS=30
SPEED=1.2

PRESET="ultrafast"
CRF=23

# Setup temporary directory for scenes
TMP_DIR="$project_path/tmp_scenes"
mkdir -p "$TMP_DIR"
CONCAT_TXT="$TMP_DIR/concat_list.txt"
> "$CONCAT_TXT"

# =========================
# AUTOMATED AUDIO TIMING CALCULATION
# =========================
echo "Calculating master audio track duration..."
# Fetch the raw duration of your wav file using ffprobe
RAW_AUDIO_LEN=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO")

# Calculate what the duration will be after the speed multiplier is applied
FINAL_DURATION=$(awk "BEGIN {print $RAW_AUDIO_LEN / $SPEED}")
echo "Target output length set by audio: ${FINAL_DURATION} seconds"

INDEX=0

# =========================
# 1. RENDER EACH SCENE WITH SPEED APPLIED
# =========================
echo "Processing, blurring, and speeding up individual scenes..."

while IFS="|" read -r _ start end _; do

    [[ -z "$start" || -z "$end" ]] && continue

    start=$(echo "$start" | xargs | tr ',' '.')
    end=$(echo "$end" | xargs | tr ',' '.')

    SCENE_FILE="$TMP_DIR/scene_${INDEX}.mp4"
    echo "Rendering Scene $INDEX ($start to $end)..."

    FILTER="[0:v]trim=start=$start:end=$end,setpts=PTS-STARTPTS,split=2[fgsrc][bgsrc];"
    FILTER+="[bgsrc]scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=increase,crop=${WIDTH}:${HEIGHT},gblur=sigma=20,fps=${FPS}[bg];"
    FILTER+="[fgsrc]scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,fps=${FPS}[fg];"
    FILTER+="[bg][fg]overlay=(W-w)/2:(H-h)/2,setpts=(1/$SPEED)*PTS[v]"

    ffmpeg -y -ss "$start" -to "$end" -i "$VIDEO" \
      -filter_complex "$FILTER" \
      -map "[v]" \
      -c:v libx264 -preset "$PRESET" -crf "$CRF" \
      -pix_fmt yuv420p -r "$FPS" -fps_mode cfr \
      "$SCENE_FILE"

    echo "file '$SCENE_FILE'" >> "$CONCAT_TXT"
    INDEX=$((INDEX+1))

done < "$SCENE"

# =========================
# 2. SPEED UP AUDIO AND STREAM-COPY VIDEO
# =========================
echo "Stitching video segments and rendering to exactly match audio track..."

TEMP_CONCAT_VIDEO="$TMP_DIR/concated_video_raw.mp4"

# 100% loss-free, instant video concatenation
ffmpeg -y -f concat -safe 0 -i "$CONCAT_TXT" -c copy "$TEMP_CONCAT_VIDEO"

# Combine the streams. 
# REPLACED -shortest WITH -t "$FINAL_DURATION" TO LOCK TO THE AUDIO TIMELINE
ffmpeg -y \
  -i "$TEMP_CONCAT_VIDEO" \
  -i "$AUDIO" \
  -filter_complex "[1:a]atempo=$SPEED[a]" \
  -map 0:v \
  -map "[a]" \
  -c:v copy \
  -c:a aac -b:a 192k \
  -t "$FINAL_DURATION" \
  "$OUT"

# =========================
# 3. CLEAN UP STORAGE
# =========================
rm -rf "$TMP_DIR"

echo "DONE -> $OUT"

