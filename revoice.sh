#!/bin/bash
export global_path=$(pwd)
export project_path="$global_path/projects/$1"

set -a
source "$global_path/config/keys"
set +a

TOPIC=$2
SPEEDUP=1.22

lib="$global_path/lib"

echo "Asking gpt to generate scene"
$lib/generate_scene.sh \
	"$TOPIC" \
	"$project_path/scene.txt"
echo "Asking gpt-tts to generate speech"
$lib/generate_speech.sh \
	"$project_path/scene.txt" \
	"$project_path/narration.wav"
echo "speed up the audio"
$lib/speedup_wav.sh \
	"$project_path/narration.wav" \
	$SPEEDUP \
	"$project_path/final.wav" 
echo "generate srt"
$lib/generate_srt.sh \
	"$project_path/final.wav" \
	"$project_path/temp.srt"
echo "split srt"
$lib/nsubsplit.sh \
	"$project_path/temp.srt" \
	3 \
	> "$project_path/final.srt"
echo "compose video"
#total_duration=$($lib/media_duration.sh "$project_path/final.wav" seconds)
#max_duration_per_scene=8
#treshold=0.2
#echo "total duration: $total_duration"
#$lib/extract_scene.sh \
#	"$project_path/source" \
#	"$project_path/scene" \
#	$total_duration \
#	$max_duration_per_scene \
#	$treshold

$lib/roundrobincompose.sh \
	"$project_path/final.wav" \
	"$project_path/final.srt" \
	"$project_path/source" \
	"$project_path/final.mp4"
