#!/bin/bash

# ========================
# INPUTS
# ========================
VIDEO="$project_path/original.mp4"
AUDIO="$project_path/scene.wav"
#SUBS="$project_path/final.srt"
SCENE="$project_path/scene.txt"

#FONT="$global_path/font/Montserrat/static/Montserrat_ExtraBold.ttf"
#FONT_NAME="Montserrat ExtraBold"

OUT="$project_path/scene.mp4"
[[ -e "$OUT" ]] && echo "skip rendering : $OUT already exist" && exit 1
# ========================
# WORKDIR
# ========================
WORKDIR="$project_path/work"
mkdir -p "$WORKDIR"

# ========================
# CONFIG
# ========================
WIDTH=1080
HEIGHT=1920
FPS=30

SPEED=1.22
TOLERANCE=2

PRESET="slow"
CRF=23

# ========================
# AUDIO SPEED PROCESS & TRANSFORMATION : avoid content ID
# ========================
echo "Processing audio..."


#if [ "$SPEED" != "1.0" ]; then

    ffmpeg -y \
      -i "$AUDIO" \
      -filter:a "atempo=$SPEED" \
      "$WORKDIR/audio.wav"

    AUDIO_FINAL="$WORKDIR/audio.wav"

#else
#    AUDIO_FINAL="$AUDIO"
#fi

# ========================
# CUT SCENES
# ========================
echo "Cutting scenes..."

i=0

while IFS="|" read -r dummy1 start end dummy2; do

    i=$((i+1))

    # cleanup timestamps
    start=$(echo "$start" | tr -d '
' | xargs | tr ',' '.')
    end=$(echo "$end" | tr -d '
' | xargs | tr ',' '.')

    # add tolerance to END only
    end=$(awk -F'[:.]' -v t="$TOLERANCE" '
    {
        sec = ($1*3600)+($2*60)+$3+("0."$4)
        sec += t

        h = int(sec/3600)
        m = int((sec%3600)/60)
        s = sec%60

        printf "%02d:%02d:%06.3f", h, m, s
    }' <<< "$end")

    echo "Scene $i"
    echo "$start -> $end"

    [[ -e "$WORKDIR/scene_$i.mp4" ]] && echo "skip : scene_$i.mp4 already exist" && continue

# ---------- FFmpeg PROCESS ----------
    ffmpeg -nostdin -y \
      -i "$VIDEO" \
      -ss "$start" \
      -to "$end" \
      -vf "
	[0:v]split=2[main][bg];

	[bg]scale=1080:1920:force_original_aspect_ratio=increase,
	crop=1080:1920,
	gblur=sigma=20[bgblur];

	[main]scale=1080:1920:force_original_aspect_ratio=decrease[fg];

	[bgblur][fg]overlay=(W-w)/2:(H-h)/2,
	fps=${FPS}
	" \
      -r $FPS \
      -fps_mode cfr \
      -c:v libx264 \
      -preset veryfast \
      -crf 20 \
      -pix_fmt yuv420p \
      -an \
      "$WORKDIR/scene_$i.mp4"

done < "$SCENE"

# ========================
# CREATE CONCAT LIST
# ========================
echo "Creating concat list..."

find "$WORKDIR" -name "scene_*.mp4" \
| sort -V \
| sed "s/^/file '/;s/$/'/" \
> "$WORKDIR/list.txt"

# ========================
# CONCAT SCENES
# ========================
echo "Concatenating scenes..."

ffmpeg -y \
  -f concat \
  -safe 0 \
  -i "$WORKDIR/list.txt" \
  -vf "fps=${FPS}" \
  -r $FPS \
  -fps_mode cfr \
  -c:v libx264 \
  -preset $PRESET \
  -crf $CRF \
  -pix_fmt yuv420p \
  "$WORKDIR/video.mp4"

# ========================
# GET VIDEO/AUDIO DURATION
# ========================
VIDEO_DURATION=$(ffprobe \
  -v error \
  -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 \
  "$WORKDIR/video.mp4")

AUDIO_DURATION=$(ffprobe \
  -v error \
  -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 \
  "$AUDIO_FINAL")

echo "Video duration: $VIDEO_DURATION"
echo "Audio duration: $AUDIO_DURATION"

# ========================
# HANDLE DURATION MISMATCH
# ========================
#
# If video shorter:
# freeze last frame
#
# If video longer:
# shortest trims safely
#
# ========================

DIFF=$(awk -v a="$AUDIO_DURATION" -v v="$VIDEO_DURATION" \
'BEGIN{print a-v}')

if awk "BEGIN {exit !($DIFF > 0)}"; then

    echo "Padding video..."

    ffmpeg -y \
      -i "$WORKDIR/video.mp4" \
      -vf "tpad=stop_mode=clone:stop_duration=$DIFF,fps=${FPS}" \
      -r $FPS \
      -fps_mode cfr \
      -c:v libx264 \
      -preset $PRESET \
      -crf $CRF \
      -pix_fmt yuv420p \
      "$WORKDIR/video_padded.mp4"

    VIDEO_FINAL="$WORKDIR/video_padded.mp4"

else

    VIDEO_FINAL="$WORKDIR/video.mp4"

fi

# ========================
# FINAL RENDER
# ========================
echo "Rendering final video..."

ffmpeg -y \
  -i "$VIDEO_FINAL" \
  -i "$AUDIO_FINAL" \
  -r $FPS \
  -fps_mode cfr \
  -c:v libx264 \
  -preset $PRESET \
  -crf $CRF \
  -pix_fmt yuv420p \
  -c:a aac \
  -b:a 192k \
  -shortest \
  "$OUT"

echo "DONE -> $OUT"
#  -vf "subtitles=$SUBS:force_style='$SUBSTYLE',fps=${FPS}" \
# ========================
# SUBTITLE STYLE
# ========================
#SUBSTYLE="Fontsize=46,\
#PrimaryColour=&HFFFFFF&,\
#OutlineColour=&H000000&,\
#BorderStyle=1,\
#Outline=4,\
#Shadow=2,\
#Alignment=2,\
#MarginV=50"

#if [ -f "$FONT" ]; then
#    SUBSTYLE="$SUBSTYLE,FontFile=$FONT"
#else
#    SUBSTYLE="$SUBSTYLE,FontName=$FONT_NAME"
#fi


