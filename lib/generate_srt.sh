#!/bin/bash

# Usage:
# ./whisper_api_srt.sh audio.mp3
API_KEY="${OPENAI_API_KEY}"

if [ $# -lt 1 ]; then
    echo "Usage: $0 audio_file"
    exit 1
fi

INPUT="$1"

# Output SRT file
OUTPUT="$2"

[[ -e "$OUTPUT" ]] && echo "skip generating original.srt, the file already exist" && exit 1

curl "$HOST"/audio/transcriptions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: multipart/form-data" \
  -F file=@"$INPUT" \
  -F model="$STT" \
  -F response_format="srt" \
  | jq -r ".text" > "$OUTPUT"

echo "Saved subtitle:"
echo "$OUTPUT"
exit 0
