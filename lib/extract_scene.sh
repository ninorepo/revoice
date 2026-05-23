#!/bin/bash

set -euo pipefail

INPUT_DIR="${1:-}"
OUTPUT_DIR="${2:-}"
TARGET_DURATION="${3:-}"
MAX_SCENE_DURATION="${4:-8}"
SCENE_THRESHOLD="${5:-0.4}"

if [[ -z "$INPUT_DIR" || -z "$OUTPUT_DIR" || -z "$TARGET_DURATION" ]]; then
  echo "Usage:"
  echo "  $0 <input_folder> <output_folder> <target_duration_sec> [max_scene_sec] [scene_threshold]"
  exit 1
fi

command -v ffmpeg >/dev/null || { echo "ffmpeg not found"; exit 1; }
command -v ffprobe >/dev/null || { echo "ffprobe not found"; exit 1; }
command -v jq >/dev/null || { echo "jq not found (install jq)"; exit 1; }

mkdir -p "$OUTPUT_DIR"

mapfile -t VIDEOS < <(
  find "$INPUT_DIR" -type f \( \
    -iname "*.mp4" -o \
    -iname "*.mkv" -o \
    -iname "*.mov" -o \
    -iname "*.avi" \
  \) | sort
)

[[ ${#VIDEOS[@]} -eq 0 ]] && { echo "No videos found"; exit 1; }

echo "Found ${#VIDEOS[@]} videos"

declare -A SCENES_MAP
declare -A DUR_MAP
declare -A INDEX_MAP
declare -A ARRAY_MAP

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[1/4] Extracting scenes (ffprobe JSON)..."

extract_scenes() {
  local file="$1"

  ffprobe -v error \
    -select_streams v:0 \
    -show_frames \
    -show_entries frame=pkt_pts_time,side_data_list \
    -of json "$file" \
  | jq -r --arg th "$SCENE_THRESHOLD" '
      .frames[]
      | select(.pkt_pts_time != null)
      | select(
          (.side_data_list // [])
          | tostring
          | contains("scene") )
      | .pkt_pts_time
    ' 2>/dev/null || true
}

for vid in "${VIDEOS[@]}"; do
  name=$(basename "$vid")

  echo "Scanning: $name"

  scenes=$(extract_scenes "$vid")

  dur=$(ffprobe -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$vid")

  SCENES_MAP["$name"]="$scenes"
  DUR_MAP["$name"]="$dur"
done

echo "[2/4] Building timelines..."

for vid in "${VIDEOS[@]}"; do
  name=$(basename "$vid")

  IFS=$'
' read -r -d '' -a arr <<< "${SCENES_MAP[$name]}" || true

  dur="${DUR_MAP[$name]}"

  # need at least 2 scenes
  if [[ ${#arr[@]} -lt 2 ]]; then
    echo "Skipping $name (not enough scenes)"
    continue
  fi

  # skip intro/outro safely
  middle=("${arr[@]:1:${#arr[@]}-2}")

  # build full timeline
  all=(0 "${middle[@]}" "$dur")

  ARRAY_MAP["$name"]="${all[*]}"
  INDEX_MAP["$name"]=0
done

echo "[3/4] Extracting clips (round-robin)..."

TOTAL=0
i=0

while true; do
  done_all=true

  for vid in "${VIDEOS[@]}"; do
    name=$(basename "$vid")

    [[ -z "${ARRAY_MAP[$name]:-}" ]] && continue

    done_all=false

    IFS=' ' read -r -a scenes <<< "${ARRAY_MAP[$name]}"
    idx=${INDEX_MAP[$name]}

    # stop condition
    if (( $(echo "$TOTAL >= $TARGET_DURATION" | bc -l) )); then
      echo "Target reached"
      exit 0
    fi

    [[ $idx -ge $((${#scenes[@]} - 1)) ]] && continue

    start="${scenes[$idx]}"
    end="${scenes[$((idx+1))]}"

    # validate numbers
    [[ -z "$start" || -z "$end" ]] && { INDEX_MAP["$name"]=$((idx+1)); continue; }

    # clamp max scene duration
    max_end=$(awk "BEGIN {print $start + $MAX_SCENE_DURATION}")

    end=$(awk "BEGIN {print ($end > $max_end) ? $max_end : $end}")

    # skip invalid
    if (( $(echo "$end <= $start" | bc -l) )); then
      INDEX_MAP["$name"]=$((idx+1))
      continue
    fi

    clipdur=$(awk "BEGIN {print $end - $start}")

    # skip tiny clips
    if (( $(echo "$clipdur < 2" | bc -l) )); then
      INDEX_MAP["$name"]=$((idx+1))
      continue
    fi

    out="$OUTPUT_DIR/clip_$(printf "%05d" "$i")_${name}_${idx}.mp4"

    echo "[$i] $out"

    ffmpeg -y \
      -ss "$start" \
      -to "$end" \
      -i "$vid" \
      -c:v libx264 \
      -preset veryfast \
      -crf 23 \
      -af loudnorm=I=-16:TP=-1.5:LRA=11 \
      -c:a aac \
      "$out" < /dev/null

    TOTAL=$(awk "BEGIN {print $TOTAL + $clipdur}")

    INDEX_MAP["$name"]=$((idx+1))
    i=$((i+1))
  done

  $done_all && break
done

echo "[4/4] Done"
exit 0

