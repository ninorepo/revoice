#!/bin/bash

# Check argument
if [ $# -lt 1 ]; then
    echo "Usage: $0 input.mp4"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

[[ -e "$OUTPUT" ]] && echo "skip generating original.mp3, already exist" && exit 1

# Extract audio to MP3
ffmpeg -i "$INPUT" -vn -acodec libmp3lame -q:a 2 "$OUTPUT"

echo "Saved as: $OUTPUT"
exit 0
