#!/bin/bash

INPUT="$1"
OUTPUT="$2"

if [ -z "$INPUT" ]; then
    echo "Usage: ./to_wav.sh input_audio [output.wav]"
    exit 1
fi

# default output name if not provided
if [ -z "$OUTPUT" ]; then
    BASE=$(basename "$INPUT")
    NAME="${BASE%.*}"
    OUTPUT="${NAME}.wav"
fi

if [ ! -f "$INPUT" ]; then
    echo "Input file not found"
    exit 1
fi

[[ -e "$OUTPUT" ]] && echo "skip: $(basename $OUTPUT) already exist" && exit 1

echo "Converting $INPUT → $OUTPUT"

ffmpeg -y -i "$INPUT" \
  -ar 48000 \
  -ac 2 \
  -c:a pcm_s16le \
  "$OUTPUT"

echo "DONE → $OUTPUT"
exit 0
