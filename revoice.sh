#!/bin/bash
export global_path=$(pwd)
export project_path="$global_path/projects/$1"

set -a
source "$global_path/config/keys"
set +a

lib="$global_path/lib"

# [OK] get audio original.mp3
$lib/extract_audio.sh "$project_path/original.mp4" "$project_path/original.m4a"

# [OK] get original.srt from the audio
$lib/generate_srt.sh "$project_path/original.m4a" "$project_path/original.srt"

# [OK] generate (summary|scene_start|scene_end) based on original.srt
$lib/generate_scene.sh "$project_path/original.srt" "$project_path/scene.txt" "$2"

# [OK] generate speech from scene summary.mp3
$lib/generate_speech.sh "$project_path/scene.txt" "$project_path/scene.wav"

# convert mp3 to wav to make sure sync accurate
#$lib/to_wav.sh "$project_path/scene.mp3" "$project_path/scene.wav"

# render
$lib/concat_render.sh
#$lib/render.sh
#$lib/render_faster.sh

#$lib/extract_audio.sh "$project_path/scene.mp4" "$project_path/final.m4a"

# generate summary.srt from summary.mp3
#$lib/generate_srt.sh "$project_path/final.m4a" "$project_path/temp.srt"
#$lib/nsubsplit.sh "$project_path/temp.srt" 3 > "$project_path/final.srt"

#$lib/burn_subs.sh "$project_path/scene.mp4" "$project_path/final.srt" "$project_path/final.mp4"

