#!/bin/bash

API_KEY="${OPENAI_API_KEY}"
SCENE_FILE="$1"
OUTPUT="$2"

if [ -z "$SCENE_FILE" ]; then
    echo "Usage: ./generate_tts.sh scenes.txt"
    exit 1
fi

if [ ! -f "$SCENE_FILE" ]; then
    echo "Scene file not found"
    exit 1
fi

if [[ -e "$2" ]]; then
   echo "skip : $(basename $2) already exist"
   exit 1
fi

# Extract narration only (first column before |)
TEXT=$(awk -F'|' '{gsub(/^ +| +$/,"",$1); print $1}' "$SCENE_FILE")

# Join into single script with natural pauses
SCRIPT=$(echo "$TEXT" | tr '
' ' ')

echo "Generating TTS audio..."

RESPONSE=$(curl -s $HOST/audio/speech \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
      --arg input "$SCRIPT" \
      --arg tts "$TTS" \
      '{
          model: $tts,
          voice: "alloy",
          input: $input,
          format: "wav"
      }')" \
  --output "$OUTPUT")

if [ $? -eq 0 ]; then
    echo "DONE → $OUTPUT"
else
    echo "TTS generation failed"
fi
exit 0
