#!/bin/bash

# Speed up WAV audio using FFmpeg
#
# Usage:
# ./speedup_wav.sh input.wav 1.25 output.wav
#
# Example:
# ./speedup_wav.sh voice.wav 1.5 fast.wav

INPUT="$1"
SPEED="$2"
OUTPUT="$3"

if [ ! -f "$INPUT" ]; then
    echo "Input WAV not found"
    exit 1
fi

if [ -z "$SPEED" ]; then
    echo "Missing speed factor"
    exit 1
fi

FILTER=""
CURRENT="$SPEED"

# FFmpeg atempo supports only 0.5 - 2.0
# Chain filters automatically

while (( $(echo "$CURRENT > 2.0" | bc -l) )); do
    FILTER="${FILTER}atempo=2.0,"
    CURRENT=$(echo "$CURRENT / 2.0" | bc -l)
done

while (( $(echo "$CURRENT < 0.5" | bc -l) )); do
    FILTER="${FILTER}atempo=0.5,"
    CURRENT=$(echo "$CURRENT / 0.5" | bc -l)
done

FILTER="${FILTER}atempo=$CURRENT"

echo "Speed : $SPEED"
echo "Filter: $FILTER"

ffmpeg \
    -i "$INPUT" \
    -filter:a "$FILTER" \
    -vn \
    -c:a pcm_s16le \
    -ar 44100 \
    -ac 2 \
    -y \
    "$OUTPUT"

echo "Done: $OUTPUT"

