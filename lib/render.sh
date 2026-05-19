#!/bin/bash

# ========================
# INPUTS
# ========================
AUDIO="$project_path/final.wav"
SUBS="$project_path/final.srt"
SCENE="$project_path/scene.txt"
VIDEO="$project_path/original.mp4"

FONT="$global_path/font/Montserrat/static/Montserrat_ExtraBold.ttf"
FONT_NAME="Montserrat\ ExtraBold"
OUT="$project_path/final.mp4"

WORKDIR="$project_path/work"
mkdir -p "$WORKDIR"

# ========================
# CONFIG
# ========================
WIDTH=1920
HEIGHT=1080
FPS=30

SPEED=1.16
PRESET="ultrafast"
CRF=23

TOLERANCE=2

# ========================
# GET DURATION
# ========================
DURATION=$(ffprobe -i "$AUDIO" -show_entries format=duration -v quiet -of csv="p=0")
ADJ_DURATION=$(echo "$DURATION / $SPEED" | bc -l)

echo "Audio duration: $DURATION"
echo "Adjusted: $ADJ_DURATION"

# ========================
# STEP 1: BLACK BACKGROUND (CFR)
# ========================
ffmpeg -y \
  -f lavfi -i color=c=black:s=${WIDTH}x${HEIGHT}:r=${FPS}:d=${ADJ_DURATION} \
  -r $FPS \
  -c:v libx264 -preset $PRESET -crf $CRF \
  -pix_fmt yuv420p \
  base.mp4

# ========================
# STEP 2: AUDIO SPEED ADJUST
# ========================
if [ "$SPEED" != "1.0" ]; then
    ffmpeg -y -i "$AUDIO" \
      -filter:a "atempo=$SPEED" \
      audio_mod.wav
    AUDIO_FINAL="audio_mod.wav"
else
    AUDIO_FINAL="$AUDIO"
fi

# ========================
# STEP 2.5: CREATE OVERLAY CLIPS
# ========================

i=0
INPUTS="-i base.mp4"
FILTER=""
OVERLAY_LAYERS=""

while IFS="|" read -r _ start end _; do



    ffmpeg -y -i "$VIDEO" \
      -ss "$start" -to "$end" \
      ...
done < "$SCENE"


while IFS="|" read -r _ start end _; do

    i=$((i+1))
    
    start=$(echo "$start" | xargs | tr ',' '.')
    end=$(echo "$end" | xargs | tr ',' '.')

    end=$(awk -F'[:.]' -v t="$TOLERANCE" '
    {
        sec = ($1*3600)+($2*60)+$3+("0."$4)
        sec += t

        h = int(sec/3600)
        m = int((sec%3600)/60)
        s = sec%60

        printf "%02d:%02d:%06.3f", h, m, s
    }' <<< "$end")

    echo "start : $start"
    echo "end : $end"
    
    # cut scene clip
    ffmpeg -nostdin -y -i "$VIDEO" \
      -ss "$start" -to "$end" \
      -vf "scale=${WIDTH}:${HEIGHT}" \
      -c:v libx264 -preset veryfast -crf 20 \
      "$WORKDIR/scene_$i.mp4"

    INPUTS="$INPUTS -i $WORKDIR/scene_$i.mp4"

    OVERLAY_LAYERS="$OVERLAY_LAYERS[$i:v]format=rgba[ov$i];"

done < "$SCENE"

# ========================
# STEP 3: OVERLAY COMPOSITION
# ========================
FILTER=""
LAST="[0:v]"

for ((j=1; j<=i; j++)); do

    NEXT="[tmp$j]"

    FILTER="${FILTER}${LAST}[$j:v]overlay=x=0:y=0${NEXT};"

    LAST="$NEXT"

done

# remove trailing ;
FILTER="${FILTER%;}"

# ========================
# STEP 4: FINAL RENDER
# ========================

SUBSTYLE="Fontsize=46,\
PrimaryColour=&HFFFFFF&,\
OutlineColour=&H000000&,\
BorderStyle=1,\
Outline=4,\
Shadow=2,\
Alignment=2,\
MarginV=50"

if [ -f "$FONT" ]; then
    SUBSTYLE="$SUBSTYLE,FontFile=$FONT"
else
    SUBSTYLE="$SUBSTYLE,FontName=$FONT_NAME"
fi

ffmpeg -y \
  $INPUTS \
  -i "$AUDIO_FINAL" \
  -filter_complex "$FILTER" \
  -vf "subtitles=$SUBS:force_style='$SUBSTYLE'" \
  -map "$LAST" \
  -map "$((i+1)):a" \
  -c:v libx264 \
  -preset $PRESET \
  -crf $CRF \
  -r $FPS \
  -pix_fmt yuv420p \
  -c:a aac \
  -b:a 192k \
  -shortest \
  "$OUT"

echo "DONE → $OUT"

